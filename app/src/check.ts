import { requireEnv } from "./lib/env.ts";
import { putObservationAge } from "./lib/metricsClient.ts";
import { observationAgeMinutes } from "./lib/observationAge.ts";
import { latestObservation, sessionStartedAt } from "./lib/observationStore.ts";

const table = requireEnv("TABLE");
const location = requireEnv("LOCATION");
// Set in AWS only; locally the Watchdog just prints.
const metricNamespace = process.env.METRIC_NAMESPACE;

const latest = await latestObservation(table, location);
const ageMinutes = observationAgeMinutes(latest, await sessionStartedAt(table));

if (metricNamespace) await putObservationAge(metricNamespace, location, ageMinutes);

console.log(
  JSON.stringify({
    message: "observation age",
    location,
    latestTs: latest?.ts ?? null,
    ageMinutes: Math.round(ageMinutes),
    published: Boolean(metricNamespace),
  }),
);
