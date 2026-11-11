# PostGIS — Geographic Data in PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! How do you find all restaurants within 5 kilometers? How do you check if a delivery address is inside your service area? How do you calculate the shortest route? PostGIS is the most powerful open-source geographic extension. It turns PostgreSQL into a full spatial database — storing points, lines, polygons, and performing geographic queries. Let us learn the fundamentals.


---

## 2. Core Technical Concepts & Mechanisms

### Geometry vs Geography
PostGIS adds geographic data types, spatial indexes, and hundreds of functions to PostgreSQL. It supports two main geometry models. Geometry is flat — for local coordinate systems, floor plans, and game maps. Geography is spherical — for real Earth coordinates like latitude and longitude. Most applications use geography for real-world locations.

| Geometry (Flat/Planar) | Geography (Spherical) |
| :--- | :--- |
| Flat 2D coordinate plane | Spherical Earth model |
| Distances in coordinate units | Distances in meters (accurate) |
| Fast calculations | Slightly slower (sphere math) |
| Good for: floor plans, game maps | Good for: GPS coordinates |
| Good for: small areas (city-level) | Good for: global applications |
| More functions available | Fewer functions, but essential ones |

### PostGIS Spatial Types
The fundamental spatial types. A point is a single location — like a restaurant or a user's GPS position. A linestring is a path — like a road or a river. A polygon is an area — like a city boundary or a delivery zone. And a multipolygon is multiple areas — like a country with islands.

| Term | Meaning / Explanation |
| :--- | :--- |
| **POINT** | Single location (longitude, latitude) — stores, users, sensors |
| **LINESTRING** | Connected line of points — roads, rivers, routes |
| **POLYGON** | Closed area — city boundaries, delivery zones, buildings |
| **MULTIPOINT** | Collection of points — chain store locations |
| **MULTILINESTRING** | Collection of lines — road network |
| **MULTIPOLYGON** | Collection of areas — country with islands |
| **GEOMETRYCOLLECTION** | Mix of any types in one column |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Essential PostGIS Functions
Here are the most commonly used PostGIS functions. These cover 90 percent of real-world spatial queries.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the most commonly used PostGIS functions |
| **These cover 90 percent of real** | world spatial queries |

### Common Coordinate Systems (SRIDs)
Here is a quick reference of coordinate systems. SRID 4326 is what you want for GPS coordinates. It is the World Geodetic System 1984 — the same system used by GPS satellites, Google Maps, and OpenStreetMap.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | SRID 4326 is what you want for GPS coordinates |
| **It is the World Geodetic System 1984** | the same system used by GPS satellites, Google Maps, and OpenStreetMap |


---

## 3. Hands-On Commands & psql Output

### Installing PostGIS
**Explanation:** Install PostGIS. It is a large extension with many dependencies — on Linux, install the OS package first. On Windows, it comes with the EnterpriseDB installer's Stack Builder.

```sql
postgres=# -- Linux: install OS package first
postgres=# -- Debian/Ubuntu:
postgres=# --   sudo apt install postgresql-16-postgis-3
postgres=# -- RHEL/Rocky:
postgres=# --   sudo dnf install postgis34_16
postgres=# -- Windows: use Stack Builder (comes with installer)
postgres=# -- or download from postgis.net
postgres=# -- Then create the extension:
postgres=# CREATE EXTENSION postgis;
postgres=# -- Verify:
postgres=# SELECT PostGIS_Full_Version();
postgres=# -- POSTGIS="3.4.2" PROJ="9.3.1" GDAL="3.8.4"
postgres=# -- GEOS="3.12.1" LIBXML="2.9.14"
postgres=# -- Check version:
postgres=# SELECT PostGIS_Version();
postgres=# -- 3.4 USE_GEOS=1 USE_PROJ=1 USE_STATS=1
```

### Creating Points (SRID 4326 = GPS)
**Explanation:** Create points using ST_MakePoint or ST_GeogFromText. Important — PostGIS uses longitude first, then latitude. This is the opposite of Google Maps which shows latitude first. Getting this wrong is the number one beginner mistake.

