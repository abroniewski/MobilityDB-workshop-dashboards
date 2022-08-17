# Dashboard and Visualization of Ship Trajectories (AIS)

This module builds on the Managing Ship Trajectories (AIS) module by creating a business intelligence dashboard to visualize and manipulate data. The module shows how to setup a Grafana dashboard with an existing database, create basic visualizations, set properties for different outputs, and use Variables to create dynamic visuals.

# Contents

The module covers the following topics:

- Setting up a Grafana dashboard and connecting to a database
- Visualize a statistic from simple aggregations
- Visualize spatial frequency with a heat-map (not aggregated)
- Visualize frequency in spatial extent with a heat-map (pre-aggregated)
- Visualize spatio-temporal proximate objects
- Create dynamic queries with variables

# Tools

The tools used in this module are as follows:  (todo Add version of these softwares)

- MobilityDB, on top of PostgreSQL and PostGIS
- QGIS
- Grafana

# Setting up Postgres Database

Follow section 1.1 to 1.6 of the AIS workshop to setup a Postgres database with the AIS data that will be used for visualization.

**or**

Connect to Azure server to access prepared data. (Instructions

# Setting up Visualization Dashboard

We can use [Grafana](https://grafana.com/), an open-source technology, to create a business intelligence dashboard. This will allow different users to setup their own queries and visualizations, or easily slice through data in a visual way for non-technical users.

Start by setting up Grafana on your system:

1. [macOS](https://grafana.com/docs/grafana/latest/setup-grafana/installation/mac/)
    
    ```
    brew update
    brew install grafana
    brew services start grafana
    ```
    
2. [Debian or Ubuntu](https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/)
    
    ```
    # Note These are instructions for Grafana Enterprise Edition (via APT repository), which they recommend. It includes all the Open Source features and can also use Enterprise
    # features if you have a License.
    
    # Setup Grafana Keys
    sudo apt-get install -y apt-transport-https
    sudo apt-get install -y software-properties-common wget
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    
    # Add repository for stable releases
    echo "deb https://packages.grafana.com/enterprise/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
    
    # Install Grafana
    sudo apt-get update
    sudo apt-get install grafana-enterprise
    ```
    
3. [Windows](https://grafana.com/docs/grafana/latest/setup-grafana/installation/windows/)

# Sign in and Connect to Data Source

We can now sign in to Grafana by going to [http://localhost:3000/](http://localhost:3000/). Setup a new account if needed. Additional instructions to login can be found here following the [build your first dashboard instructions.](https://grafana.com/docs/grafana/latest/getting-started/build-first-dashboard/)

Next, we **add a data source** for Grafana to interact with. In this case, we can follow the [Grafana instructions for adding a data source](https://grafana.com/docs/grafana/latest/datasources/add-a-data-source/) and search for [Postgre](https://grafana.com/docs/grafana/latest/datasources/postgres/)SQL as the data source.

The workshop is using the following settings to connect to the postgres server on Azure.

- Name: *DanishAIS*
- Host: *20.79.254.53:5432*
- Database: danishais
- User: mobilitydb-guest
- Password: *password*
- TLS/SSL Mode: *disable*
- Version: *12+*

Then press save and test

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled.png)

```sql
# Use to find host and port if non-defaults were used
SELECT name, setting
FROM pg_settings
WHERE name = 'port' OR name = 'listen_addresses';
```

# Creating a Dashboard

With the dashboard setup and configure, we will now build different panels to visualize data in intuitive ways. 

## Speed of Individual Ships

Let’s visualize the speed of the ships using the previously build query. Here we will represent it as a statistic with a color gradient.

1. Add a new panel
2. Select *DanishAIS* as the data source
3. In Format as, change “Time series” to “Table” and choose “Edit SQL”
4. Here you can add your SQL queries. Let’s replace the exist query with the following SQL script:
    
    ```sql
    SELECT mmsi, ABS(twavg(SOG) * 1.852 - twavg(speed(Trip))* 3.6 ) AS SpeedDifference
    FROM Ships
    ORDER BY SpeedDifference DESC
    LIMIT 5;
    ```
    
5. We can also quickly do some datatype transformations to help Grafana correctly interpret the incoming data. Next to the Query button, select “Transform”, add “Convert field type” and choose *mmsi* as *String.*
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%201.png)
    
6. We will modify some of the visualization options in the panel on the right. 
    
    First, choose *stat* as the visualization
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%202.png)
    
    **Panel Options:** Give the panel the title *Incorrect AIS Boat Speed Reporting*
    
    **Value Options:**
    
    - Show: All values
    - Fields: speeddifference
        
        ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%203.png)
        
    
    *Note: we can include a limit here instead of in our SQL query as well.*
    
    **Stat Styles:**
    
    - Orientation: Horizontal
        
        ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%204.png)
        
    
    **Standard Options:**
    
    - Unit:  Velocity → meter/second (m/s). *Note: you can scroll in the drop down menu to see all options.*
    - Color scheme: Green-Yellow-Red (by value)
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%205.png)
    
    **Thresholds:** 
    
    - remove the existing threshold (little trash can icon)
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%206.png)
    

