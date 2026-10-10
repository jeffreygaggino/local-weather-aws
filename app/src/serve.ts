import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { requireEnv } from "./lib/env.ts";
import { latestObservation, observationsSince } from "./lib/observationStore.ts";

const table = requireEnv("TABLE");
const location = requireEnv("LOCATION");
const port = Number(process.env.PORT ?? 8080);

const DEFAULT_HISTORY_HOURS = 6;
const MAX_HISTORY_HOURS = 24;

const app = new Hono();

app.get("/health", (c) => c.json({ ok: true }));

app.get("/latest", async (c) => {
  const observation = await latestObservation(table, location);
  if (!observation) return c.json({ error: "no observations yet" }, 404);
  return c.json(observation);
});

app.get("/history", async (c) => {
  const hours = Number(c.req.query("hours") ?? DEFAULT_HISTORY_HOURS);
  if (!Number.isFinite(hours) || hours <= 0 || hours > MAX_HISTORY_HOURS) {
    return c.json({ error: `hours must be greater than 0 and at most ${MAX_HISTORY_HOURS}` }, 400);
  }
  const since = new Date(Date.now() - hours * 60 * 60 * 1000);
  const observations = await observationsSince(table, location, since);
  return c.json({ location, hours, observations });
});

const server = serve({ fetch: app.fetch, port }, (info) => {
  console.log(JSON.stringify({ message: "listening", port: info.port }));
});

// As PID 1 in a container, Node ignores SIGTERM unless it handles it, so ECS would wait 30s and SIGKILL.
process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
