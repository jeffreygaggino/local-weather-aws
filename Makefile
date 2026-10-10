include app/local.env

IMAGE = local-weather:dev
RUN = docker compose --progress quiet run --rm

# local.env is the container's view (dynamodb:8000); from the Mac, DynamoDB Local is on localhost.
DDB = AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	aws dynamodb --endpoint-url http://localhost:8000 --region $(AWS_REGION)

HOURS ?= 6

LOCATION_QUERY = --table-name $(TABLE) \
	--key-condition-expression '\#l = :l' \
	--expression-attribute-names '{"\#l":"location"}' \
	--expression-attribute-values '{":l":{"S":"$(LOCATION)"}}' \
	--no-scan-index-forward

# ── Local development ─────────────────────────────────────────────────────────

.PHONY: install
install:
	@cd app && npm install

.PHONY: typecheck
typecheck:
	@cd app && npm run -s typecheck

.PHONY: test
test:
	@$(RUN) app npm test --silent

.PHONY: local
local:
	@docker compose --progress quiet up -d --wait
	@$(RUN) app node scripts/create-local-table.ts

.PHONY: local-down
local-down:
	@docker compose down

# src/ is mounted into the container, so only dependency or Dockerfile changes need a rebuild.
.PHONY: image
image:
	@docker buildx build --platform linux/arm64 -t $(IMAGE) --load --quiet . >/dev/null

.PHONY: serve
serve:
	@$(RUN) --service-ports app node --watch src/serve.ts

.PHONY: collect
collect:
	@$(RUN) app node src/collect.ts

.PHONY: check
check:
	@$(RUN) app node src/check.ts


# ── Call the local API (run `make serve` in another terminal) ────────────────

.PHONY: health
health:
	@curl -sS localhost:$(PORT)/health | jq .

.PHONY: latest
latest:
	@curl -sS localhost:$(PORT)/latest | jq .

.PHONY: history
history:
	@curl -sS "localhost:$(PORT)/history?hours=$(HOURS)" | jq .


# ── Inspect local data ────────────────────────────────────────────────────────

.PHONY: db-scan
db-scan:
	@$(DDB) scan --table-name $(TABLE)

.PHONY: db-latest
db-latest:
	@$(DDB) query $(LOCATION_QUERY) --limit 1

.PHONY: db-history
db-history:
	@$(DDB) query $(LOCATION_QUERY) \
		--query 'Items[].{ts: ts.S, temperatureC: temperatureC.N, collectedAt: collectedAt.S}' --output table


# ── AWS (run `aws login --profile weather` first) ─────────────────────────────

export AWS_PROFILE ?= weather
# All runs in the infra folder
TF = terraform -chdir=infra
# The files that go into the image. The tag is the last commit that changed any of them,
# so Terraform-only or docs commits keep the same tag and need no push.
IMAGE_INPUTS = Dockerfile .dockerignore app/package.json app/package-lock.json app/src
TAG := $(shell git log -1 --format=%h -- $(IMAGE_INPUTS))$(shell [ -n "$$(git status --porcelain -- $(IMAGE_INPUTS))" ] && echo -dirty)

# ── Sessions ──────────────────────────────────────────────────────────────────

# Runs left to right: check, create ECR, push the image, then the full apply (shows its plan and asks).
.PHONY: up
up: preflight ecr-repo push tf-apply
	@echo
	@echo "Session is up. Click the SNS confirmation email to receive alarms."

.PHONY: down
down: tf-destroy

# Is anything from this project running in AWS right now?
.PHONY: status
status:
	@resources=$$($(TF) state list 2>/dev/null | grep -vc '^data\.'); \
	clusters=$$(aws ecs list-clusters --query 'length(clusterArns)' --output text); \
	echo "Terraform resources:  $$resources"; \
	echo "ECS clusters in AWS:  $$clusters"; \
	if [ "$$resources" -gt 0 ] || [ "$$clusters" -gt 0 ]; then echo "→ A Session is up. Run make down when you're finished."; \
	else echo "→ Nothing is running."; fi

