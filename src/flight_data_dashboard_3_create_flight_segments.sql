

WITH different_flights AS (SELECT icao24,
                                  startvalue(unnest(segments(callsign))) AS callsign,
                                  unnest(segments(callsign) )::period AS flight_period
                           FROM single_airframe_traj)
SELECT *
FROM different_flights;


-- UPDATE FULL TABLE

DROP INDEX IF EXISTS idx_airframe_traj_trip;
CREATE INDEX idx_airframe_traj_trip
ON airframe_traj USING gist (trip);

DROP INDEX IF EXISTS idx_airframe_traj_velocity;
CREATE INDEX idx_airframe_traj_velocity
ON airframe_traj USING gist (velocity);

DROP INDEX IF EXISTS idx_airframe_traj_callsign;
CREATE INDEX idx_airframe_traj_callsign
ON airframe_traj USING gist (callsign);

-- Each row from airframe will create a new row in flight_traj depending on when the
-- callsign changes, regardless of whether a plane repeats the same flight multiple
-- times in any period

-- Airplane123 (airframe_traj) |-------------------------|
-- Flightpath1 (flight_traj)   |-----|
-- Flightpath2 (flight_traj)         |--------|
-- Flightpath1 (flight_traj)                  |-------|
-- Flightpath3 (flight_traj)                          |--|

DROP TABLE IF EXISTS flight_traj CASCADE;
CREATE TABLE flight_traj(icao24, callsign, flight_period, trip, velocity, heading,
                         vertrate, squawk, geoaltitude)
AS
    -- callsign sequence unpacked into rows to split all other temporal sequences.
WITH airframe_traj_with_unpacked_callsign AS
         (SELECT icao24,
                 trip,
                 velocity,
                 heading,
                 vertrate,
                 squawk,
                 geoaltitude,
                 startValue(unnest(segments(callsign))) AS start_value_callsign,
                 unnest(segments(callsign))::period     AS callsign_segment_period
          FROM airframe_traj)

SELECT icao24                                         AS icao24,
       start_value_callsign                           AS callsign,
       callsign_segment_period                        AS flight_period,
       atPeriod(trip, callsign_segment_period)        AS trip,
       atPeriod(velocity, callsign_segment_period)    AS velocity,
       atPeriod(heading, callsign_segment_period)     AS heading,
       atPeriod(vertrate, callsign_segment_period)    AS vertrate,
       atPeriod(squawk, callsign_segment_period)      AS squawk,
       atPeriod(geoaltitude, callsign_segment_period) AS geoaltitude
FROM airframe_traj_with_unpacked_callsign;


SELECT * FROM flight_traj LIMIT 1;

DROP MATERIALIZED VIEW IF EXISTS flight_traj_sample;
CREATE MATERIALIZED VIEW flight_traj_sample AS
    (
    SELECT *
    FROM flight_traj
    WHERE trip IS NOT NULL
    AND vertrate IS NOT NULL
    ORDER BY icao24
    LIMIT 200
    );

REFRESH MATERIALIZED VIEW flight_traj_sample;
SELECT * FROM flight_traj_sample
ORDER BY icao24;
-- NOTE: There are lots of trips with NULL velocity, or other parameters....
SELECT COUNT(*) FROM airframe_traj WHERE airframe_traj.vertrate IS NULL;

SELECT * FROM flight_traj_sample LIMIT 1;