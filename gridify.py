import geohash
from pyspatialite import dbapi2 as db

conn = db.connect('countries_grid.sqlite')
cur = conn.cursor()

# Load countries from CSV
# cur.execute('CREATE TABLE "countries_load" ( countries VARCHAR, country_code CHAR(2), geom_wkt TEXT )')
# cur.execute('.mode tabs')
# cur.execute('.import ./hiu_countries.tab countries_load')

def create_indexed():
  # Create spatially indexed country
  print "Creating indexed countries"
  cur.execute('CREATE TABLE countries_indexed ( country_code CHAR(2) )')
  cur.execute('SELECT AddGeometryColumn("countries_indexed", "geom", 4326, "GEOMETRY", "XY")')
  cur.execute("INSERT INTO countries_indexed SELECT country_code, GeomFromText(geom_wkt, 4326) from countries_load")
  cur.execute('SELECT CreateSpatialIndex("countries_indexed", "geom")')

def create_grid():
  # Create grid
  print "Creating grid"
  cur.execute('CREATE TABLE grid (lat INTEGER, long INTEGER)')
  cur.execute("SELECT AddGeometryColumn('grid', 'geom', 4326, 'GEOMETRY', 'XY')")

  for lng in range(-180, 179):
    for lat in range(-90,89):
        latstr = str(lat)
        lat1str = str(lat + 1)
        lngstr = str(lng)
        lng1str = str(lng + 1)
        geom = "GeomFromText('POLYGON(("
        geom += lngstr + " " + latstr +  ","
        geom += lngstr + " " + lat1str + ","
        geom += lng1str + " " + lat1str + ","
        geom += lng1str + " " + latstr + ","
        geom += lngstr + " " + latstr
        geom += "))', 4326)"
        sql = "INSERT INTO grid (lat, long, geom) VALUES (%d, %d, %s)" % (lat, lng, geom)
        cur.execute(sql)

def create_countries():
  # Create countries table of intersections
  print "Creating countries grid intersection table"
  cur.execute('CREATE TABLE countries ( country_code CHAR(2) )')
  cur.execute('SELECT AddGeometryColumn("countries", "Geometry", 4326, "Geometry", "XY")')
  cur.execute('INSERT INTO countries SELECT c.country_code,ST_Intersection(grid.geom, c.geom) FROM grid,countries_indexed AS c WHERE c.ROWID IN (SELECT ROWID FROM SpatialIndex WHERE f_table_name="countries_indexed" AND search_frame = grid.geom)')

  print "Indexing countries"
  cur.execute('DELETE FROM countries WHERE Geometry IS NULL')
  cur.execute('SELECT CreateSpatialIndex("countries", "Geometry")')

def clean_up():
  print "Cleaning up"
  cur.execute('DROP TABLE grid')
  cur.execute('DROP TABLE countries_load')
  # cur.execute('SELECT DiscardGeometryColumn("countries_indexed", "geom")')
  # cur.execute('DROP TABLE countries_indexed')
  cur.execute('VACUUM')





create_indexed();
create_grid();
create_countries();
clean_up();
conn.commit();
