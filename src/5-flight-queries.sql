-- Average flight speeds during flight
-- Highest average speeds during flight
SELECT callsign, twavg(velocity) AS average_velocity
FROM flight_traj
WHERE twavg(velocity) IS NOT NULL
AND twavg(velocity) < 1500
ORDER BY twavg(velocity) desc;


-- Max speeds during flight
SELECT icao24, maxValue(velocity) AS max_speed
FROM flight_traj
WHERE maxValue(velocity) IS NOT NULL -- remove flights that did not have velocity data
AND maxValue(velocity) < 1500 -- commercial and private flight max = 1500m/s
GROUP BY icao24, maxValue(velocity)
ORDER BY maxValue(velocity) desc;

-- Flights completed by private pilots (estimate)
SELECT COUNT(callsign) AS private_flight
FROM flight_traj
WHERE (maxValue(velocity) IS NOT NULL -- remove flights without velocity
    AND maxValue(velocity) <= 65) -- sport aircraft max is 140mph (65m/s)
AND (maxValue(geoaltitude) IS NOT NULL -- remove flights without altitude
    AND maxValue(geoaltitude) <= 5500); --18,000ft (5,500m) max for private pilot

-- Count of commercial flights (estimate)
SELECT COUNT(callsign) AS commercial_flight
FROM flight_traj
WHERE (maxValue(velocity) IS NOT NULL
    AND maxValue(velocity) > 65)
AND (maxValue(geoaltitude) IS NOT NULL
    AND maxValue(geoaltitude) > 5500);


-- Max speeds during flight
SELECT floor(maxValue(velocity) / 20) * 20 AS velocity_bin, count(*)
FROM flight_traj
WHERE (maxValue(velocity) > 10 -- remove flights that are assumed to be taxing only
AND maxValue(velocity) < 1500) -- commercial and private flight max = 1500m/s
GROUP BY velocity_bin
ORDER BY velocity_bin;


-- Ascending: Where are flights ascending given some interval of time?
WITH
-- The flight_traj_time_slice CTE is clipping all the temporal columns
-- to the user specified time-range.
flight_traj_time_slice (icao24, callsign, time_slice_trip, time_slice_geoaltitude,
                        time_slice_vertrate) AS
    (SELECT icao24,
            callsign,
            atPeriod(trip, period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)'),
            atPeriod(geoaltitude, period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)'),
            atPeriod(vertrate,
                     period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)')
     FROM flight_traj_sample TABLESAMPLE SYSTEM (20)),

-- There are 3 things happening in the flight_traj_time_slice_ascent CTE:
-- 1. atRange: Clips the temporal data to create ranges where the vertrate
-- was between '[1, 20]'. This vertrate means an aircraft was ascending.
-- 2. sequenceN: Selects the first sequence from the generated sequences.
--  This first sequence is takeoff and eliminates mid-flight ascents.
-- 3. atPerido: Returns the period of the first sequence.
flight_traj_time_slice_ascent(icao24, callsign, ascending_trip, ascending_geoaltitude,
                              ascending_vertrate) AS
    (SELECT icao24,
            callsign,
            atPeriod(time_slice_trip,
                     period(sequenceN(
                         atRange(time_slice_vertrate, floatrange '[1,20]'), 1))),
            atPeriod(time_slice_geoaltitude,
                     period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'),
                                      1))),
            atPeriod(time_slice_vertrate,
                     period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'),
                                      1)))
     FROM flight_traj_time_slice),

-- The final_output CTE uses unnest to unpack the temporal data into rows for visualization in Grafana.
-- Each row will contain a latitude, longitude and the altitude and vertrate at those locations.
final_output AS
    (SELECT icao24,
            callsign,
            getValue(unnest(instants(ascending_geoaltitude))) AS geoaltitude,
            getValue(unnest(instants(ascending_vertrate)))    AS vertrate,
            ST_X(getValue(unnest(instants(ascending_trip))))  AS lon,
            ST_Y(getValue(unnest(instants(ascending_trip))))  AS lat
     FROM flight_traj_time_slice_ascent)

SELECT *
FROM final_output
WHERE vertrate IS NOT NULL
  AND geoaltitude IS NOT NULL;

SELECT * FROM flight_traj_sample
ORDER BY icao24
LIMIT 50;