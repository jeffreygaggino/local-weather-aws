/** Current weather at one Location for one Slot. */
export interface Observation {
  location: string;
  /** Slot start, UTC ISO 8601 (e.g. 2026-10-10T04:15:00Z). */
  ts: string;
  /** When the collector fetched this, UTC ISO 8601. */
  collectedAt: string;
  temperatureC: number;
  apparentTemperatureC: number;
  relativeHumidityPct: number;
  precipitationMm: number;
  rainMm: number;
  /** WMO weather interpretation code. */
  weatherCode: number;
  cloudCoverPct: number;
  pressureMslHpa: number;
  windSpeedKmh: number;
  windDirectionDeg: number;
  windGustsKmh: number;
  isDay: boolean;
}
