-- Deterministic integration fixtures. The Swift test helper replaces
-- {{schema}} with a unique schema name.

CREATE TABLE "{{schema}}".features (
    id bigint PRIMARY KEY,
    name text,
    kind text,
    geom geometry(Geometry, 4326)
);

INSERT INTO "{{schema}}".features (id, name, kind, geom) VALUES
    (1, 'point', 'point', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    (2, 'line', 'line', ST_GeomFromText('LINESTRING(11.4 48.0, 11.5 48.1, 11.6 48.2)', 4326)),
    (3, 'polygon', 'polygon', ST_GeomFromText('POLYGON((11.4 48.0, 11.6 48.0, 11.6 48.2, 11.4 48.2, 11.4 48.0), (11.48 48.08, 11.52 48.08, 11.52 48.12, 11.48 48.12, 11.48 48.08))', 4326)),
    (4, 'multi', 'multipolygon', ST_GeomFromText('MULTIPOLYGON(((11.40 48.00, 11.45 48.00, 11.45 48.05, 11.40 48.05, 11.40 48.00)), ((11.55 48.15, 11.60 48.15, 11.60 48.20, 11.55 48.20, 11.55 48.15)))', 4326)),
    (5, 'collection', 'geometrycollection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(11.5 48.1), LINESTRING(11.4 48.0, 11.6 48.2))', 4326)),
    (6, 'null', 'point', NULL),
    (7, 'invalid', 'polygon', ST_GeomFromText('POLYGON((11.40 48.00, 11.60 48.20, 11.60 48.00, 11.40 48.20, 11.40 48.00))', 4326));

CREATE TABLE "{{schema}}".property_types (
    id bigint PRIMARY KEY,
    text_value text,
    char_value char(4),
    uuid_value uuid,
    int2_value int2,
    int4_value int4,
    int8_value int8,
    int2_array int2[],
    int4_array int4[],
    int8_array int8[],
    float4_value float4,
    float8_value float8,
    numeric_value numeric,
    float4_array float4[],
    float8_array float8[],
    bool_value boolean,
    bool_array boolean[],
    date_value date,
    timestamp_value timestamp,
    timestamptz_value timestamptz,
    text_array text[],
    varchar_value varchar(20),
    varchar_array varchar[],
    inet_value inet,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".property_types VALUES (
    1,
    'text',
    'AB',
    '00000000-0000-0000-0000-000000000001',
    -2,
    -4,
    -8,
    ARRAY[1, 2]::int2[],
    ARRAY[3, 4]::int4[],
    ARRAY[5, 6]::int8[],
    1.25,
    2.5,
    12.50,
    ARRAY[1.5, 2.5]::float4[],
    ARRAY[3.5, 4.5]::float8[],
    true,
    ARRAY[true, false],
    DATE '2024-01-02',
    TIMESTAMP '2024-01-02 03:04:05',
    TIMESTAMPTZ '2024-01-02 03:04:05+00',
    ARRAY['a', NULL, 'b']::text[],
    'varchar',
    ARRAY['x', 'y']::varchar[],
    '192.0.2.1'::inet,
    ST_GeomFromText('POINT(11.5 48.1)', 4326)
);

CREATE TABLE "{{schema}}".features_3857 (
    id bigint PRIMARY KEY,
    name text,
    kind text,
    geom geometry(Geometry, 3857)
);

INSERT INTO "{{schema}}".features_3857 (id, name, kind, geom) VALUES
    (1, 'point-3857', 'point', ST_Transform(ST_GeomFromText('POINT(11.5 48.1)', 4326), 3857)),
    (2, 'line-3857', 'line', ST_Transform(ST_GeomFromText('LINESTRING(11.4 48.0, 11.6 48.2)', 4326), 3857));

CREATE TABLE "{{schema}}".features_utm (
    id bigint PRIMARY KEY,
    name text,
    kind text,
    geom geometry(Geometry, 32633)
);

INSERT INTO "{{schema}}".features_utm (id, name, kind, geom) VALUES
    (1, 'point-utm', 'point', ST_Transform(ST_GeomFromText('POINT(11.5 48.1)', 4326), 32633)),
    (2, 'line-utm', 'line', ST_Transform(ST_GeomFromText('LINESTRING(11.4 48.0, 11.6 48.2)', 4326), 32633));

CREATE TABLE "{{schema}}".clip_features (
    id bigint PRIMARY KEY,
    name text,
    geom geometry(Geometry, 4326)
);

INSERT INTO "{{schema}}".clip_features (id, name, geom) VALUES
    (1, 'crossing-line', ST_GeomFromText('LINESTRING(-10 10, 10 -10)', 4326)),
    (2, 'crossing-polygon', ST_GeomFromText('POLYGON((-10 10, 10 10, 10 -10, -10 -10, -10 10))', 4326)),
    (3, 'inside-point', ST_GeomFromText('POINT(-10 10)', 4326)),
    (4, 'outside-point', ST_GeomFromText('POINT(10 -10)', 4326)),
    (5, 'inside-line', ST_GeomFromText('LINESTRING(-20 20, -15 15)', 4326));

CREATE TABLE "{{schema}}".simplify_features (
    id bigint PRIMARY KEY,
    name text,
    geom geometry(Geometry, 4326)
);

INSERT INTO "{{schema}}".simplify_features (id, name, geom) VALUES
    (1, 'zigzag', ST_GeomFromText('LINESTRING(0 0, 0.1 0.05, 0.2 0, 0.3 0.05, 0.4 0, 0.5 0.05, 0.6 0)', 4326));

CREATE TABLE "{{schema}}".invalid_geometry (
    id bigint PRIMARY KEY,
    name text,
    geom geometry(Geometry, 4326)
);

INSERT INTO "{{schema}}".invalid_geometry (id, name, geom) VALUES
    (1, 'bow-tie', ST_GeomFromText('POLYGON((0 0, 2 2, 2 0, 0 2, 0 0))', 4326));

CREATE TABLE "{{schema}}".null_geometry (
    id bigint PRIMARY KEY,
    name text,
    geom geometry(Geometry, 4326)
);

INSERT INTO "{{schema}}".null_geometry (id, name, geom) VALUES
    (1, 'missing', NULL),
    (2, 'present', ST_GeomFromText('POINT(11.5 48.1)', 4326));

CREATE TABLE "{{schema}}".unknown_types (
    id bigint PRIMARY KEY,
    inet_value inet,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".unknown_types (id, inet_value, geom) VALUES
    (1, '192.0.2.1'::inet, ST_GeomFromText('POINT(11.5 48.1)', 4326));

CREATE TABLE "{{schema}}".missing_geometry (
    id bigint PRIMARY KEY,
    name text
);

INSERT INTO "{{schema}}".missing_geometry (id, name) VALUES
    (1, 'no-geometry');
