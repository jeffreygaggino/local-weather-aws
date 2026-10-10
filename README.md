# local-weather-aws

Collects the current weather for Mudgeeraba, QLD from [Open-Meteo](https://open-meteo.com/) and stores it in DynamoDB. The aim is a stack that runs on ECS Fargate, scheduled by EventBridge Scheduler, and is created and destroyed with Terraform.

Domain terms (Location, Observation, Slot, Session, Watchdog) are defined in [CONTEXT.md](CONTEXT.md). Architectural decisions are in [docs/adr](docs/adr).

## Status

- [x] Collector fetches the current Observation from Open-Meteo
- [x] Observations stored in DynamoDB (local)
- [x] API: `/health`, `/latest`, `/history`
- [x] Watchdog: computes Observation Age (publishing to CloudWatch comes with the alarms)
- [x] Container image (arm64, runs `serve`, `collect` or `check`)
- [x] Terraform: DynamoDB, ECR (image pushed by hand)
- [x] ECS Fargate task, run by hand (`make run-collect`)
- [ ] ECS service for the API
- [ ] EventBridge Scheduler and dead-letter queue
- [ ] Alarms and budget
- [ ] `make up` / `make down`, CI

## Prerequisites

- Docker (the app and DynamoDB Local both run in containers)
- Node 22.18+ and npm, for typechecking and editor support
- AWS CLI, for inspecting tables
- jq, for pretty-printing API responses
- Terraform 1.10+ and an AWS CLI profile named `weather`, for the AWS targets (see [AWS](#aws))

## Local development

Everything runs in Docker, using the same image ECS runs. `app/src` is mounted into the container, so code changes take effect without a rebuild.

```sh
make install     # npm install in app/ (editor + typecheck)
make image       # build local-weather:dev (again after changing dependencies or the Dockerfile)
make local       # start DynamoDB Local and create the table
make collect     # fetch and store one Observation
make check       # Watchdog: print Observation Age
make serve       # API on :8080, restarts when src/ changes
make latest      # in another terminal: GET /latest
make local-down  # stop DynamoDB Local (data is in-memory and is discarded)
```

Container config lives in [`app/local.env`](app/local.env). `DYNAMODB_ENDPOINT` points the SDK at the `dynamodb` Compose service; in AWS it is unset, and credentials come from the ECS task role.

### Make targets

| Target | Does |
| --- | --- |
| `install` | `npm install` in `app/` |
| `typecheck` | Typecheck the app |
| `test` | Run the tests in the container (unit tests plus the store against DynamoDB Local) |
| `image` | Build the arm64 image `local-weather:dev` |
| `local` | Start DynamoDB Local and create the table |
| `local-down` | Stop DynamoDB Local |
| `collect` | Fetch the current Observation and store it |
| `check` | Run the Watchdog: print Observation Age |
| `serve` | Run the API with `--watch` |
| `health` / `latest` / `history` | Call the local API (`make history HOURS=2`) |
| `db-scan` | Every item in the table, raw DynamoDB format |
| `db-latest` | Newest Observation for the Location |
| `db-history` | All Observations for the Location, newest first |

## Container

One image runs every mode; the command picks which one:

| Mode | Command | In AWS |
| --- | --- | --- |
| serve | `node src/serve.ts` (default) | ECS service |
| collect | `node src/collect.ts` | Scheduled task |
| check | `node src/check.ts` | Scheduled task (Watchdog) |

Node runs the TypeScript directly, so there is no build step and the image contains `src/` as written. It is built for `linux/arm64` to match Graviton Fargate.

## Code layout

```
app/
├── src/
│   ├── collect.ts               entrypoint: fetch an Observation and store it
│   ├── check.ts                 entrypoint: Watchdog, measures Observation Age
│   ├── serve.ts                 entrypoint: HTTP API
│   └── lib/
│       ├── api.ts               HTTP routes (createApi), independent of where data comes from
│       ├── observationAge.ts    Observation Age calculation
│       ├── openMeteoClient.ts   client: Open-Meteo API
│       ├── observationStore.ts  store: Observations table in DynamoDB
│       ├── observation.ts       type: Observation
│       ├── location.ts          type: Location, read from env
│       └── env.ts               config helpers
├── scripts/
│   └── create-local-table.ts    creates the table in DynamoDB Local
├── test/                        node:test suites, mounted into the container (not in the image)
└── local.env                    container config for local runs
```

Naming: `*Client.ts` talks to an external API, `*Store.ts` reads and writes a table, plain nouns are types. Entrypoints only wire these together.

## AWS

Everything in AWS is created and destroyed together; a Session is the time between the two. Nothing is left running in between.

### One-time setup

1. An AWS account, with MFA on the root user and a monthly cost budget created in the Billing console.
2. An IAM user with console access, MFA and the `AdministratorAccess` policy. Do not enable IAM Identity Center or AWS Organizations: on a free-plan account, creating an organization switches to paid and ends the free credits.
3. A CLI profile for that user:
   ```sh
   aws configure set region ap-southeast-2 --profile weather
   aws login --profile weather
   aws sts get-caller-identity --profile weather   # Arn should end in :user/<you>
   ```
4. Download the Terraform provider: `make tf-init`.

`REGISTRY` in the Makefile contains the AWS account ID; change it if you use a different account.

### Starting a Session

```sh
aws login --profile weather   # if the previous login has expired
make tf-apply                 # network, IAM roles, table, ECR repository, cluster, task definition
make push                     # build the arm64 image and push it, tagged with the git SHA
make run-collect              # run collect once as a Fargate task
make logs                     # follow task logs (tasks take about a minute to start)
make aws-db-history           # Observations in the real table
```

`tf-apply` comes before `push` because the ECR repository has to exist before an image can be pushed to it. The task definition can refer to an image tag that hasn't been pushed yet; it only matters once a task runs.

Commit before `make tf-apply` and `make push`: both tag with the current git SHA, so the task definition points at the image you pushed. With uncommitted changes the tag ends in `-dirty`.

### Ending a Session

```sh
make tf-destroy               # removes everything, including ECR images, logs and Observations
```

Task definitions are deregistered rather than deleted, so `local-weather:<n>` stays listed as INACTIVE in the ECS console; the next apply creates the next revision.

### AWS make targets

| Target | Does |
| --- | --- |
| `tf-init` | Download the Terraform provider (once per clone) |
| `tf-plan` / `tf-apply` / `tf-destroy` | Plan, create or remove the stack, tagged with the current git SHA |
| `push` | Log in to ECR, build the arm64 image and push it |
| `ecr-images` | List image tags in the repository |
| `run-collect` | Run collect once as a Fargate task |
| `logs` | Follow the task logs in CloudWatch |
| `aws-db-history` | Observations in the real table |

Terraform state is local (`infra/terraform.tfstate`, gitignored); the provider lock file is committed.

## Tests

```sh
make local   # the store tests need DynamoDB Local
make test
```

Tests use Node's built-in runner (`node:test`) and run in the container. The Open-Meteo client is tested against a mocked `fetch`, the API through `createApi` with fake data functions (no server or database), and the store against DynamoDB Local in a throwaway table that is deleted afterwards.

## API

| Route | Returns |
| --- | --- |
| `GET /health` | `{ "ok": true }` |
| `GET /latest` | Newest Observation, or `404` before the first one is collected |
| `GET /history?hours=6` | Observations from the last `hours` (default 6, max 24), newest first |

## Data model

One DynamoDB table, keyed by `location` (partition key) and `ts` (sort key, the Slot start in UTC ISO 8601). Open-Meteo's current conditions change every 15 minutes, so each Location has at most one Observation per Slot. Collecting twice in the same Slot overwrites rather than duplicates.
