import type { Observation } from "../src/lib/observation.ts";

export function anObservation(overrides: Partial<Observation> = {}): Observation {
  return {
    location: "mudgeeraba",
    ts: "2026-10-10T04:15:00Z",
    collectedAt: "2026-10-10T04:17:30.000Z",
    temperatureC: 24.2,
    apparentTemperatureC: 25.2,
    relativeHumidityPct: 64,
    precipitationMm: 0,
    rainMm: 0,
    weatherCode: 2,
    cloudCoverPct: 74,
    pressureMslHpa: 1017.2,
    windSpeedKmh: 15.8,
    windDirectionDeg: 316,
    windGustsKmh: 39.2,
    isDay: true,
    ...overrides,
  };
}