The final visualization will look like like this:

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%207.png)

## Routes Used Most Frequently Visualized with a Static Heat Map

We can visualize the routes used by ships with a heat map generated from individual GPS points of the ships. This approach is quite data heavy, so we will use TABLESAMPLE SYSTEM to specify an approximate percentage of the data to use. This is a “quick” way to make things work, however an alternative approach could be to use the postGIS [ST_AsGeoJSON](https://postgis.net/docs/ST_AsGeoJSON.html) to generate shapes in geoJSON format which can be used in [Grafana’s World Map Panel plugin](https://grafana.com/grafana/plugins/grafana-worldmap-panel/).

1. Add a panel, select DanishAIS as the data source and Format As Table.
2. Using Edit SQL, add the following SQL code:
    
    ```sql
    # NOTE: TABLESAMPLE SYSTEM(40) returns ~40% of the data.
    SELECT
      latitude,
      longitude,
      mmsi
    FROM aisinputfiltered TABLESAMPLE SYSTEM (40)
    ```
    
3. Change the visualization type to *Geomap*. Note that at the writing of this tutorial, the Geomap plugin is in beta and has some minor bugs. 
4. On the map, zoom in to fit the data points into the frame and modify the following visualization options:
    
    **Panel Options:**
    
    - Title: Route Usage Frequency
    
    **Map View:**
    
    - Use current map setting (this will use the current zoom and positioning level as default)
    - Share View: enable (this will sync up the movement and zoom across multiple maps on the same dashboard)
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%208.png)
    
    **Data Layer:**
    
    - Layer type: Heatmap
    - Location: Coords
    - Latitude field: latitude
    - Longitude field: longitude
    - Weight values: 0.1
    - Radius: 1
    - Blur: 5
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%209.png)
    
    **Standard Options:**
    
    - Color scheme: Blue-Yellow-Red (by value)
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2010.png)
    

The final visualization will look like this:

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2011.png)

## Number of Boats Moving Through a Given Area

1. Create a new panel, and set DanishAIS as the Source, Format as: “Table”.
2. Select visualization as: “Geomap”
3. Add this SQL in the “SQL editor” section

```sql
-- Table with bounding boxes over regions of interest
WITH ports(port_name, port_geom, lat,lng)
as (
    SELECT p.port_name, p.port_geom, lat,lng
    FROM
    ( VALUES ( 'Rodby', ST_MakeEnvelope(651135, 6058230, 651422, 6058548, 25832)::geometry, 54.53,11.06 ),
            ('Puttgarden', ST_MakeEnvelope(644339, 6042108, 644896, 6042487, 25832)::geometry, 54.64,11.36 )
    ) as p(port_name, port_geom, lat,lng)
    )

SELECT P.port_name, 
        sum( numSequences( atGeometry( S.Trip, P.port_geom))) AS trips_intersect_with_port,
        p.lat, 
        p.lng
FROM ports as P, Ships as S
WHERE intersects(S.Trip, P.port_geom)
GROUP BY P.port_name, P.lat, P.lng
```

