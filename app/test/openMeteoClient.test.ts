import assert from "node:assert/strict";
import { afterEach, describe, it, mock } from "node:test";
import { fetchObservation } from "../src/lib/openMeteoClient.ts";

const mudgeeraba = { slug: "mudgeeraba", latitude: -28.08, longitude: 153.37 };

const current = {
  time: "2026-10-10T04:15",
  interval: 900,
  temperature_2m: 24.2,
  apparent_temperature: 25.2,
  relative_humidity_2m: 64,
  precipitation: 0,
  rain: 0,
  weather_code: 2,
  cloud_cover: 74,
  pressure_msl: 1017.2,
  wind_speed_10m: 15.8,
  wind_direction_10m: 316,
  wind_gusts_10m: 39.2,
  is_day: 1,
};

function respondWith(body: unknown, status = 200) {
  return mock.method(globalThis, "fetch", async () => new Response(JSON.stringify(body), { status }));
}

describe("fetchObservation", () => {
  afterEach(() => mock.restoreAll());

  it("maps Open-Meteo's current conditions to an Observation", async () => {
    respondWith({ current });
    const now = new Date("2026-10-10T04:17:30Z");

    const observation = await fetchObservation(mudgeeraba, now);

    assert.deepEqual(observation, {
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
    });
  });

  it("asks for the Location's coordinates in GMT", async () => {
    const fetch = respondWith({ current });

    await fetchObservation(mudgeeraba);

    const url = new URL(String(fetch.mock.calls[0]?.arguments[0]));
    assert.equal(url.searchParams.get("latitude"), "-28.08");
    assert.equal(url.searchParams.get("longitude"), "153.37");
    assert.equal(url.searchParams.get("timezone"), "GMT");
  });

  it("treats is_day 0 as night", async () => {
    respondWith({ current: { ...current, is_day: 0 } });

    const observation = await fetchObservation(mudgeeraba);

    assert.equal(observation.isDay, false);
  });

  it("fails with Open-Meteo's reason on a non-200 response", async () => {
    respondWith({ reason: "Latitude must be in range of -90 to 90°", error: true }, 400);

    await assert.rejects(fetchObservation(mudgeeraba), /Open-Meteo returned 400: .*Latitude must be in range/);
  });

  it("fails rather than store an Observation with a missing field", async () => {
    const { temperature_2m: _, ...withoutTemperature } = current;
    respondWith({ current: withoutTemperature });

    await assert.rejects(fetchObservation(mudgeeraba), /missing numeric current\.temperature_2m/);
  });
});
