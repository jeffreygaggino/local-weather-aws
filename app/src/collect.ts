import { locationFromEnv } from "./lib/location.ts";
import { fetchObservation } from "./lib/openMeteo.ts";

const observation = await fetchObservation(locationFromEnv());
console.log(observation);
