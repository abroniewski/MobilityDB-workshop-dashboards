CREATE EXTENSION MobilityDB CASCADE;

-- ***********
-- ***CREATING TABLES AND UPLOADING DATA***
-- ***********

-- Create table to copy flight data into
-- all time is in epoch and will be imported as int or float and then converted
DROP TABLE IF EXISTS flights CASCADE;

CREATE TABLE flights(
    et              bigint,
    icao24          varchar(20),
    lat             float,
    lon             float,
    velocity        float,
    heading         float,
    vertrate        float,
    callsign        varchar(10),
    onground        boolean,
    alert           boolean,
    spi             boolean,
    squawk          integer,
    baroaltitude    numeric(7,2),
    geoaltitude     numeric(7,2),
    lastposupdate   numeric(13,3),
    lastcontact     numeric(13,3)
);

-- -- statement to copy data. Location should be changes to user's local location for data
-- -- this will just import a single file, the python script below will import all csv data
--
-- COPY flights(et, icao24, lat, lon, velocity, heading, vertrate, callsign, onground, alert, spi, squawk, baroaltitude, geoaltitude, lastposupdate, lastcontact)
-- FROM '/Users/adambroniewski/DATA for Projects/OpenSky Data/states_2020-06-01-00.csv/states_2020-06-01-00.csv' DELIMITER  ',' CSV HEADER;
-- SELECT * FROM flights WHERE lat IS NOT NULL ORDER BY lat desc LIMIT 5;

-- ***********
-- ***COPY ALL DATA***
-- ***********
-- here we run the copyAllData python script to import all data into our table
-- we then check the size of the table in rows and space

SELECT COUNT(*) FROM flights;
SELECT pg_size_pretty( pg_total_relation_size('flights') );



-- ***********
-- ***SAMPLE DATA FOR CLEANING***
-- ***********
-- We will take a small sample of data to start looking for the data cleaning requirements.
-- This will help the queries run a bit faster. We use a materialized view of a single aircraft

SELECT icao24, COUNT(lat)
FROM flights
GROUP BY icao24
ORDER BY COUNT(lat) desc;

CREATE MATERIALIZED VIEW sample AS
    SELECT *
    FROM flights
    WHERE icao24 IN ('738286');

SELECT COUNT(*) FROM sample;
SELECT pg_size_pretty( pg_total_relation_size('sample') );



-- ***********
-- ***REMOVING TRANSPONDERS WITH NULL LOCATIONS***
-- ***********

-- Let's get some stats to see what we are starting with
SELECT COUNT(*) FROM flights; -- 25,769,605 rows
SELECT pg_size_pretty( pg_total_relation_size('flights') ); -- 6789 MB

WITH distinct_icao24 AS (
    SELECT DISTINCT icao24
    FROM flights
    )
SELECT COUNT(icao24)
FROM distinct_icao24; -- 35,885 distinct icao24 values

-- How many icao24's have NULL for all their latitudes? (9,357)
SELECT icao24, COUNT(lat)
FROM flights
GROUP BY icao24
HAVING COUNT(lat) = 0;

-- Delete all icao24 that have all NULL latitudes
-- icao24_with_null_lat is used to provide a list of rows that will be deleted
WITH icao24_with_null_lat AS (
    SELECT icao24, COUNT(lat)
    FROM flights
    GROUP BY icao24
    HAVING COUNT(lat) = 0
      )
DELETE
FROM flights
WHERE icao24 IN
      -- this SELECT statement is needed for the IN statement to compare against a list
    (SELECT icao24 FROM icao24_with_null_lat);

-- We can now check to see if we have successfully removed the intended rows
SELECT icao24, COUNT(lat)
FROM flights
GROUP BY icao24
HAVING COUNT(lat) = 0; -- returns 0, success!

-- Let's check on the overall impact to our dataset
SELECT COUNT(*) FROM flights; -- 20,524,309 -> dropped 5,245,296 rows
SELECT pg_size_pretty( pg_total_relation_size('flights') ); -- 3121MB

-- How many distinct icao24 values exist after the drop? (26,528 -> dropped 9,357 icao24)
WITH distinct_icao24 AS (
    SELECT DISTINCT icao24
    FROM flights
    )
SELECT COUNT(icao24)
FROM distinct_icao24;

-- ***********
-- ***EXPLORING FLIGHT WITH SOME NULLs***
-- ***********

-- Here we can find a icao24 that includes some NULL values for lat to see if there is more cleaning that
-- can or should be done

SELECT *
FROM flights
WHERE lat IS NULL
LIMIT 5;

-- We pick out a1085d to take a closer look. At this point, we can move forward with some queries,
-- and return to do more cleaning if/when we get errors or strange returns
SELECT *
FROM flights
WHERE icao24 = 'a1085d'
ORDER BY et;


-- ***********
-- ***TRANSFORMING TIME***
-- ***********
-- add column with epoch time converted to timestamp and then generate the date from the "et" column
ALTER TABLE flights
    ADD COLUMN et_ts timestamp,
    ADD COLUMN lastposupdate_ts timestamp,
    ADD COLUMN lastcontact_ts timestamp;
SELECT * FROM flights LIMIT 5;

-- use to_timestamp to convert the timestamps
UPDATE flights
    SET et_ts = to_timestamp(et),
    lastposupdate_ts = to_timestamp(lastposupdate),
    lastcontact_ts = to_timestamp(lastcontact);

-- checking to see that the conversion worked as expected
SELECT * FROM flights ORDER BY lat LIMIT 5;


-- ***********
-- ***QUERYING THE DATA***
-- ***********
-- QUERY: total flight time
-- QUERY: total ground time
--

CREATE INDEX icao24_time_index
    ON flights (icao24, et_ts);

ALTER TABLE flights
    ADD COLUMN geom geometry(Point, 4326);

UPDATE flights SET
  geom = ST_SetSRID( ST_MakePoint( lon, lat ), 4326);


---- FINAL----
CREATE TABLE flight_traj(icao24, trip, velocity, heading, vertrate, callsign, squawk, geoaltitude) AS
    SELECT icao24,
        tgeompoint_seq(array_agg(tgeompoint_inst(geom, et_ts) ORDER BY et_ts) FILTER (WHERE geom IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(velocity, et_ts) ORDER BY et_ts) FILTER (WHERE velocity IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(heading, et_ts) ORDER BY et_ts) FILTER (WHERE heading IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(vertrate, et_ts) ORDER BY et_ts) FILTER (WHERE vertrate IS NOT NULL)),
        ttext_seq(array_agg(ttext_inst(callsign, et_ts) ORDER BY et_ts) FILTER (WHERE callsign IS NOT NULL)),
        tint_seq(array_agg(tint_inst(squawk, et_ts) ORDER BY et_ts) FILTER (WHERE squawk IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(geoaltitude, et_ts) ORDER BY et_ts) FILTER (WHERE geoaltitude IS NOT NULL))
    FROM sample
    GROUP BY icao24;




