import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { observationAgeMinutes } from "../src/lib/observationAge.ts";
import { anObservation } from "./fixtures.ts";

const sessionStartedAt = new Date("2026-10-10T03:00:00Z");

describe("observationAgeMinutes", () => {
  it("measures from the start of the newest Observation's Slot", () => {
    const latest = anObservation({ ts: "2026-10-10T04:15:00Z" });

    assert.equal(observationAgeMinutes(latest, sessionStartedAt, new Date("2026-10-10T04:24:00Z")), 9);
  });

  it("ignores when the Observation was collected", () => {
    const latest = anObservation({ ts: "2026-10-10T04:15:00Z", collectedAt: "2026-10-10T04:50:00Z" });

    assert.equal(observationAgeMinutes(latest, sessionStartedAt, new Date("2026-10-10T04:54:00Z")), 39);
  });

  it("measures from the start of the Session when nothing has been collected", () => {
    assert.equal(observationAgeMinutes(undefined, sessionStartedAt, new Date("2026-10-10T03:20:00Z")), 20);
  });
});
