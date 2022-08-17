-- ***********
-- ***CREATING TABLES AND UPLOADING DATA***
-- ***********

-- Create table to copy flight data into
-- all time is in epoch and will be imported as int or float and then converted
DROP TABLE IF EXISTS flights;

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
    baroaltitude    float,
    geoaltitude     float,
    lastposupdate   float,
    lastcontact     float
);

-- statement to copy data. Location should be changes to user's local location for data
COPY flights(et, icao24, lat, lon, velocity, heading, vertrate, callsign, onground, alert, spi, squawk, baroaltitude, geoaltitude, lastposupdate, lastcontact)
FROM '/Users/adambroniewski/DATA for Projects/OpenSky Data/states_2020-06-01-00.csv/states_2020-06-01-00.csv' DELIMITER  ',' CSV HEADER;

-- checking to make sure import worked correctly
SELECT * FROM flights ORDER BY lat LIMIT 5;

-- ***********
-- ***TRANSFORMING TIME***
-- ***********
-- add column with epoch time converted to timestamp and then generate the date from the "et" column
ALTER TABLE flights
    ADD COLUMN et_ts timestamp,
    ADD COLUMN lastposupdate_ts timestamp,
    ADD COLUMN lastcontact_ts timestamp;

UPDATE flights
    SET et_ts = to_timestamp(et),
    lastposupdate_ts = to_timestamp(lastposupdate),
    lastcontact_ts = to_timestamp(lastcontact);

-- checking to see how
SELECT * FROM flights ORDER BY lat LIMIT 5;