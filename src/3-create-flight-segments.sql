

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


-- THIS IS THE CORRECT QUERY TO BUILD FULL VELOCITY SLICE!!!!
DROP TABLE IF EXISTS flight_traj;
EXPLAIN (ANALYSE, VERBOSE) CREATE TABLE flight_traj(
    icao24, callsign, flight_period, trip, velocity, heading, vertrate, squawk, geoaltitude)
    AS
SELECT icao24                                                    AS icao24,
       startvalue(unnest(segments(callsign)))                    AS callsign,
       unnest(segments(callsign))::period                        AS flight_period,
       atPeriod(trip, unnest(segments(callsign))::period)        AS trip,
       atPeriod(velocity, unnest(segments(callsign))::period)    AS velocity,
       atPeriod(heading, unnest(segments(callsign))::period)     AS heading,
       atPeriod(vertrate, unnest(segments(callsign))::period)    AS vertrate,
       atPeriod(squawk, unnest(segments(callsign))::period)      AS squawk,
       atPeriod(geoaltitude, unnest(segments(callsign))::period) AS geoaltitude
FROM airframe_traj;

SELECT * FROM flight_traj;

DROP MATERIALIZED VIEW flight_traj_sample;
CREATE MATERIALIZED VIEW flight_traj_sample AS
    (
    SELECT *
    FROM flight_traj
    LIMIT 200
    );


-- NOTE: There are lots of trips with NULL velocity, or other parameters....
SELECT COUNT(*) FROM airframe_traj WHERE airframe_traj.vertrate IS NULL;

SELECT * FROM flight_traj_sample LIMIT 1;