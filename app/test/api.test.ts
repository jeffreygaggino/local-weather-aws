import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { createApi } from "../src/lib/api.ts";
import type { Observation } from "../src/lib/observation.ts";
import { anObservation } from "./fixtures.ts";

const now = new Date("2026-10-10T12:00:00Z");

function apiWith({ latest, history = [] }: { latest?: Observation; history?: Observation[] } = {}) {
  const sinceCalls: Date[] = [];
  const app = createApi({
    location: "mudgeeraba",
    latestObservation: async () => latest,
    observationsSince: async (since) => {
      sinceCalls.push(since);
      return history;
    },
    now: () => now,
  });
  return { app, sinceCalls };
}

describe("GET /latest", () => {
  it("returns 404 before anything has been collected", async () => {
    const res = await apiWith().app.request("/latest");

    assert.equal(res.status, 404);
    assert.deepEqual(await res.json(), { error: "no observations yet" });
  });
});

describe("GET /history", () => {
  it("defaults to the last 6 hours", async () => {
    const { app, sinceCalls } = apiWith();

    const res = await app.request("/history");

    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { location: "mudgeeraba", hours: 6, observations: [] });
    assert.equal(sinceCalls[0]?.toISOString(), "2026-10-10T06:00:00.000Z");
  });

  it("returns the Observations for the requested window", async () => {
    const history = [anObservation({ ts: "2026-10-10T11:45:00Z" }), anObservation({ ts: "2026-10-10T11:30:00Z" })];
    const { app, sinceCalls } = apiWith({ history });

    const res = await app.request("/history?hours=2");

    assert.deepEqual(await res.json(), { location: "mudgeeraba", hours: 2, observations: history });
    assert.equal(sinceCalls[0]?.toISOString(), "2026-10-10T10:00:00.000Z");
  });

  it("allows up to 24 hours", async () => {
    const res = await apiWith().app.request("/history?hours=24");

    assert.equal(res.status, 200);
  });

  for (const hours of ["0", "25", "abc"]) {
    it(`rejects hours=${hours} without querying`, async () => {
      const { app, sinceCalls } = apiWith();

      const res = await app.request(`/history?hours=${hours}`);

      assert.equal(res.status, 400);
      assert.equal(sinceCalls.length, 0);
    });
  }
});
