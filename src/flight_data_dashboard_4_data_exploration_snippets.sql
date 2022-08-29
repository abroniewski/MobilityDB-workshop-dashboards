    -- returns icao + all callsigns for each period where callsign changes
WITH callsigns AS (SELECT icao24,
                          startvalue(unnest(segments(callsign))) AS callsign_changes
                   FROM airframe_traj),
    -- aggregates the number of callsign changes a single airframe
    -- has in a day
     too_many_callsign AS (SELECT icao24,
                                  COUNT(callsign_changes) AS number_of_callsign_changes
                           FROM callsigns
                           GROUP BY icao24),
    -- returns the airframes that had a number of callsign changes greater than
    -- the WHERE clause
    questionable_airframes AS (SELECT too_many_callsign.icao24,
                                      number_of_callsign_changes
                               FROM too_many_callsign
                               WHERE number_of_callsign_changes > 10),
-- give the "questionable" airframes with the number of changes
-- and the periods at which changes occurred to allow for inspection
-- of what might be going on.
-- Looks like icao24 = 000001 should be dropped, and some of the airframes
-- have issues with string editing
    question_airframes_compiled AS (SELECT airframe_traj.icao24 AS airframe,
                                           startvalue(unnest(segments(callsign))) AS callsign,
                                           unnest(segments(callsign))::period AS flight_period,
                                           number_of_callsign_changes
                                    FROM airframe_traj,
                                         questionable_airframes AS qa
                                    WHERE airframe_traj.icao24 IN (qa.icao24))
SELECT qac.airframe,
       qac.callsign,
       qac.number_of_callsign_changes AS num_call_changes,
       qac.flight_period,
       to_char(duration(qac.flight_period), 'HH24h:MIm:SSs') AS flight_time

FROM question_airframes_compiled AS qac
ORDER BY number_of_callsign_changes desc;


    -- return flights with flight interval under 10min
WITH callsigns AS (SELECT icao24,
                          startvalue(unnest(segments(callsign))) AS callsign_changes
                   FROM airframe_traj),

     too_many_callsign AS (SELECT icao24,
                                  COUNT(callsign_changes) AS number_of_callsign_changes
                           FROM callsigns
                           GROUP BY icao24),

    questionable_airframes AS (SELECT too_many_callsign.icao24,
                                      number_of_callsign_changes
                               FROM too_many_callsign ),

    question_airframes_compiled AS (SELECT airframe_traj.icao24 AS airframe,
                                           startvalue(unnest(segments(callsign))) AS callsign,
                                           unnest(segments(callsign))::period AS flight_period,
                                           number_of_callsign_changes
                                    FROM airframe_traj,
                                         questionable_airframes AS qa
                                    WHERE airframe_traj.icao24 IN (qa.icao24))
SELECT qac.airframe,
       qac.callsign,
       qac.number_of_callsign_changes AS num_call_changes,
       qac.flight_period,
       to_char(duration(qac.flight_period), 'HH24h:MIm:SSs') AS flight_time
FROM question_airframes_compiled AS qac
WHERE duration(qac.flight_period) < INTERVAL '10m'
ORDER BY flight_time;



SELECT icao24,
       startvalue(unnest(segments(callsign))) AS callsign,
       unnest( segments( callsign ) )::period AS flight_period
FROM airframe_traj
WHERE icao24 IN ('ae04b0');

SELECT
    COUNT(*) FILTER (WHERE geom IS NULL) AS null_geom,
    COUNT(*) FILTER (WHERE velocity IS NULL) AS null_velocity
FROM flights;