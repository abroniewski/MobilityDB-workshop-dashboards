# Dashboard and Visualization for Flight Data

# Contents

The module covers the following topics:

- Setting up a Grafana dashboard and connecting to a database
- Visualizing time-series data
- Visualizing geographic points on a map
- Visualizing statistics from temporal aggregations
- Visualizing statistics from multiple queries returning temporal aggregations
- Returning value changes from temporal data
- Visualizing spatial statistics from nested temporal conditions (intrinsic and dynamic)

# Tools

The tools used in this module are as follows:

- MobilityDB, on top of PostgreSQL and PostGIS
- Grafana (version 9.0.7)

# Setting up the Dashboard and Connecting to Data Source

Data for the workshop is loaded into a MobilityDB database hosted on Azure, with all login information provided in the [Sign-in and Connect to Data Source](https://www.notion.so/Dashboard-and-Visualization-of-Ship-Trajectories-AIS-246e16838096443ea2bfa9be554a9a44) section below.

The workshop is using the following settings in Grafana to connect to the postgres server on Azure. More detailed instruction to setup Grafana can be found in section 2.3 to 2.5 of the Dashboard and Visualization of Ship Trajectories (AIS) workshop.

- Name: OpenSkyLOCAL
- Host: *20.79.254.53:5432*
- Database: opensky
- User: *mobilitydb-guest*
- Password: *mobilitydb@guest*
- TLS/SSL Mode: *disable*
- Version: *12+*

The data used for this workshop provided by [The OpenSky Network](http://www.opensky-network.org). This is data from a 24hr period from June 1, 2020 ([dataset link](https://opensky-network.org/datasets/states/2020-06-01/)). The raw data is originally provided in separate CSV documents for each hour of the day.

# Creating a Dashboard

Open a new browser and go to [http://localhost:3000/](http://localhost:3000/) to work in your instance of Grafana. With a new dashboard we can start creating the panels below.

# Visualizing 24hr Flight Pattern of Single Airplane

We will start by looking at a single airplane. Grafana proves to be a good way to quickly visualize our dataset and can be useful to support pre-processing and cleaning. If using a connection to the Azure database, required tables are already created. 

A full description of each parameter is included in the [OpenSky original dataset readme](https://opensky-network.org/datasets/states/README.txt). The table structure in the Azure dataset after loading and transformations looks like the following:

![First row of table “single_airframe”, with 24hrs of flight information for airplane “c827a6”](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled.png)

First row of table “single_airframe”, with 24hrs of flight information for airplane “c827a6”

![Full table “single_airframe_traj” for airplane “c827a6” with data in mobilityDB trajectories format](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%201.png)

Full table “single_airframe_traj” for airplane “c827a6” with data in mobilityDB trajectories format

![First row of table “flight_traj_sample”, which includes 200 flight trajectories.](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%202.png)

First row of table “flight_traj_sample”, which includes 200 flight trajectories.

## Change Timezone in Grafana

Make Sure you are visualizing the data in the correct timezone. The data we had was in UTC. To change the timezone,

1. Click on the time-range panel on the top-right of the window. 
    
    ![grafana_timerange_panel_open.png](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/grafana_timerange_panel_open.png)
    
2. In the pop-up window, on the bottom there is “Change time settings”. Click that to set the desired timezone.   

## Visualize the Coordinates of a Single Airplane

Let’s visualize the latitude and longitude coordinates of an airplane’s journey throughout the day. For this one we will not color the geo-markers but it is possible to color them using some criterion.

1. Add a new panel
2. Select “OpenSkyLOCAL” as the data source
3. In Format as, change “Time series” to “Table” and choose “Edit SQL”
4. Here you can add your SQL queries. Let’s replace the exist query with the following SQL script:
    
    ```sql
    --icao24 is the unique identifier for each airframe (airplane)
    SELECT et_ts, icao24, lat, lon
    -- TABLESAMPLE SYSTEM (n) returns only n% of the data from the table. 
    FROM flights TABLESAMPLE SYSTEM (5)
    WHERE icao24 IN ('738286') AND $__timeFilter(et_ts) 
    ```
    
5. Change the visualization type to “*Geomap”*.
6. The options (visualization settings - on the right side of the screen) should be as follows:
    
    **Panel Options**
    
    - Title →GPS location over time
    
    **Map View**
    
    - Initial view: For this one zoom in on the visualization on the panel as you see fit and then click “use current map settings” button.
    
    **Data Layer**
    
    - Layer type: → “markers”
    - Style size → Fixed Value: 2
    - Color → Green

In this visualization we can see that the airplane is visiting different countries and almost completing a loop. This indicates that there are more than 1 trips (flights) completed by this single airframe. The coordinates are sparse because we are sampling the results using “TABLESAMPLE SYSTEM (5)” in our query. This is done to speed up the visualization.

![single_airframe_geopoints_vs_time.png](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/single_airframe_geopoints_vs_time.png)

## Velocity vs Time graph of a Single Airplane

Following the similar steps to add a Geomap panel as before, we include the following SQL script. Note $__timeFilter() is a Grafana global variable. This global variable will inject time constraint SQL-conditions from Grafana’s time range panel.

1. In Format as, use “Time series”

```sql
SELECT
  et_ts AS "time",
  velocity
FROM flights
WHERE icao24 = 'c827a6' AND $__timeFilter(et_ts)
```

1. Change the visualization type to “Time Series”.
2. The options (visualization settings - on the right side of the screen) should be as follows:
    
    **Panel Options**
    
    - Title → Single AirFrame - Velocity vs Time

In the visualization we can see clearly that on this day, this airframe took 3 flights. That is why its speed curve has 3 humps. The zero speed towards the end of each hump is a clear indicator that plane stopped, thus it must have completed its flight.

![single_airframe_velocity_vs_time.png](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/single_airframe_velocity_vs_time.png)

## Altitude vs Time graph of a Single Airplane

Follow the similar steps to add a Geomap panel as before, we include the following SQL script.

1. In Format as, we have “Time series”

```sql
SELECT
  et_ts AS "time",
  baroaltitude, geoaltitude
FROM flights
WHERE icao24 = 'c827a6' AND $__timeFilter(et_ts)
```

1. Change the visualization type to “Time Series”.
2. The options (visualization settings - on the right side of the screen) should be as follows:
    
    **Panel Options**
    
    - Title → Single AirFrame - Altitude vs Time

In the visualization we can again see that on this day, the airframe took 3 flights, as altitude reaches zero between each flight. There is some noise in the data, which appear as spikes. This would be almost impossible to spot in a tabular format, but on a line graph these data anomalies can be easily identified.

![single_airframe_altitude_vs_time.png](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/single_airframe_altitude_vs_time.png)

## Vertical-Rate vs Time graph of a Single Airplane

Follow the similar steps to add a Geomap panel as before, we include the following SQL script.

1. In Format as, we have “Time series”

```sql
SELECT
  et_ts AS "time",
  vertrate
FROM flights
WHERE icao24 = 'c827a6' AND $__timeFilter(et_ts)
```

1. Change the visualization type to “Time Series”.
2. The options (visualization settings - on the right side of the screen) should be as follows:
    
    **Panel Options**
    
    - Title → Single AirFrame - Verticle-Rate vs Time

The positive values here represents the ascent of the plane. While at cruising altitude, the plane has almost zero vertical-rate and during decent this value becomes negative. So a sequence of positive values, then zero values followed by negative values would represent a single flight.  

![single_airframe_vertrate_vs_time.png](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/single_airframe_vertrate_vs_time.png)

## Callsign vs Time graph of a Single Airplane

Follow the similar steps to add a Geomap panel as before, we include the following SQL script.

1. In Format as, we have “Table”

```sql
SELECT
  min(et_ts) AS "time", callsign
FROM flights
WHERE icao24 = 'c827a6'
GROUP BY callsign
```

1. Change the visualization type to “Table”.
2. The options (visualization settings - on the right side of the screen) should be as follows:
    
    **Panel Options**
    
    - Title → Single AirFrame - Callsign vs Time

In the visualization we can see that this airplane completed 3 flights and started the 4th one towards the very end of the day. We also see there is some NULL data in the callsign column which is why the first timestamp doesn’t have a corresponding callsign.

![single_airframe_callsign_vs_time.png](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/single_airframe_callsign_vs_time.png)

# Aggregating Flight Statistics

## Average velocity of each flight

Following the same approach that was used for other panels, we can pull aggregated statistics for all flights.

1. In Format as, we have “Table”
    
    ```sql
    -- Average flight speeds during flight
    SELECT callsign,twavg(velocity) AS average_velocity
    FROM flight_traj
    WHERE twavg(velocity)IS NOT NULL -- drop rows without velocity data
    AND twavg(velocity) < 1500 -- removes erroneous data
    ORDER BY twavg(velocity) desc;
    ```
    
2. Change the visualization type to “Bar gauge”.
3. The options (visualization settings - on the right side of the screen) should be as follows
    
    **Panel Options**
    
    - Title → Average Flight Speed
    
    **Bar gauge**
    
    - Orientation → Horizontal
    
    **Standard Options**
    
    - Unit → meters/second (m/s)
    - Min → 200
    
    The settings we adjust improve the visualization by cutting the bar graph values of 0-200, improving the resolution at higher ranges to see differences.
    
    ![Untitled](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%203.png)
    

## Number of private and commercial flights

With Grafana, we can easily combine results from multiple queries in the same visualization, simplifying the queries themselves. Here we apply some domain knowledge of sport pilot aircraft license limits for altitude and speed to provide an estimated count of each.

1. In Format as, we have “Table”
    
    ```sql
    -- Count of flights completed by private pilots (estimate)
    SELECT COUNT(callsign) AS private_flight
    FROM flight_traj
    WHERE (maxValue(velocity) IS NOT NULL -- remove flights that did not have velocity data
        AND maxValue(velocity) <= 65) -- sport aircraft max is 140mph (65m/s)
    AND (maxValue(geoaltitude) IS NOT NULL -- remove flights that did not have altitude data
        AND maxValue(geoaltitude) <= 5500); --18,000ft (5,500m) max for private pilot
    
    -- Count of commercial flights (estimate)
    SELECT COUNT(callsign) AS commercial_flight
    FROM flight_traj
    WHERE (maxValue(velocity) IS NOT NULL 
        AND maxValue(velocity) > 65) 
    AND (maxValue(geoaltitude) IS NOT NULL 
        AND maxValue(geoaltitude) > 5500);
    ```
    
    In Grafana, when we are in the query editor we can click on “+ Query” at the bottom to add multiple queries that provide different results.
    
    ![Multiple queries providing results for a single visualization](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%204.png)
    
    Multiple queries providing results for a single visualization
    
2. Change the visualization type to “Stat”.
    
    To label the data for each result separately, choose “Overrides” at the top of the options panel on the right. Here you can override global panel settings for specific attributes as shown below.
    
    ![Override options for panel with multiple queries](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%205.png)
    
    Override options for panel with multiple queries
    

The final statistics visualization will look like like this:

![Statistic visualization of number of flights by license type](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%206.png)

Statistic visualization of number of flights by license type

# Creating Trajectories

## Per AirFrame Trajectories

Now we are ready to construct airframe or airplane trajectories out of their individual observations. Each “icao24” in our dataset represents a single airplane. 

We can create a composite index on icao24 (unique to each plane) and et_ts (timestamps of observations) to help improve the performance of trajectory generation. 

```sql
CREATE INDEX icao24_time_index
    ON flights (icao24, et_ts);
```

We create trajectories for a single airframe because:

- this query serves as a simple example of how to use mobilityDB to create trajectories
- these kind of trajectories can be very important for plane manufacturer, as they are interested in the airplane’s analysis.
- it becomes building a building block the query that we need to create flights trajectories. (Each row would represent a single flight, where flight is identified by icao24 & callsign)

```sql
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
```

Here we create a new table for all the trajectories. We select all of the attributes of interest that change over time. We can follow the transformation from the inner call to the outer call:

- tgeompoint_inst: combines each geometry point(lat, long) with the timestamp where that point existed
- array_agg: aggregates all the instants together into a single array for each item in the group by. In this case, it will create an array for each icao24
- tgeompoint_seq: constructs the array as a sequence which can be manipulated with mobilityDB functionality. The same approach is used for each trajectory, with the function used changing depending on the datatype

## Per Flight Trajectories

Right now we have, in a single row airframe's entire day's trip information. We would like to segment that information per flight (airframe flying under a specific callsign). This query segments the trajectories (in temporal columns) based on time period from call sign. Below we explain the query and the reason behind segmenting the data this way.

```sql
CREATE TABLE flight_traj(
    icao24, callsign, flight_period, trip, velocity, heading, vertrate, squawk, geoaltitude)
    AS
SELECT icao24                                                    AS icao24,
       startvalue(unnest(segments(callsign)))                    AS callsign,
       unnest(segments(callsign))::period                        AS flight_period,
       atPeriod(trip, unnest(segments(callsign))::period)        AS trip,
       atPeriod(velocity, unnest(segments(callsign))::period)    AS velocity,
       atPeriod(heading, unnest(segments(callsign))::period)     AS heading,
       atPeriod(vertrate, unnest(segments(callsign))::period)    AS vertrate,
       atPeriod(squawk, unnest(segments(callsign))::period)      AS squawk,
       atPeriod(geoaltitude, unnest(segments(callsign))::period) AS geoaltitude
FROM airframe_traj;
```

**Note:** There are some edge cases to watch out for when creating trajectories.

edge case 1: We could have created the above (table ”flight_traj”) per flight trajectories by simply including “callsign” in the GROUP BY statement in the query from per airframe trajectories. The final query would that we explained would look like: 

```sql
-- copy query from per airframe trajectories
    GROUP BY icao24, callsign;
```

The **problem** with this solution: Suppose an airplane was used for the same route (it got assigned same callsign) twice, then our above solution would put the trajectory of data of 2 flights in a single row, making it look that this belongs to a single flight. Next when we’ll do per flight analysis we would get an anomaly in the results.

# TODO

The **Solution:** We need to segment the data in a way that also takes into account the temporal distance between the same callsign of an airframe.

## Flights ascending heat-map given some interval of time?

**Note:** This is an expensive query, and so for quick response we are using a sampled table/ view in this query. So naming convention is:

- “flight_traj_sample” is just a sampled version of “flight_traj”

```sql
WITH
-- This CTE is just clipping all the temporal columns to the user specified time-range.
flight_traj_time_slice (icao24, callsign, time_slice_trip, time_slice_geoaltitude, time_slice_vertrate) AS
		(SELECT icao24,
		       callsign,
		       atPeriod(trip, period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)'),
		       atPeriod(geoaltitude, period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)'),
		       atPeriod(vertrate, period '[2020-06-01 03:00:00, 2020-06-01 20:30:00)') -- return only the portion of flight in this time period
		FROM flight_traj_sample TABLESAMPLE SYSTEM (20)),

-- There are 3 things happening in this CTE.
-- 1. First further clips temporal columns and creates ranges that fall in the floatrange '[1, 20]', using atRagne
-- 2. Selects the first sequences from the generated sequences, using sequenceN
-- 3. Returns the period of the first sequence
flight_traj_time_slice_ascent(icao24, callsign, ascending_trip, ascending_geoaltitude, ascending_vertrate) AS
		(SELECT icao24,
		       callsign,
		       atPeriod(time_slice_trip, period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'), 1) )),
		       atPeriod(time_slice_geoaltitude, period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'), 1))),
		       atPeriod(time_slice_vertrate, period(sequenceN(atRange(time_slice_vertrate, floatrange '[1,20]'), 1)))
		FROM flight_traj_time_slice),

-- This CTE unpacks the temporal columns into rows for visualization in grafana, using unnest. 
final_output AS
		(SELECT icao24,
		       callsign,
		       getValue(unnest(instants(ascending_geoaltitude)))                   AS geoaltitude,
		       getValue(unnest(instants(ascending_vertrate)))                   AS vertrate,
		       ST_X(getValue(unnest(instants(ascending_trip)))) AS lon,             -- will give the longitude
		       ST_Y(getValue(unnest(instants(ascending_trip)))) AS lat              -- will give the latitude
		FROM flight_traj_time_slice_ascent)

SELECT *
FROM final_output
WHERE vertrate IS NOT NULL
  AND geoaltitude IS NOT NULL;
```

Tips for **QGIS** visualization: QGIS uses geometry points for visualization, so for that in the third CTE you can use trajectory function on ascending_trip and unnest the result.

We will modify make the follow adjustments for the visualization.

1. Change the visualization type to “Geomap”.
2. The options (visualization settings - on the right side of the screen) should be as follows:
    
    **Panel Options**
    
    - Title → Flight Ascent in Time Window
    
    **Data Layer:**
    
    - Layer type: Markers
    - Location: Coords
    - Latitude field: lat
    - Longitude field: lon
    - Styles
        - Size: altitude_slice
        - Min: 1
        - Max: 10
        - Color: altitude_slice
        - Fill opacity: 0.1
    
    **Standard Options:**
    
    - Unit: meter(m)
    - Color scheme: Red-Yellow-Green (by value)

Here is a zoomed in version of how each flight ascent will look like:

![Zoomed in view of flight ascent](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%207.png)

Zoomed in view of flight ascent

The final visualization will look like the below.

![Final visualization with multiple flight ascents](Dashboard%20and%20Visualization%20for%20Flight%20Data%207410963696e846a8a65ccf7b55c62c86/Untitled%208.png)

Final visualization with multiple flight ascents