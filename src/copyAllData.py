import psycopg2
import glob
import os

conn = psycopg2.connect(database="openskylocal", user = "adambroniewski", password = "password", host = "localhost", port = "5432")
print("Opened database successfully")

cur = conn.cursor()
path = "/Users/adambroniewski/DATA for Projects/OpenSky Data"

try:
    for directory in os.listdir(path):
        if directory.endswith(".csv"):
            directory_path = os.path.join(path,directory)
            for fname in os.listdir(directory_path):
                if fname.endswith(".csv"):
                    fname_path = os.path.join(directory_path,fname)
                    copy_command = f'''
                        COPY flights(et, icao24, lat, lon, velocity, heading, vertrate, callsign, onground, alert, spi, squawk, baroaltitude, geoaltitude, lastposupdate, lastcontact)
                        FROM '{fname_path}' DELIMITER  ',' CSV HEADER;'''


                    cur.execute(copy_command)
                    conn.commit()
                    print(f"Added csv {fname}")
    print("Data import complete!")

except Exception as e:
    print("There was an error!")
    print(e)

finally:
    conn.close()
    print("Connection closed")