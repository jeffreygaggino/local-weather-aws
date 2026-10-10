include app/local.env

DDB = AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	aws dynamodb --endpoint-url $(DYNAMODB_ENDPOINT) --region $(AWS_REGION)

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
	@docker compose up -d --wait
	@cd app && npm run -s db:create

.PHONY: local-down
local-down:
	@docker compose down

.PHONY: collect
collect:
	@cd app && npm run -s collect


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
