

WITH different_flights AS (SELECT icao24,
                                  startvalue(unnest(segments(callsign))) AS callsign,
                                  unnest(segments(callsign))::period AS flight_period
                           FROM single_flight_traj)
SELECT *
FROM different_flights;


-- WITH different_flights(icao24, single_flight) AS (SELECT icao24, unnest(segments(callsign))::period FROM single_flight_traj)
-- SELECT icao24, array_agg(single_flight order by single_flight)
-- FROM different_flights
-- GROUP BY icao24;



-- WITH time_table AS(
--     SELECT unnest(timestamps(callsign)) AS ttime
--     FROM single_flight_traj
-- )
-- SELECT ttime,
--        LEAD (ttime, 1) OVER()
-- FROM time_table
-- ORDER BY ttime;

-- -- UPDATE FULL TABLE
-- CREATE TABLE flight_traj(icao24, tvelocity) AS
-- WITH different_flights AS (
--     SELECT icao24, unnest( segments( callsign ) )::period AS flight_segment
--     FROM airframe_traj
-- )
-- SELECT df.icao24, atPeriod(sf.velocity, df.flight_segment)
-- FROM different_flights df, airframe_traj sf;

-- CREATE SAMPLE TABLE
DROP TABLE few_flights_per_row_traj;
CREATE TABLE few_flights_per_row_traj(icao24, callsign, tvelocity) AS
WITH different_flights AS (
    SELECT icao24,
          startvalue(unnest(segments(callsign))) AS callsign,
          unnest(segments(callsign))::period AS flight_period
   FROM single_flight_traj
)
SELECT df.icao24, df.callsign, atPeriod(sf.velocity, df.flight_period)
FROM different_flights df, single_airframe_traj sf;

SELECT * FROM few_flights_per_row_traj;