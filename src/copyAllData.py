import psycopg2
import glob

conn = psycopg2.connect(database="openskylocal", user = "adambroniewski", password = "password", host = "localhost", port = "5432")
print("Opened database successfully")

cur = conn.cursor()
path = "/Users/adambroniewski/DATA for Projects/OpenSky Data/*.csv"

for fname in glob.glob(path):
    copy_command = f""
    cur.execute('''
        COPY flights(et, icao24, lat, lon, velocity, heading, vertrate, callsign, onground, alert, spi, squawk, baroaltitude, geoaltitude, lastposupdate, lastcontact)
        FROM '/Users/adambroniewski/DATA for Projects/OpenSky Data/states_2020-06-01-00.csv/states_2020-06-01-00.csv' DELIMITER  ',' CSV HEADER;
        ''')
    print("Table dropped successfully")

conn.commit()
conn.close()