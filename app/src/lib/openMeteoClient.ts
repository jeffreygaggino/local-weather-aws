import type { Location } from "./location.ts";
import type { Observation } from "./observation.ts";

const CURRENT_FIELDS = [
  "temperature_2m",
  "apparent_temperature",
  "relative_humidity_2m",
  "precipitation",
  "rain",
  "weather_code",
  "cloud_cover",
  "pressure_msl",
  "wind_speed_10m",
  "wind_direction_10m",
  "wind_gusts_10m",
  "is_day",
] as const;

type CurrentField = (typeof CURRENT_FIELDS)[number];

interface CurrentResponse {
  current: { time: string; interval: number } & Record<CurrentField, number>;
}

export async function fetchObservation(location: Location, now = new Date()): Promise<Observation> {
  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.searchParams.set("latitude", String(location.latitude));
  url.searchParams.set("longitude", String(location.longitude));
  url.searchParams.set("current", CURRENT_FIELDS.join(","));
  url.searchParams.set("timezone", "GMT");

  const response = await fetch(url, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok) {
    throw new Error(`Open-Meteo returned ${response.status}: ${await response.text()}`);
  }
  const { current } = (await response.json()) as CurrentResponse;

  for (const field of CURRENT_FIELDS) {
    if (typeof current[field] !== "number") {
      throw new Error(`Open-Meteo response missing numeric current.${field}`);
    }
  }

  return {
    location: location.slug,
    // current.time is the Slot start in GMT without seconds or zone, e.g. "2026-10-10T04:15".
    ts: `${current.time}:00Z`,
    collectedAt: now.toISOString(),
    temperatureC: current.temperature_2m,
    apparentTemperatureC: current.apparent_temperature,
    relativeHumidityPct: current.relative_humidity_2m,
    precipitationMm: current.precipitation,
    rainMm: current.rain,
    weatherCode: current.weather_code,
    cloudCoverPct: current.cloud_cover,
    pressureMslHpa: current.pressure_msl,
    windSpeedKmh: current.wind_speed_10m,
    windDirectionDeg: current.wind_direction_10m,
    windGustsKmh: current.wind_gusts_10m,
    isDay: current.is_day === 1,
  };
}
