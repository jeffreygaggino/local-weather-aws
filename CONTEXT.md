# Local Weather

Collects current weather conditions for a Location on a fixed schedule and serves them back over a small API. The whole system exists only while a Session is running.

## Language

**Location**:
A named place weather is collected for, identified by a slug (e.g. `mudgeeraba`) and fixed coordinates. There is exactly one today.
_Avoid_: City, site, place

**Observation**:
The current weather conditions at one Location for one Slot, as reported by Open-Meteo.
_Avoid_: Reading, row, item, record, weather data

**Slot**:
The 15-minute interval an Observation describes, identified by its start time. A Location has at most one Observation per Slot.
_Avoid_: Timestamp, tick

**Observation Age**:
Minutes between now and the start of the newest Observation's Slot for a Location, or since the Session started if there is none yet. The single measure of whether the system is healthy.
_Avoid_: Staleness, lag, freshness

**Watchdog**:
A scheduled check, independent of collection, that measures Observation Age and reports it. If the Watchdog itself stops reporting, that counts as unhealthy too.
_Avoid_: Health check, monitor, alarm job

**Session**:
The period between bringing the stack up and tearing it down. Observations exist only for the Session they were collected in; tearing down discards them.
_Avoid_: Run, deployment, environment
