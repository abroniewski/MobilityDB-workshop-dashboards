CREATE EXTENSION MobilityDB CASCADE;


CREATE TABLE AISInput(
  T timestamp,
  TypeOfMobile varchar(50),
  MMSI integer,
  Latitude float,
  Longitude float,
  navigationalStatus varchar(50),
  ROT float,
  SOG float,
  COG float,
  Heading integer,
  IMO varchar(50),
  Callsign varchar(50),
  Name varchar(100),
  ShipType varchar(50),
  CargoType varchar(100),
  Width float,
  Length float,
  TypeOfPositionFixingDevice varchar(50),
  Draught float,
  Destination varchar(50),
  ETA varchar(50),
  DataSourceType varchar(50),
  SizeA float,
  SizeB float,
  SizeC float,
  SizeD float,
  Geom geometry(Point, 4326)
);

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

COPY AISInput(T, TypeOfMobile, MMSI, Latitude, Longitude, NavigationalStatus, ROT, SOG, COG, Heading, IMO, CallSign, Name, ShipType,CargoType, Width, Length, TypeOfPositionFixingDevice, Draught, Destination, ETA, DataSourceType, SizeA, SizeB, SizeC, SizeD, Geom)

FROM '/Users/adambroniewski/Downloads/ais.csv' DELIMITER  ',' CSV HEADER;

UPDATE AISInput SET
  NavigationalStatus = CASE NavigationalStatus WHEN 'Unknown value' THEN NULL END,
  IMO = CASE IMO WHEN 'Unknown' THEN NULL END,
  ShipType = CASE ShipType WHEN 'Undefined' THEN NULL END,
  TypeOfPositionFixingDevice = CASE TypeOfPositionFixingDevice
  WHEN 'Undefined' THEN NULL END,
  Geom = ST_SetSRID( ST_MakePoint( Longitude, Latitude ), 4326);

CREATE TABLE AISInputFiltered AS
SELECT DISTINCT ON(MMSI,T) *
FROM AISInput
WHERE Longitude BETWEEN -16.1 and 32.88 AND Latitude BETWEEN 40.18 AND 84.17;
SELECT COUNT(*) FROM AISInputFiltered;

CREATE TABLE Ships(MMSI, Trip, SOG, COG) AS
SELECT MMSI,
  tgeompoint_seq(array_agg(tgeompoint_inst( ST_Transform(Geom, 25832), T) ORDER BY T)),
  tfloat_seq(array_agg(tfloat_inst(SOG, T) ORDER BY T) FILTER (WHERE SOG IS NOT NULL)),
  tfloat_seq(array_agg(tfloat_inst(COG, T) ORDER BY T) FILTER (WHERE COG IS NOT NULL))
FROM AISInputFiltered
GROUP BY MMSI;

ALTER TABLE Ships ADD COLUMN Traj geometry;
UPDATE Ships SET Traj= trajectory(Trip);

DELETE FROM Ships
WHERE length(Trip) = 0 OR length(Trip) >= 1500000;


WITH
    TimeShips AS (
        SELECT MMSI,
               atPeriod(S.Trip, period '[2018-01-04 01:00:00, 2018-01-04 06:30:00)' ) AS trip
        FROM
            Ships S
),
    TimeClosestShips As (
        SELECT
            S1.MMSI AS "boat1", S2.MMSI AS "boat_2",
            startValue( atMin(S1.trip <-> S2.trip)) as closet_distance,
            startTimestamp( atMin(S1.trip <-> S2.trip)) as time_at_closest_dist,
            S1.trip as "b1_trip",
            S2.trip as "b2_trip"
        FROM
            TimeShips S1, TimeShips S2
        WHERE
            S1.MMSI > S2.MMSI AND
            dwithin(S1.Trip, S2.Trip, 300)
)
SELECT  t.boat1, t.boat_2, t.closet_distance, t.time_at_closest_dist,
        ST_X( ST_Transform( valueAtTimestamp(b1_trip, time_at_closest_dist), 4326) ) as b1_lng,
        ST_Y( ST_Transform( valueAtTimestamp(b1_trip, time_at_closest_dist), 4326) ) as b1_lat,
        ST_X( ST_Transform( valueAtTimestamp(b2_trip, time_at_closest_dist), 4326) ) as b2_lng,
        ST_Y( ST_Transform( valueAtTimestamp(b2_trip, time_at_closest_dist), 4326) ) as b2_lat

FROM TimeClosestShips t;