# Everything `make up` needs, checked before anything touches AWS.
.PHONY: preflight
preflight:
	@test -f infra/terraform.tfvars || { echo "Copy infra/terraform.tfvars.example to infra/terraform.tfvars and set alert_email"; exit 1; }
	@aws sts get-caller-identity >/dev/null || { echo "Run: aws login --profile $(AWS_PROFILE)"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Start Docker first"; exit 1; }

# Just the ECR repository, so there's somewhere to push before the full apply.
# No prompt: it can only create one empty repository.
.PHONY: ecr-repo
ecr-repo:
	@$(TF) init -input=false >/dev/null
	@$(TF) apply -var image_tag=$(TAG) -target=aws_ecr_repository.app -auto-approve >/dev/null


# ── Terraform, step by step ───────────────────────────────────────────────────

.PHONY: tf-init
tf-init:
	@$(TF) init

.PHONY: tf-plan
tf-plan:
	@$(TF) plan -var image_tag=$(TAG)

.PHONY: tf-apply
tf-apply:
	@$(TF) apply -var image_tag=$(TAG)

.PHONY: tf-destroy
tf-destroy:
	@$(TF) destroy -var image_tag=$(TAG)

REGISTRY = 420653187671.dkr.ecr.ap-southeast-2.amazonaws.com
ECR_URL = $(REGISTRY)/local-weather

.PHONY: ecr-login
ecr-login:
	@aws ecr get-login-password | docker login --username AWS --password-stdin $(REGISTRY)

.PHONY: push
push: ecr-login
	@docker buildx build --platform linux/arm64 --provenance=false -t $(ECR_URL):$(TAG) --push .
	@echo "Pushed $(ECR_URL):$(TAG)"

.PHONY: ecr-images
ecr-images:
	@aws ecr list-images --repository-name local-weather --output table

# Subnet and security group IDs change every time the stack is recreated, so they're read from Terraform.
SUBNETS = $(shell $(TF) output -json public_subnet_ids | jq -r 'join(",")')
JOBS_SG = $(shell $(TF) output -raw jobs_security_group_id)

.PHONY: run-collect
run-collect:
	@aws ecs run-task \
		--cluster local-weather \
		--task-definition local-weather \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNETS)],securityGroups=[$(JOBS_SG)],assignPublicIp=ENABLED}" \
		--overrides '{"containerOverrides":[{"name":"app","command":["node","src/collect.ts"]}]}' \
		--query 'tasks[0].taskArn' --output text

.PHONY: run-check
run-check:
	@aws ecs run-task \
		--cluster local-weather \
		--task-definition local-weather \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNETS)],securityGroups=[$(JOBS_SG)],assignPublicIp=ENABLED}" \
		--overrides '{"containerOverrides":[{"name":"app","command":["node","src/check.ts"]}]}' \
		--query 'tasks[0].taskArn' --output text

# Observation Age as CloudWatch sees it, over the last 2 hours.
.PHONY: age
age:
	@aws cloudwatch get-metric-statistics --namespace LocalWeather --metric-name ObservationAgeMinutes \
		--dimensions Name=Location,Value=$(LOCATION) \
		--start-time $$(date -u -v-2H +%Y-%m-%dT%H:%M:%SZ) --end-time $$(date -u +%Y-%m-%dT%H:%M:%SZ) \
		--period 300 --statistics Maximum \
		--query 'sort_by(Datapoints, &Timestamp)[].{time: Timestamp, ageMinutes: Maximum}' --output table

.PHONY: logs
logs:
	@aws logs tail /ecs/local-weather --follow --since 15m

.PHONY: aws-db-history
aws-db-history:
	@aws dynamodb query $(LOCATION_QUERY) \
		--query 'Items[].{ts: ts.S, temperatureC: temperatureC.N, collectedAt: collectedAt.S}' --output table

# The serve task's public IP: service → its running task → the task's network card → that card's public IP.
# It changes whenever the task is replaced, so it's looked up each time.
.PHONY: ip
ip:
	@task=$$(aws ecs list-tasks --cluster local-weather --service-name local-weather-serve --query 'taskArns[0]' --output text) && \
	eni=$$(aws ecs describe-tasks --cluster local-weather --tasks $$task --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text) && \
	aws ec2 describe-network-interfaces --network-interface-ids $$eni --query 'NetworkInterfaces[0].Association.PublicIp' --output text

API = http://$$($(MAKE) -s --no-print-directory ip):8080

.PHONY: aws-health
aws-health:
	@curl -sS $(API)/health | jq .

.PHONY: aws-latest
aws-latest:
	@curl -sS $(API)/latest | jq .

.PHONY: aws-history
aws-history:
	@curl -sS "$(API)/history?hours=$(HOURS)" | jq .

# Why the scheduler failed to start a task, if it has. Reading doesn't remove the messages.
.PHONY: dlq
dlq:
	@aws sqs receive-message --queue-url $$($(TF) output -raw dlq_url) \
		--max-number-of-messages 10 --visibility-timeout 0 --message-attribute-names All \
		--query 'Messages[].MessageAttributes.{error: ERROR_CODE.StringValue, message: ERROR_MESSAGE.StringValue}' \
		--output table

.PHONY: alarms
alarms:
	@aws cloudwatch describe-alarms --alarm-name-prefix local-weather \
		--query 'MetricAlarms[].{alarm: AlarmName, state: StateValue, reason: StateReason}' --output table

# Sends a test email through the real alarm. It returns to its true state at the next evaluation.
.PHONY: alarm-test
alarm-test:
	@aws cloudwatch set-alarm-state --alarm-name local-weather-observation-stale \
		--state-value ALARM --state-reason "Testing the email from make alarm-test"
