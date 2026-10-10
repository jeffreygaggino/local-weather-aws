// Runs against DynamoDB Local in a throwaway table, so local Observations are left alone.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { after, before, describe, it } from "node:test";
import { CreateTableCommand, DeleteTableCommand, DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { requireEnv } from "../src/lib/env.ts";
import {
  latestObservation,
  observationsSince,
  putObservation,
  sessionStartedAt,
} from "../src/lib/observationStore.ts";
import { anObservation } from "./fixtures.ts";

const table = `observations-test-${randomUUID()}`;
const client = new DynamoDBClient({ endpoint: requireEnv("DYNAMODB_ENDPOINT") });

describe("observationStore", () => {
  before(async () => {
    await client.send(
      new CreateTableCommand({
        TableName: table,
        BillingMode: "PAY_PER_REQUEST",
        AttributeDefinitions: [
          { AttributeName: "location", AttributeType: "S" },
          { AttributeName: "ts", AttributeType: "S" },
        ],
        KeySchema: [
          { AttributeName: "location", KeyType: "HASH" },
          { AttributeName: "ts", KeyType: "RANGE" },
        ],
      }),
    );
  });

  after(async () => {
    await client.send(new DeleteTableCommand({ TableName: table }));
  });

  it("has no latest Observation for an empty Location", async () => {
    assert.equal(await latestObservation(table, "nowhere"), undefined);
  });

  it("keeps one Observation per Slot, the last one written", async () => {
    const location = "same-slot";
    await putObservation(table, anObservation({ location, collectedAt: "2026-10-10T04:17:00.000Z" }));
    await putObservation(table, anObservation({ location, collectedAt: "2026-10-10T04:20:00.000Z" }));

    const all = await observationsSince(table, location, new Date(0));

    assert.equal(all.length, 1);
    assert.equal(all[0]?.collectedAt, "2026-10-10T04:20:00.000Z");
  });

  it("returns the newest Slot as latest regardless of write order", async () => {
    const location = "write-order";
    await putObservation(table, anObservation({ location, ts: "2026-10-10T04:30:00Z" }));
    await putObservation(table, anObservation({ location, ts: "2026-10-10T04:00:00Z" }));
    await putObservation(table, anObservation({ location, ts: "2026-10-10T04:15:00Z" }));

    assert.equal((await latestObservation(table, location))?.ts, "2026-10-10T04:30:00Z");
  });

  it("returns Observations from `since` onwards, newest first", async () => {
    const location = "range";
    for (const ts of ["2026-10-10T03:45:00Z", "2026-10-10T04:00:00Z", "2026-10-10T04:15:00Z", "2026-10-10T04:30:00Z"]) {
      await putObservation(table, anObservation({ location, ts }));
    }

    const recent = await observationsSince(table, location, new Date("2026-10-10T04:00:00Z"));

    assert.deepEqual(
      recent.map((o) => o.ts),
      ["2026-10-10T04:30:00Z", "2026-10-10T04:15:00Z", "2026-10-10T04:00:00Z"],
    );
  });

  it("keeps Locations separate", async () => {
    await putObservation(table, anObservation({ location: "here", ts: "2026-10-10T05:00:00Z" }));
    await putObservation(table, anObservation({ location: "there", ts: "2026-10-10T06:00:00Z" }));

    assert.equal((await latestObservation(table, "here"))?.ts, "2026-10-10T05:00:00Z");
  });

  it("reads the Session start from the table's creation time", async () => {
    const started = await sessionStartedAt(table);

    assert.ok(Date.now() - started.getTime() < 60_000, `expected a recent creation time, got ${started.toISOString()}`);
  });
});
