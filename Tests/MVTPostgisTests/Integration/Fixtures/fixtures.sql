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
    (3, 'polygon', 'polygon', ST_GeomFromText('POLYGON((11.4 48.0, 11.6 48.0, 11.6 48.2, 11.4 48.2, 11.4 48.0), (11.53 48.13, 11.53 48.17, 11.57 48.17, 11.57 48.13, 11.53 48.13))', 4326)),
    (4, 'multi', 'multipolygon', ST_GeomFromText('MULTIPOLYGON(((11.40 48.00, 11.45 48.00, 11.45 48.05, 11.40 48.05, 11.40 48.00)), ((11.55 48.15, 11.60 48.15, 11.60 48.20, 11.55 48.20, 11.55 48.15)))', 4326)),
    (5, 'collection', 'geometrycollection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(11.5 48.1), LINESTRING(11.4 48.0, 11.6 48.2))', 4326)),
    (6, 'null', 'point', NULL),
    (7, 'invalid', 'polygon', ST_GeomFromText('POLYGON((11.40 48.00, 11.60 48.20, 11.60 48.00, 11.40 48.20, 11.40 48.00))', 4326)),
    (8, 'multipoint', 'multipoint', ST_GeomFromText('MULTIPOINT((11.5 48.1), (11.6 48.2))', 4326)),
    (9, 'multilinestring', 'multilinestring', ST_GeomFromText('MULTILINESTRING((11.4 48.0, 11.5 48.1), (11.55 48.15, 11.6 48.2))', 4326));

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

CREATE EXTENSION IF NOT EXISTS hstore;

CREATE TYPE "{{schema}}".mood AS ENUM ('sad', 'ok', 'happy');
CREATE DOMAIN "{{schema}}".positive_int AS int4 CHECK (VALUE > 0);
CREATE TYPE "{{schema}}".pair AS (x int4, y int4);

CREATE TABLE "{{schema}}".extended_types (
    id bigint PRIMARY KEY,
    json_value json,
    jsonb_value jsonb,
    json_array json[],
    jsonb_array jsonb[],
    bytea_value bytea,
    bytea_array bytea[],
    xml_value xml,
    xml_array xml[],
    money_value money,
    money_array money[],
    oid_value oid,
    regproc_value regproc,
    regproc_array regproc[],
    regclass_value regclass,
    regclass_array regclass[],
    regtype_value regtype,
    regtype_array regtype[],
    numeric_array numeric[],
    bpchar_array char(4)[],
    name_value name,
    name_array name[],
    uuid_array uuid[],
    date_array date[],
    timestamp_array timestamp[],
    timestamptz_array timestamptz[],
    enum_value "{{schema}}".mood,
    hstore_value hstore,
    unsupported_time time,
    interval_value interval,
    interval_array interval[],
    unsupported_inet inet,
    unsupported_cidr cidr,
    unsupported_macaddr macaddr,
    unsupported_bit bit(4),
    unsupported_int4range int4range,
    tsrange_value tsrange,
    tstzrange_value tstzrange,
    daterange_value daterange,
    empty_range tsrange,
    unbounded_range daterange,
    domain_value "{{schema}}".positive_int,
    unsupported_composite "{{schema}}".pair,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".extended_types VALUES (
    1,
    '{"a": 1}',
    '{"b": [1, 2]}',
    ARRAY['{"c": 3}'::json, '{"d": 4}'::json],
    ARRAY['{"e": 5}'::jsonb, '{"f": 6}'::jsonb],
    '\xDEADBEEF'::bytea,
    ARRAY['\x0102'::bytea, '\x0304'::bytea],
    '<root><a>1</a></root>'::xml,
    ARRAY['<a>1</a>'::xml, '<b>2</b>'::xml],
    12.34::money,
    ARRAY[1.23::money, 4.56::money],
    1234::oid,
    'pg_catalog.now'::regproc,
    ARRAY['pg_catalog.now'::regproc, 'pg_catalog.now'::regproc],
    'pg_class'::regclass,
    ARRAY['pg_class'::regclass, 'pg_type'::regclass],
    'integer'::regtype,
    ARRAY['integer'::regtype, 'text'::regtype],
    ARRAY[1.5, 2.5]::numeric[],
    ARRAY['A'::char(4), 'B'::char(4)],
    'a_name'::name,
    ARRAY['x'::name, 'y'::name],
    ARRAY['00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000002'::uuid],
    ARRAY['2024-01-02'::date, '2024-01-03'::date],
    ARRAY['2024-01-02 03:04:05'::timestamp, '2024-01-03 04:05:06'::timestamp],
    ARRAY['2024-01-02 03:04:05+00'::timestamptz, '2024-01-03 04:05:06+00'::timestamptz],
    'happy'::"{{schema}}".mood,
    'name => "München", population => "1500000"'::hstore,
    '12:34:56'::time,
    '1 day 02:03:04'::interval,
    ARRAY['1 day'::interval, '02:00:00'::interval],
    '192.0.2.1'::inet,
    '192.0.2.0/24'::cidr,
    '08:00:2b:01:02:03'::macaddr,
    B'1010'::bit(4),
    '[1,5)'::int4range,
    '[2024-01-02 03:04:05, 2024-01-03 04:05:06)'::tsrange,
    '[2024-01-02 03:04:05+00, 2024-01-03 04:05:06+00)'::tstzrange,
    '[2024-01-02, 2024-01-05)'::daterange,
    'empty'::tsrange,
    '(,2024-01-05)'::daterange,
    42::"{{schema}}".positive_int,
    ROW(1, 2)::"{{schema}}".pair,
    ST_GeomFromText('POINT(11.5 48.1)', 4326)
);

CREATE TABLE "{{schema}}".array_edge_cases (
    id bigint PRIMARY KEY,
    empty_int_array int4[],
    null_int_array int4[],
    int_array_with_null int4[],
    text_array_with_null text[],
    multi_int_array int4[],
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".array_edge_cases VALUES (
    1,
    '{}'::int4[],
    NULL,
    ARRAY[1, NULL, 3],
    ARRAY['a', NULL, 'b'],
    ARRAY[[1, 2], [3, 4]],
    ST_GeomFromText('POINT(11.5 48.1)', 4326)
);

CREATE TABLE "{{schema}}".geography_features (
    id bigint PRIMARY KEY,
    name text,
    geom geography
);

INSERT INTO "{{schema}}".geography_features (id, name, geom) VALUES
    (1, 'point', ST_GeogFromText('POINT(11.5 48.1)')),
    (2, 'line', ST_GeogFromText('LINESTRING(11.4 48.0, 11.6 48.2)')),
    (3, 'polygon', ST_GeogFromText('POLYGON((11.4 48.0, 11.6 48.0, 11.6 48.2, 11.4 48.2, 11.4 48.0))'));
