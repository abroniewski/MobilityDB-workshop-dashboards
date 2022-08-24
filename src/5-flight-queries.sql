-- Highest average speeds during flight
SELECT icao24, callsign, twavg(velocity) AS average_velocity
FROM flight_traj
WHERE twavg(velocity) IS NOT NULL
ORDER BY twavg(velocity) desc;

-- Max speeds during flight
SELECT icao24, callsign, maxValue(velocity) AS max_speed
FROM flight_traj
WHERE maxValue(velocity) IS NOT NULL
ORDER BY maxValue(velocity) desc;

-- Ascending
SELECT icao24,
       callsign,
       period(atRange(vertrate, floatrange '[1,20]')) AS ascending_period,
       atPeriod(trip, period(atRange(vertrate, floatrange '[1,20]'))) AS ascending_location_array,
    tgeompoint_seq(atPeriod(velocity, period(atRange(vertrate, floatrange '[1,20]')))) --attempting to return the x,y for all locations where the flight is ascending
FROM flight_traj
WHERE icao24 IN ('7c351b');

-- Ascending: Here I am trying to get a query that will visaully show all lat, long points on a map when planes
-- are ascending between a certain time period.
SELECT icao24,
       callsign,
       period(atRange(vertrate, floatrange '[1,20]')) AS ascending_period,
    lower(period(atRange(vertrate, floatrange '[1,20]'))) AS start_ascent,
    upper(period(atRange(vertrate, floatrange '[1,20]'))) AS end_ascent,
    atPeriod(vertrate, period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)' )
FROM flight_traj
WHERE icao24 IN ('7c351b');

SELECT *
FROM airframe_traj;