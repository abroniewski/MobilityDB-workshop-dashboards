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


COPY flights(et, icao24, lat, lon, velocity, heading, vertrate, callsign, onground, alert, spi, squawk, baroaltitude, geoaltitude, lastposupdate, lastcontact)
FROM '/Users/adambroniewski/DATA for Projects/OpenSky Data/states_2020-06-01-00.csv/states_2020-06-01-00.csv' DELIMITER  ',' CSV HEADER;


SELECT * FROM flights LIMIT 5;