```sql
postgres=# -- IMPORTANT: PostGIS = longitude FIRST, then latitude!
postgres=# -- Google Maps: 40.7128, -74.0060 (lat, lon)
postgres=# -- PostGIS:    -74.0060, 40.7128 (lon, lat)
postgres=# -- Create a point (geography):
postgres=# SELECT ST_GeogFromText('POINT(-74.0060 40.7128)');
postgres=# -- New York City
postgres=# -- Using ST_MakePoint + casting to geography:
postgres=# SELECT ST_SetSRID(
    ST_MakePoint(-74.0060, 40.7128),
    4326
)::geography;
postgres=# -- SRID 4326 = WGS 84 (standard GPS coordinates)
postgres=# -- Well-Known Text (WKT) format:
postgres=# -- POINT(lon lat)
postgres=# -- LINESTRING(lon1 lat1, lon2 lat2, ...)
postgres=# -- POLYGON((lon1 lat1, lon2 lat2, ..., lon1 lat1))
```

### Practical: Restaurants Table
**Explanation:** Let us create a practical table — restaurants with locations. We store the location as a geography column with SRID 4326 for GPS coordinates.

```sql
postgres=# CREATE TABLE restaurants (
    id serial PRIMARY KEY,
    name text NOT NULL,
    cuisine text,
    location geography(POINT, 4326) NOT NULL
);
postgres=# -- Insert restaurants (lon, lat):
postgres=# INSERT INTO restaurants (name, cuisine, location) VALUES
('Pizza Palace', 'Italian',
  ST_GeogFromText('POINT(-73.9857 40.7484)')),
('Sushi Spot', 'Japanese',
  ST_GeogFromText('POINT(-73.9712 40.7831)')),
('Taco Town', 'Mexican',
  ST_GeogFromText('POINT(-73.9934 40.7505)')),
('Curry House', 'Indian',
  ST_GeogFromText('POINT(-73.9867 40.7569)'));
postgres=# -- View (as human-readable text):
postgres=# SELECT name, ST_AsText(location) FROM restaurants;
postgres=# -- Pizza Palace | POINT(-73.9857 40.7484)
postgres=# -- Sushi Spot   | POINT(-73.9712 40.7831)
```

### ST_DWithin — Find Nearby
**Explanation:** The most common query — find everything within a distance. ST_DWithin checks if two geographies are within a specified distance in meters. Let us find all restaurants within 2 kilometers of a point.

```sql
postgres=# -- Find restaurants within 2 km of Times Square:
postgres=# SELECT name, cuisine,
    round(ST_Distance(
        location,
        ST_GeogFromText('POINT(-73.9855 40.7580)')
    )::numeric) AS distance_m
postgres-# FROM restaurants
postgres-# WHERE ST_DWithin(
    location,
    ST_GeogFromText('POINT(-73.9855 40.7580)'),
    2000  -- 2000 meters = 2 km
)
postgres-# ORDER BY distance_m;
postgres=# -- Results:
postgres=# -- name         | cuisine  | distance_m
postgres=# -- Curry House  | Indian   | 102
postgres=# -- Pizza Palace | Italian  | 1068
postgres=# -- Taco Town    | Mexican  | 1017
```

### ST_Distance — Calculate Distance
**Explanation:** ST_Distance calculates the distance between two geographies in meters. For geometry types, the unit depends on the coordinate system. Always use geography for real-world distance calculations.

```sql
postgres=# -- Distance between two points (in meters):
postgres=# SELECT ST_Distance(
    ST_GeogFromText('POINT(-73.9857 40.7484)'),  -- Pizza Palace
    ST_GeogFromText('POINT(-73.9712 40.7831)')   -- Sushi Spot
) AS distance_meters;
postgres=# -- 3907.42 meters (~3.9 km)
postgres=# -- Distance from each restaurant to a user:
postgres=# SELECT name,
    round(
        ST_Distance(
            location,
            ST_GeogFromText('POINT(-73.9900 40.7500)')
        )::numeric
    ) AS distance_m
postgres-# FROM restaurants
postgres-# ORDER BY location <->
    ST_GeogFromText('POINT(-73.9900 40.7500)');
postgres=# -- <-> is the distance operator (uses index!)
```

### Spatial Indexes (GiST)
**Explanation:** Spatial indexes are critical for performance. Without an index, every query scans all rows and calculates distances — very slow. A GiST index on a geography column makes spatial queries fast.

