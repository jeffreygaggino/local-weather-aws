import { requireEnv } from "./lib/env.ts";
import { locationFromEnv } from "./lib/location.ts";
import { putObservation } from "./lib/observations.ts";
import { fetchObservation } from "./lib/openMeteo.ts";

const table = requireEnv("TABLE");

const observation = await fetchObservation(locationFromEnv());
await putObservation(table, observation);

console.log(
  JSON.stringify({ message: "observation written", location: observation.location, ts: observation.ts }),
);