1. The options should be as follows:
    
    **Data Layer**
    
    - Layer type: → “markers”
    - Style Size: → “Fixed” and value: 20
    - Color: → “trips_intersect_with_port” (This will color  points on the map based on this value)
    
    **Standard options**
    
    - Min → 88
    - Max → 97  (Note normally we shouldn’t have to set these values but due to a bug in Grafana, we have to here.)
    - Color scheme → “Green-Yellow-Red (by value)”

In the visualization below we can see port Rodby has a higher number of ships coming and going to it and that’s why it is colored Red. This visualization can show relative activity of ships in regions and ports. 

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2012.png)

## Boats in Close Proximity in a Given Time Range

Follow the similar steps to add a Geomap panel, and include the following SQL script:

```sql
-- 2 CTEs are created to help make these queries more user friendly; TimeShips and TimeClosestShips.

WITH 
		-- The TimeShips CTE returns the data for a time period from 1am to 6:30am
    TimeShips AS (
        SELECT MMSI, 
               atPeriod(S.Trip, period '[2018-01-04 01:00:00, 2018-01-04 06:30:00)' ) AS trip
        FROM 
            Ships S
),
		-- The TimeClosestShips CTE returns the time, location, and closest distance of the boats
		-- that are within 300m of each other. Note the use of dwithin in the WHERE clause
		-- improves performance by limiting the computation to only those ships that were within
		-- 300m.
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
-- The final SELECT is used to project the time_at_closest_distance onto the sequence of
-- locations to return the lat and long of both ships. 
SELECT  t.boat1, t.boat_2, t.closet_distance, t.time_at_closest_dist,
        ST_X( ST_Transform( valueAtTimestamp(b1_trip, time_at_closest_dist), 4326) ) as b1_lng,
        ST_Y( ST_Transform( valueAtTimestamp(b1_trip, time_at_closest_dist), 4326) ) as b1_lat,
        ST_X( ST_Transform( valueAtTimestamp(b2_trip, time_at_closest_dist), 4326) ) as b2_lng,
        ST_Y( ST_Transform( valueAtTimestamp(b2_trip, time_at_closest_dist), 4326) ) as b2_lat
        
FROM TimeClosestShips t;
```

To add the points to the map modify the following options:

**Panel Options:**

- Title: Ships within 300m

**Map View:**

- Share view: enabled

**Data Layer:**

- Layer 1: rename to Boat1
- Layer type: Heatmap
- Location: Coords
- Latitude field: b1_lat
- Longitude field: b1_lng
- Radius: 5
- Blur: 15

Click on “+ Add layer” to add another layer to the data, this time using b2_lat and b2_long as the coordinates. We can also add a layer to show the precise locations with markers for both ships. For the Boat 1 and Boat 2 Locations, we use the following options:

**Data Layer:**

- Value: 1
- Color: select different color for each boat.

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2013.png)

The final visualization looks like the below. Note that the same ship can be within 300m to multiple other ships in the same time frame. This can result in a higher frequency of results in a heat map view than expected. SQL queries should be modified to ensure they are correctly interpreted. It can also help to include the tooltip for layers to allow users to see the data behind the visualization.

Not surprisingly, we see there are lots of results for proximity within ports. We can avoid including results in ports by excluding all results that occur within an envelope defined by ST_MakeEnvelope, as seen in previous queries. 

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2014.png)

The cluster of ships in the middle of this harbour all represent the same ship that was found to have a closest distance to other ships at various times while in the port.

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2015.png)

# Dynamic Dashboards - Creating Variables

We need variables in Grafana to manipulate time-range that goes as input to the MobilityDB query. Default Grafana macro format isn’t flexible enough. So we’ll be creating a drop-down like variable **“FromTime”**. 

1. In the dashboard window, click “Dashboard settings” icon. (the gear symbol, on the top-slightly-right of the window).
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2016.png)
    

1. Click on the “Variables” in the next window. (On the top-left side of the screen)
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2017.png)
    