```sql
postgres=# -- Create a spatial GiST index:
postgres=# CREATE INDEX idx_restaurants_location
postgres-# ON restaurants USING gist (location);
postgres=# -- Now ST_DWithin and <-> use the index!
postgres=# EXPLAIN ANALYZE
postgres=# SELECT name FROM restaurants
postgres-# WHERE ST_DWithin(
    location,
    ST_GeogFromText('POINT(-73.9855 40.7580)'),
    2000
);
postgres=# -- Index Scan using idx_restaurants_location
postgres=# -- (not Seq Scan — much faster)
postgres=# -- K-Nearest-Neighbor (KNN) query:
postgres=# -- Find 3 closest restaurants:
postgres=# SELECT name, ST_Distance(
    location,
    ST_GeogFromText('POINT(-73.9855 40.7580)')
) AS dist
postgres-# FROM restaurants
postgres-# ORDER BY location <->
    ST_GeogFromText('POINT(-73.9855 40.7580)')
postgres-# LIMIT 3;
postgres=# -- Uses index for efficient KNN!
```

### Polygons & Containment
**Explanation:** Polygons define areas — delivery zones, city boundaries, restricted areas. ST_Contains checks if a point is inside a polygon. ST_Intersects checks if two shapes overlap.

```sql
postgres=# -- Create delivery zones:
postgres=# CREATE TABLE delivery_zones (
    id serial PRIMARY KEY,
    zone_name text NOT NULL,
    area geography(POLYGON, 4326) NOT NULL
);
postgres=# -- Insert a rectangular zone (close the ring!):
postgres=# INSERT INTO delivery_zones (zone_name, area) VALUES
('Downtown', ST_GeogFromText(
  'POLYGON((-74.01 40.74, -73.97 40.74,
            -73.97 40.76, -74.01 40.76,
            -74.01 40.74))'
));
postgres=# -- Check if a point is inside the zone:
postgres=# SELECT zone_name FROM delivery_zones
postgres-# WHERE ST_Covers(
    area,
    ST_GeogFromText('POINT(-73.9857 40.7484)')
);
postgres=# -- Downtown (point is inside!)
postgres=# -- Which restaurants are in the delivery zone?
postgres=# SELECT r.name FROM restaurants r
postgres-# JOIN delivery_zones dz ON ST_Covers(dz.area, r.location)
postgres-# WHERE dz.zone_name = 'Downtown';
```

### GeoJSON Output for Web Maps
**Explanation:** GeoJSON is the standard format for geographic data on the web. PostGIS can convert any geometry to GeoJSON with ST_AsGeoJSON. This integrates directly with web mapping libraries like Leaflet, Mapbox, and Google Maps.

```sql
postgres=# -- Single point as GeoJSON:
postgres=# SELECT ST_AsGeoJSON(location) FROM restaurants
postgres-# WHERE name = 'Pizza Palace';
postgres=# -- {"type":"Point",
postgres=# --  "coordinates":[-73.9857,40.7484]}
postgres=# -- Full GeoJSON Feature Collection (for map display):
postgres=# SELECT json_build_object(
    'type', 'FeatureCollection',
    'features', json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(location)::json,
            'properties', json_build_object(
                'name', name,
                'cuisine', cuisine
            )
        )
    )
) AS geojson
postgres-# FROM restaurants;
postgres=# -- Ready to paste into Leaflet, Mapbox, etc.
```

### Beginner Trap: Longitude/Latitude Order
**Explanation:** A common beginner trap — getting longitude and latitude backwards. PostGIS uses longitude first, then latitude. Google Maps and most GPS apps show latitude first. Swapping them puts your points in the wrong hemisphere.

```sql
postgres=# -- WRONG: latitude first (Google Maps order)
postgres=# SELECT ST_GeogFromText('POINT(40.7128 -74.0060)');
postgres=# -- This puts you near Turkey, not New York!
postgres=# -- RIGHT: longitude first (PostGIS order)
postgres=# SELECT ST_GeogFromText('POINT(-74.0060 40.7128)');
postgres=# -- This is New York City
postgres=# -- Memory aid:
postgres=# -- PostGIS = (X, Y) = (longitude, latitude)
postgres=# -- Google  = (lat, lng) — opposite!
postgres=# -- Sanity check — longitude range:
postgres=# -- -180 to +180 (West negative, East positive)
postgres=# -- Latitude range:
postgres=# -- -90 to +90 (South negative, North positive)
postgres=# -- If your coordinates are > 90, they are likely swapped!
```

### Beginner Trap: Polygon & SRID Errors
**Explanation:** Another trap — forgetting to close polygons. The first and last point of a polygon must be identical. And always specify SRID 4326 for GPS coordinates, or your distance calculations will be in the wrong units.

