CREATE EXTENSION MobilityDB CASCADE;

-- ***********
-- ***CREATING TABLES AND UPLOADING DATA***
-- ***********

-- Create table to copy flight data into
-- all time is in epoch and will be imported as int or float and then converted
DROP TABLE IF EXISTS flights CASCADE;
DROP TABLE IF EXISTS flight_traj CASCADE;

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

CREATE MATERIALIZED VIEW single_flight AS
    SELECT *
    FROM flights
    WHERE icao24 IN ('c827a6');


SELECT COUNT(*) FROM single_flight;
SELECT pg_size_pretty( pg_total_relation_size('single_flight') );

-- ***********************************************
-- ***REMOVING WHITESPACE FROM varchar***
-- ***********************************************

UPDATE flights SET callsign = TRIM(callsign);

-- ***********************************************
-- ***REMOVING TRANSPONDERS WITH NULL LOCATIONS***
-- ***********************************************

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

-- we can create a composite index on icao24 (unique to each plane) and et_ts (timestamps of observations)
-- to help improve the performance of trajectory generation. The generation of the index is costly, but
-- the cost is less then the improvement cost of trajectory generation
CREATE INDEX icao24_time_index
    ON flights (icao24, et_ts);

-- start by creating a geometry point. This treats each latitude and longitude as a point in space.
ALTER TABLE flights
    ADD COLUMN geom geometry(Point, 4326);

UPDATE flights SET
  geom = ST_SetSRID( ST_MakePoint( lon, lat ), 4326);


-- Here we create a new table for all the trajectories. We select all of the attributes of interest
-- that change over time. We can follow the transformation from the inner call to the outer call:
-- 1. tgeompoint_inst: combines each geometry point(lat, long) with the timestamp where that point existed
-- 2. array_agg: aggregates all the instants together into a single array for each item in the group by.
--      In this case, it will create an array for each icao24
-- 3. tgeompoint_seq: constructs the array as a sequence which can be manipulated with mobilityDB functionality
-- The same approach is used for each trajectory, with the function used changing depending on the datatype
CREATE TABLE flight_traj(icao24, trip, velocity, heading, vertrate, callsign, squawk, geoaltitude) AS
    SELECT icao24,
        tgeompoint_seq(array_agg(tgeompoint_inst(geom, et_ts) ORDER BY et_ts) FILTER (WHERE geom IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(velocity, et_ts) ORDER BY et_ts) FILTER (WHERE velocity IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(heading, et_ts) ORDER BY et_ts) FILTER (WHERE heading IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(vertrate, et_ts) ORDER BY et_ts) FILTER (WHERE vertrate IS NOT NULL)),
        ttext_seq(array_agg(ttext_inst(callsign, et_ts) ORDER BY et_ts) FILTER (WHERE callsign IS NOT NULL)),
        tint_seq(array_agg(tint_inst(squawk, et_ts) ORDER BY et_ts) FILTER (WHERE squawk IS NOT NULL)),
        tfloat_seq(array_agg(tfloat_inst(geoaltitude, et_ts) ORDER BY et_ts) FILTER (WHERE geoaltitude IS NOT NULL))
    FROM flights
    GROUP BY icao24;
-- 26,528 rows created, execution: 2 m 23 s


DROP MATERIALIZED VIEW single_flight;

CREATE TABLE single_flight AS (SELECT *
                               FROM flights
                               WHERE icao24 IN ('c827a6'));

CREATE TABLE single_flight_traj AS (SELECT *
                                    FROM flight_traj
                                    WHERE icao24 IN ('c827a6'));


SELECT * FROM single_flight_traj;
SELECT callsign FROM single_flight_traj;
SELECT timestamps(callsign) FROM single_flight_traj;
SELECT instants(callsign) FROM single_flight_traj;
SELECT unnest(timestamps(callsign)) FROM single_flight_traj;


SELECT timestamps(callsign) FROM single_flight_traj;
SELECT timestampset(timestamps(callsign)) FROM single_flight_traj;
SELECT CAST(timestampset(timestamps(callsign)) AS periodset) FROM single_flight_traj;



WITH time_table AS(
    SELECT unnest(timestamps(callsign)) AS ttime
    FROM single_flight_traj
)
SELECT ttime,
       LEAD (ttime, 1) OVER()
FROM time_table
ORDER BY ttime;

SELECT periodset(segments(velocity))
FROM single_flight_traj;

SELECT periodset(segments(callsign))
FROM single_flight_traj;

SELECT ttext '(A@2000-01-01, B@2000-01-03], (D@2000-01-04, C@2000-01-05]'::period;

-- -- Restriction to a period
-- SELECT DeptNo, atPeriod(velocity, '[2012-01-01, 2012-04-01]')
-- FROM Department;




-- ********************* CONTEXT MATCHING: CREATING DATASET *********************
-- "n", "id","t","x","y","label"
-- "1","211477000-2",2021-11-14 15:00:10,705723.070725276,6225237.28619866,"01-sailing"

DROP TABLE IF EXISTS single_flight_context;
CREATE TABLE single_flight_context (
    n_int SERIAL,
    n varchar(255),
    id varchar(20),
    t timestamp,
    x float,
    y float,
    label varchar(20)
);


-- TODO: Find the correct coordinate systems
INSERT INTO single_flight_context (id, t, x, y)
SELECT icao24, et_ts,
    ST_X(ST_Transform( ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3857)) AS lon,
       ST_Y(ST_Transform( ST_SetSRID(ST_MakePoint(lon, lat), 4326), 3857)) AS lat
FROM single_flight
WHERE et_ts > '2020-06-01 05:52:40' AND et_ts < '2020-06-01 07:00:00'
ORDER BY et_ts;

SELECT * FROM single_flight_context ORDER BY t;

UPDATE single_flight_context
SET label = '01-sailing'
WHERE t > '2020-06-01 05:52:40' AND t < '2020-06-01 06:04:00';

UPDATE single_flight_context
SET label = '02-fishing'
WHERE t >= '2020-06-01 06:04:00' AND t < '2020-06-01 06:28:30';

UPDATE single_flight_context
SET label = '03-sailing'
WHERE t >= '2020-06-01 06:28:30' AND t < '2020-06-01 07:00:00';


UPDATE single_flight_context SET n = CONCAT('"',CAST ( n_int AS varchar(255)),'"'),
                          id = CONCAT('"',id,'"'),
                          label = CONCAT('"',label,'"');

SELECT * FROM single_flight_context ORDER BY t;

COPY (SELECT n, id, t, x, y, label FROM single_flight_context ORDER BY t)
    TO '/Users/adambroniewski/Documents/Work/MobilityDB-Internship/Context-Matching-Algorithm/AIS_traj/traj/1.csv'
    WITH DELIMITER ',' CSV HEADER
    QUOTE AS '*'
;

SELECT * FROM single_flight_traj;

SELECT
    column_name,
    data_type
FROM
    information_schema.columns
WHERE
    table_name = 'single_flight';