-- Highest average speeds during flight
SELECT icao24, callsign, twavg(velocity) AS average_velocity
FROM flight_traj
WHERE twavg(velocity) IS NOT NULL -- remove flights that did not have velocity data
ORDER BY twavg(velocity) desc;


-- Max speeds during flight
SELECT icao24, maxValue(velocity) AS max_speed
FROM flight_traj
WHERE maxValue(velocity) IS NOT NULL -- remove flights that did not have velocity data
AND maxValue(velocity) < 1500 -- commercial and private flight max = 1500m/s
GROUP BY icao24, maxValue(velocity)
ORDER BY maxValue(velocity) desc;

-- sport aircraft
SELECT icao24, callsign, maxValue(velocity) AS max_speed
FROM flight_traj
WHERE maxValue(velocity) IS NOT NULL -- remove flights that did not have velocity data
AND maxValue(velocity) < 70 -- commercial and private flight max = 1500m/s
ORDER BY maxValue(velocity) desc;

alt = 3050

-- Max speeds during flight
SELECT floor(maxValue(velocity) / 20) * 20 AS velocity_bin, count(*)
FROM flight_traj
WHERE (maxValue(velocity) > 10 -- remove flights that are assumed to be taxing only
AND maxValue(velocity) < 1500) -- commercial and private flight max = 1500m/s
GROUP BY velocity_bin
ORDER BY velocity_bin;

-- Ascending
tgeompoint_seq(atPeriod(velocity, period(atRange(vertrate, floatrange '[1,20]')))) --attempting to return the x,y for all locations where the flight is ascending

SELECT icao24,
       callsign,
       period(atRange(vertrate, floatrange '[1,20]')) AS ascending_period,
       atPeriod(trip, period(atRange(vertrate, floatrange '[1,20]'))) AS ascending_location_array

FROM flight_traj
WHERE icao24 IN ('7c351b');

-- Ascending: Where are flights ascending given some interval of time?

EXPLAIN ANALYSE WITH flight_traj_time_slice (icao24, callsign, trip, geoaltitude, full_vertrate, time_slice_vertrate) AS
         (SELECT icao24,
                 callsign,
                 trip,
                 geoaltitude,
                 vertrate,
                 atPeriod(vertrate,
                          period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)') -- return only the portion of flight in this time period
          FROM flight_traj_sample TABLESAMPLE SYSTEM (20)),

     flight_traj_time_slice_ascent(icao24, callsign, ascending_period, time_ascent_slice_vertrate, altitude_slice,
                                   vertrate_slice) AS
         (SELECT icao24,
                 callsign,
                 period(atRange(full_vertrate, floatrange '[1,20]')), -- used to return the beginning and ending of the overall flight ascent
                 atPeriod(trip, period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'), 1) )),
                 atPeriod(geoaltitude, period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'), 1))),
                 atPeriod(full_vertrate, period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'), 1)))
          FROM flight_traj_time_slice),

     final_output AS
         (SELECT icao24,
                 callsign,
                 lower(ascending_period)                                      AS start_ascent,
                 upper(ascending_period)                                      AS end_ascent,
                 time_ascent_slice_vertrate                                   AS time_slice,
                 trajectory(time_ascent_slice_vertrate)                       AS qgis_trajectory, -- will give a line
                 getValue(unnest(instants(altitude_slice)))                   AS altitude_slice,
                 getValue(unnest(instants(vertrate_slice)))                   AS vertrate_slice,
                 ST_X(getValue(unnest(instants(time_ascent_slice_vertrate)))) AS lon,             -- will give the longitude
                 ST_Y(getValue(unnest(instants(time_ascent_slice_vertrate)))) AS lat              -- will give the longitude
          FROM flight_traj_time_slice_ascent
        )
SELECT *
FROM final_output
WHERE vertrate_slice IS NOT NULL
  AND altitude_slice IS NOT NULL;


SELECT * FROM flight_traj LIMIT 1;

SELECT pg_typeof(atPeriod(trip, period(atRange(vertrate, floatrange '[1,20]'))))
FROM flight_traj
LIMIT 1;


SELECT *
FROM airframe_traj;