```sql
postgres=# -- WRONG: polygon not closed
postgres=# SELECT ST_GeogFromText(
  'POLYGON((-74.01 40.74, -73.97 40.74,
            -73.97 40.76, -74.01 40.76))'
);
postgres=# -- ERROR: geometry contains non-closed rings
postgres=# -- RIGHT: first point = last point
postgres=# SELECT ST_GeogFromText(
  'POLYGON((-74.01 40.74, -73.97 40.74,
            -73.97 40.76, -74.01 40.76,
            -74.01 40.74))'
);
postgres=# -- OK!
postgres=# -- WRONG: no SRID on geometry (assumes 0)
postgres=# SELECT ST_Distance(
    ST_MakePoint(-74.0060, 40.7128),
    ST_MakePoint(-73.9712, 40.7831)
);
postgres=# -- Returns ~0.04 (degrees, not meters!)
postgres=# -- RIGHT: use geography or set SRID:
postgres=# SELECT ST_Distance(
    ST_GeogFromText('POINT(-74.0060 40.7128)'),
    ST_GeogFromText('POINT(-73.9712 40.7831)')
);
postgres=# -- Returns ~3940 (meters — correct!)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Longitude/Latitude Order
A common beginner trap — getting longitude and latitude backwards. PostGIS uses longitude first, then latitude. Google Maps and most GPS apps show latitude first. Swapping them puts your points in the wrong hemisphere.

```sql
-- WRONG: latitude first (Google Maps order)
SELECT ST_GeogFromText('POINT(40.7128 -74.0060)');
-- This puts you near Turkey, not New York!
-- RIGHT: longitude first (PostGIS order)
SELECT ST_GeogFromText('POINT(-74.0060 40.7128)');
-- This is New York City
-- Memory aid:
-- PostGIS = (X, Y) = (longitude, latitude)
-- Google  = (lat, lng) — opposite!
-- Sanity check — longitude range:
-- -180 to +180 (West negative, East positive)
-- Latitude range:
-- -90 to +90 (South negative, North positive)
-- If your coordinates are > 90, they are likely swapped!
```

### Beginner Trap: Polygon & SRID Errors
Another trap — forgetting to close polygons. The first and last point of a polygon must be identical. And always specify SRID 4326 for GPS coordinates, or your distance calculations will be in the wrong units.

```sql
-- WRONG: polygon not closed
SELECT ST_GeogFromText(
  'POLYGON((-74.01 40.74, -73.97 40.74,
            -73.97 40.76, -74.01 40.76))'
);
-- ERROR: geometry contains non-closed rings
-- RIGHT: first point = last point
SELECT ST_GeogFromText(
  'POLYGON((-74.01 40.74, -73.97 40.74,
            -73.97 40.76, -74.01 40.76,
            -74.01 40.74))'
);
-- OK!
-- WRONG: no SRID on geometry (assumes 0)
SELECT ST_Distance(
    ST_MakePoint(-74.0060, 40.7128),
    ST_MakePoint(-73.9712, 40.7831)
);
-- Returns ~0.04 (degrees, not meters!)
-- RIGHT: use geography or set SRID:
SELECT ST_Distance(
    ST_GeogFromText('POINT(-74.0060 40.7128)'),
    ST_GeogFromText('POINT(-73.9712 40.7831)')
);
-- Returns ~3940 (meters — correct!)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. PostGIS turns PostgreSQL into a full spatial database. Use geography type with SRID 4326 for GPS coordinates. PostGIS uses longitude first, then latitude — opposite of Google Maps. ST_DWithin finds nearby items, ST_Distance calculates distance in meters, ST_Covers checks containment. Always create a GiST index on geography columns. Use ST_AsGeoJSON for web map integration. In the next class, we learn pg_trgm for fuzzy text matching and similarity search.

- **PostGIS: geographic data types + spatial functions**
- **geography(POINT, 4326) for GPS coordinates**
- **IMPORTANT: longitude first, then latitude**
- **ST_DWithin(a, b, meters): nearby search**
- **ST_Distance(a, b): distance in meters**
- **ST_Covers(polygon, point): containment check**
- **GiST index: essential for spatial performance**
- **ST_AsGeoJSON(): web map integration**
- **<-> operator: indexed KNN queries**
- **Close polygons: first point = last point**
- **Next: pg_trgm — Fuzzy Text Matching**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
