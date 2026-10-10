import type { Observation } from "./observation.ts";

/**
 * Minutes since the newest Observation's Slot started, or since the Session started if
 * nothing has been collected yet.
 */
export function observationAgeMinutes(
  latest: Observation | undefined,
  sessionStartedAt: Date,
  now: Date = new Date(),
): number {
  const since = latest ? new Date(latest.ts) : sessionStartedAt;
  return (now.getTime() - since.getTime()) / 60_000;
}