2. You’ll see a sreen that explains the variables in grafana and also points to the [Templates and variables documentation](https://grafana.com/docs/grafana/latest/variables/). Click on the “Add variable” button.
3.  In “General”
    - Name → FromTime
    - Type → Custom
4. In “Custom options” manually all the time ranges with 1 hour increment. e.g. “2018-01-04 00:00:00, 2018-01-04 01:00:00 … 2018-01-04 23:00:00”
5. You get a screen like below. Towards the buttom there is also a “Preview of values” that shows what drop-down options for the created variable you’ll have.
    
    ![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2018.png)
    

1. Similarly create another variable called “ToTime” with values shifted 1 hour. So starting value would be “2018-01-04 01:00:00” and the final value will be “2018-01-05 00:00:00”

Now we can modify some of the queries to return results from a specific time window. We now have the ability to slive through time and query. 

## Dynamic Query: Number of Boats Moving Through a Given Area in a Certain Time Period

In the query code we just need to make slight changes for it to take time values from the variables. In the Select section of the original query, shown below:

```sql
sum( numSequences( atGeometry( S.Trip, P.port_geom))) AS trips_intersect_with_port,
```

We just need to modify it as:

```sql
sum(numSequences(atGeometry( atPeriod(S.Trip, period '[$FromTime, $ToTime)'), P.port_geom))) AS trips_intersect_with_port,
```

Essentially we just wrapped ‘S.Trip’ around with ‘atPeriod() and passed our custom period range. Giving us the final query:

```sql
-- Table with bounding boxes over regions of interest
WITH ports(port_name, port_geom, lat,lng)
as (
    SELECT p.port_name, p.port_geom, lat,lng
    FROM
    ( VALUES ( 'Rodby', ST_MakeEnvelope(651135, 6058230, 651422, 6058548, 25832)::geometry, 54.53,11.06 ),
            ('Puttgarden', ST_MakeEnvelope(644339, 6042108, 644896, 6042487, 25832)::geometry, 54.64,11.36 )
    ) as p(port_name, port_geom, lat,lng)
    )

SELECT P.port_name, 
        sum(numSequences(atGeometry(atPeriod(S.Trip, period '[$FromTime, $ToTime)'), 
                                    P.port_geom))) AS trips_intersect_with_port,
        p.lat, 
        p.lng
FROM ports as P, Ships as S
WHERE intersects(S.Trip, P.port_geom)
GROUP BY P.port_name, P.lat, P.lng
```

We can select the start time, “FromTime” → “2018-01-04 02:00:00” & “ToTime” → “2018-01-04 06:00:00” . As we can see below, the port Rodby has less activity during this period and that’s why it is green now. But overall Rodby has more activity so when we look at the entire days data it is colored red.

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2019.png)

---

# TODO IS BELOW HERE

## How many ships are active during each hour of the day?

@Ismail 

## Where are the ships with cargo X moving?

```sql
CREATE TABLE AISInputFilteredPlus AS
SELECT DISTINCT ON(MMSI, TypeOfMobile, T) *
FROM AISInput
WHERE Longitude BETWEEN -16.1 and 32.88 AND Latitude BETWEEN 40.18 AND 84.17;

SELECT
  latitude,
  longitude,
  typeofmobile,
	mmsi
FROM aisinputfiltered TABLESAMPLE SYSTEM (10)

SELECT DISTINCT(TypeOfMobile) FROM AISInputFilteredPlus;

SELECT COUNT(TypeOfMobile) FROM AISInput GROUP BY TypeOfMobile;
```

## How many total ships…?

@Adam Broniewski 

- Are included in the dataset?
    
    ```sql
    SELECT
      COUNT(*) DISTINCT
    FROM ships
    ```
    
- in some period of time?
- are there with a certain type of cargo?
    
    ```sql
    SELECT
      COUNT(*) AS Frequency, Destination AS Destination
    FROM aisinput
    GROUP BY Destination
    ORDER BY Frequency desc;
    ```
    
- 

## How many KMs of travel was there in some period of time?

![Untitled](Dashboard%20and%20Visualization%20of%20Ship%20Trajectories%20(%20845afa91ff30470181ea3a0b5ddf08b5/Untitled%2020.png)