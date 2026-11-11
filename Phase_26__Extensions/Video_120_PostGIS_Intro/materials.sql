-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- PostGIS — Geographic Data in PostgreSQL (Class 226)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION
-- ============================================================

-- Linux:
--   Debian/Ubuntu: sudo apt install postgresql-16-postgis-3
--   RHEL/Rocky:    sudo dnf install postgis34_16
-- Windows: Stack Builder or download from postgis.net

CREATE EXTENSION postgis;

-- Verify:
SELECT PostGIS_Full_Version();
SELECT PostGIS_Version();

-- ============================================================
-- 1. CREATING POINTS
-- ============================================================

-- IMPORTANT: PostGIS = longitude FIRST, latitude SECOND
-- Google Maps = latitude first — opposite!

-- From WKT (Well-Known Text):
SELECT ST_GeogFromText('POINT(-74.0060 40.7128)');  -- New York

-- From ST_MakePoint:
SELECT ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)::geography;

-- SRID 4326 = WGS 84 (GPS coordinates)

-- ============================================================
-- 2. RESTAURANTS TABLE (Practical Example)
-- ============================================================

CREATE TABLE restaurants (
    id serial PRIMARY KEY,
    name text NOT NULL,
    cuisine text,
    location geography(POINT, 4326) NOT NULL
);

-- Insert restaurants (longitude, latitude):
INSERT INTO restaurants (name, cuisine, location) VALUES
('Pizza Palace', 'Italian',
  ST_GeogFromText('POINT(-73.9857 40.7484)')),
('Sushi Spot', 'Japanese',
  ST_GeogFromText('POINT(-73.9712 40.7831)')),
('Taco Town', 'Mexican',
  ST_GeogFromText('POINT(-73.9934 40.7505)')),
('Curry House', 'Indian',
  ST_GeogFromText('POINT(-73.9867 40.7569)'));

-- View as text:
SELECT name, ST_AsText(location) FROM restaurants;

-- ============================================================
-- 3. SPATIAL INDEX (Essential!)
-- ============================================================

CREATE INDEX idx_restaurants_location
    ON restaurants USING gist (location);

-- ============================================================
-- 4. FIND NEARBY (ST_DWithin)
-- ============================================================

-- Restaurants within 2 km of Times Square:
SELECT name, cuisine,
    round(ST_Distance(
        location,
        ST_GeogFromText('POINT(-73.9855 40.7580)')
    )::numeric) AS distance_m
FROM restaurants
WHERE ST_DWithin(
    location,
    ST_GeogFromText('POINT(-73.9855 40.7580)'),
    2000  -- meters
)
ORDER BY distance_m;

-- ============================================================
-- 5. DISTANCE CALCULATION (ST_Distance)
-- ============================================================

-- Distance between two points (meters):
SELECT ST_Distance(
    ST_GeogFromText('POINT(-73.9857 40.7484)'),
    ST_GeogFromText('POINT(-73.9712 40.7831)')
) AS distance_meters;

-- Ordered by distance (KNN with index):
SELECT name,
    round(ST_Distance(
        location,
        ST_GeogFromText('POINT(-73.9900 40.7500)')
    )::numeric) AS distance_m
FROM restaurants
ORDER BY location <-> ST_GeogFromText('POINT(-73.9900 40.7500)')
LIMIT 3;

-- ============================================================
-- 6. POLYGONS & CONTAINMENT
-- ============================================================

CREATE TABLE delivery_zones (
    id serial PRIMARY KEY,
    zone_name text NOT NULL,
    area geography(POLYGON, 4326) NOT NULL
);

-- Insert a zone (close the ring: first point = last point):
INSERT INTO delivery_zones (zone_name, area) VALUES
('Downtown', ST_GeogFromText(
  'POLYGON((-74.01 40.74, -73.97 40.74,
            -73.97 40.76, -74.01 40.76,
            -74.01 40.74))'
));

-- Check if a point is inside:
SELECT zone_name FROM delivery_zones
WHERE ST_Covers(
    area,
    ST_GeogFromText('POINT(-73.9857 40.7484)')
);

-- Which restaurants are in the zone?
SELECT r.name FROM restaurants r
JOIN delivery_zones dz ON ST_Covers(dz.area, r.location)
WHERE dz.zone_name = 'Downtown';

-- ============================================================
-- 7. GEOJSON OUTPUT (For Web Maps)
-- ============================================================

-- Single point:
SELECT ST_AsGeoJSON(location) FROM restaurants
WHERE name = 'Pizza Palace';

-- Full FeatureCollection:
SELECT json_build_object(
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
FROM restaurants;

-- ============================================================
-- 8. OTHER OUTPUT FORMATS
-- ============================================================

-- Well-Known Text:
SELECT ST_AsText(location) FROM restaurants LIMIT 1;

-- Well-Known Binary (for applications):
SELECT ST_AsBinary(location) FROM restaurants LIMIT 1;

-- KML (for Google Earth):
SELECT ST_AsKML(location::geometry) FROM restaurants LIMIT 1;

-- ============================================================
-- USEFUL FUNCTIONS REFERENCE
-- ============================================================

-- ST_Distance(a, b)      — distance in meters (geography)
-- ST_DWithin(a, b, d)    — within d meters?
-- ST_Contains(a, b)      — geometry containment
-- ST_Covers(a, b)        — geography containment
-- ST_Intersects(a, b)    — shapes overlap?
-- ST_Area(polygon)       — area in sq meters
-- ST_Length(line)         — length in meters
-- ST_Buffer(geom, d)     — expand shape
-- ST_Union(a, b)         — merge shapes
-- ST_AsText(geom)        — to WKT
-- ST_AsGeoJSON(geom)     — to GeoJSON

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a table of cities with name and geography(POINT, 4326).
--    Insert 5 cities you know. Create a GiST index.

-- 2. Find all cities within 500 km of one city.

-- 3. Calculate the distance between two cities in kilometers.

-- 4. Create a delivery zone polygon and check which
--    restaurants fall inside it.

-- 5. Output your restaurants as a GeoJSON FeatureCollection.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS restaurants;
-- DROP TABLE IF EXISTS delivery_zones;
-- DROP EXTENSION IF EXISTS postgis;
