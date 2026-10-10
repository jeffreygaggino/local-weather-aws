import { serve } from "@hono/node-server";
import { createApi } from "./lib/api.ts";
import { requireEnv } from "./lib/env.ts";
import { latestObservation, observationsSince } from "./lib/observationStore.ts";

const table = requireEnv("TABLE");
const location = requireEnv("LOCATION");
const port = Number(process.env.PORT ?? 8080);

const app = createApi({
  location,
  latestObservation: () => latestObservation(table, location),
  observationsSince: (since) => observationsSince(table, location, since),
});

const server = serve({ fetch: app.fetch, port }, (info) => {
  console.log(JSON.stringify({ message: "listening", port: info.port }));
});

// As PID 1 in a container, Node ignores SIGTERM unless it handles it, so ECS would wait 30s and SIGKILL.
process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
