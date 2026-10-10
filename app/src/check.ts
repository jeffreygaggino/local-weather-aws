import { requireEnv } from "./lib/env.ts";
import { latestObservation, sessionStartedAt } from "./lib/observationStore.ts";

const table = requireEnv("TABLE");
const location = requireEnv("LOCATION");

const latest = await latestObservation(table, location);
const since = latest ? new Date(latest.ts) : await sessionStartedAt(table);
const ageMinutes = (Date.now() - since.getTime()) / 60_000;

console.log(
  JSON.stringify({
    message: "observation age",
    location,
    latestTs: latest?.ts ?? null,
    ageMinutes: Math.round(ageMinutes),
  }),
);
