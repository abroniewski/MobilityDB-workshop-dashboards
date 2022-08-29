DELETE FROM airframe_traj AS original_table
WHERE EXISTS
(WITH callsigns AS (SELECT icao24,
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
SELECT qac.airframe
FROM question_airframes_compiled AS qac
WHERE duration(qac.flight_period) < INTERVAL '10m'
AND original_table.icao24 = qac.airframe
    );

SELECT COUNT(*) FROM airframe_traj;