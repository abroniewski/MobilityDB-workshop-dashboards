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
CREATE TABLE airframe_traj(icao24, trip, velocity, heading, vertrate, callsign, squawk, geoaltitude) AS
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


CREATE TABLE single_airframe_traj AS (
    SELECT *
    FROM airframe_traj
    WHERE icao24 IN ('c827a6'));