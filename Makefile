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
