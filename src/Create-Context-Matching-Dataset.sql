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

-- ********************* END CONTEXT MATCHING: CREATING DATASET *********************