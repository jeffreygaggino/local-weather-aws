# local-weather-aws

Collects the current weather for Mudgeeraba, QLD from [Open-Meteo](https://open-meteo.com/) and stores it in DynamoDB. The aim is a stack that runs on ECS Fargate, scheduled by EventBridge Scheduler, and is created and destroyed with Terraform.

Domain terms (Location, Observation, Slot, Session, Watchdog) are defined in [CONTEXT.md](CONTEXT.md). Architectural decisions are in [docs/adr](docs/adr).

## Status

- [x] Collector fetches the current Observation from Open-Meteo
- [x] Observations stored in DynamoDB (local)
- [x] API: `/health`, `/latest`, `/history`
- [x] Watchdog: computes Observation Age (publishing to CloudWatch comes with the alarms)
- [ ] Container image
- [ ] Terraform: DynamoDB, ECR
- [ ] ECS Fargate task and service
- [ ] EventBridge Scheduler and dead-letter queue
- [ ] Alarms and budget
- [ ] `make up` / `make down`, CI

## Prerequisites

- Node 22.18+ (runs the TypeScript directly, no build step)
- Docker, for DynamoDB Local
- AWS CLI, for inspecting tables
- jq, for pretty-printing API responses

## Local development

```sh
make install     # npm install in app/
make local       # start DynamoDB Local and create the table
make collect     # fetch and store one Observation
make db-history  # list stored Observations, newest first
make serve       # run the API on :8080, restarting on file changes
make latest      # in another terminal: GET /latest
make local-down  # stop DynamoDB Local (data is in-memory and is discarded)
```

Local config lives in [`app/local.env`](app/local.env). `DYNAMODB_ENDPOINT` points the SDK at DynamoDB Local. In AWS it is unset, and credentials come from the ECS task role.

### Make targets

| Target | Does |
| --- | --- |
| `install` | `npm install` in `app/` |
| `typecheck` | Typecheck the app |
| `local` | Start DynamoDB Local and create the table |
| `local-down` | Stop DynamoDB Local |
| `collect` | Fetch the current Observation and store it |
| `check` | Run the Watchdog: print Observation Age |
| `serve` | Run the API locally with `--watch` |
| `health` / `latest` / `history` | Call the local API (`make history HOURS=2`) |
| `db-scan` | Every item in the table, raw DynamoDB format |
| `db-latest` | Newest Observation for the Location |
| `db-history` | All Observations for the Location, newest first |

## Code layout

```
app/
├── src/
│   ├── collect.ts               entrypoint: fetch an Observation and store it
│   ├── check.ts                 entrypoint: Watchdog, measures Observation Age
│   ├── serve.ts                 entrypoint: HTTP API
│   └── lib/
│       ├── openMeteoClient.ts   client: Open-Meteo API
│       ├── observationStore.ts  store: Observations table in DynamoDB
│       ├── observation.ts       type: Observation
│       ├── location.ts          type: Location, read from env
│       └── env.ts               config helpers
├── scripts/
│   └── create-local-table.ts    creates the table in DynamoDB Local
└── local.env                    local config
```

Naming: `*Client.ts` talks to an external API, `*Store.ts` reads and writes a table, plain nouns are types. Entrypoints only wire these together.

## API

| Route | Returns |
| --- | --- |
| `GET /health` | `{ "ok": true }` |
| `GET /latest` | Newest Observation, or `404` before the first one is collected |
| `GET /history?hours=6` | Observations from the last `hours` (default 6, max 24), newest first |

## Data model

One DynamoDB table, keyed by `location` (partition key) and `ts` (sort key, the Slot start in UTC ISO 8601). Open-Meteo's current conditions change every 15 minutes, so each Location has at most one Observation per Slot. Collecting twice in the same Slot overwrites rather than duplicates.
