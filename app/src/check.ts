import { requireEnv } from "./lib/env.ts";
import { observationAgeMinutes } from "./lib/observationAge.ts";
import { latestObservation, sessionStartedAt } from "./lib/observationStore.ts";

const table = requireEnv("TABLE");
const location = requireEnv("LOCATION");

const latest = await latestObservation(table, location);
const ageMinutes = observationAgeMinutes(latest, await sessionStartedAt(table));

console.log(
  JSON.stringify({
    message: "observation age",
    location,
    latestTs: latest?.ts ?? null,
    ageMinutes: Math.round(ageMinutes),
  }),
);
