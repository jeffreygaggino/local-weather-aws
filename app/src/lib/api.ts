import { Hono } from "hono";
import type { Observation } from "./observation.ts";

const DEFAULT_HISTORY_HOURS = 6;
const MAX_HISTORY_HOURS = 24;

export interface ApiDeps {
  location: string;
  latestObservation: () => Promise<Observation | undefined>;
  observationsSince: (since: Date) => Promise<Observation[]>;
  now?: () => Date;
}

export function createApi({ location, latestObservation, observationsSince, now = () => new Date() }: ApiDeps): Hono {
  const app = new Hono();

  app.get("/health", (c) => c.json({ ok: true }));

  app.get("/latest", async (c) => {
    const observation = await latestObservation();
    if (!observation) return c.json({ error: "no observations yet" }, 404);
    return c.json(observation);
  });

  app.get("/history", async (c) => {
    const hours = Number(c.req.query("hours") ?? DEFAULT_HISTORY_HOURS);
    if (!Number.isFinite(hours) || hours <= 0 || hours > MAX_HISTORY_HOURS) {
      return c.json({ error: `hours must be greater than 0 and at most ${MAX_HISTORY_HOURS}` }, 400);
    }
    const since = new Date(now().getTime() - hours * 60 * 60 * 1000);
    const observations = await observationsSince(since);
    return c.json({ location, hours, observations });
  });

  return app;
}
