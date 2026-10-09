import { requireEnv } from "./env.ts";

export interface Location {
  slug: string;
  latitude: number;
  longitude: number;
}

export function locationFromEnv(): Location {
  return {
    slug: requireEnv("LOCATION"),
    latitude: Number(requireEnv("LATITUDE")),
    longitude: Number(requireEnv("LONGITUDE")),
  };
}
