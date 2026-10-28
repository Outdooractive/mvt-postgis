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

CREATE TABLE "{{schema}}".property_edge_cases (
    case_name text PRIMARY KEY,
    text_empty text,
    text_unicode text,
    text_control text,
    text_long text,
    char_padded char(6),
    "na.me" text,
    "ümlaut" text,
    int2_min int2,
    int2_max int2,
    int4_min int4,
    int4_max int4,
    int8_min int8,
    int8_max int8,
    int8_above_2_53 int8,
    numeric_high numeric,
    numeric_nan numeric,
    numeric_infinity numeric,
    numeric_neg_infinity numeric,
    float4_nan float4,
    float4_infinity float4,
    float4_neg_infinity float4,
    float4_min_subnormal float4,
    float4_max float4,
    float8_nan float8,
    float8_infinity float8,
    float8_neg_infinity float8,
    float8_min_subnormal float8,
    float8_max float8,
    date_bc date,
    date_after_9999 date,
    date_infinity date,
    date_neg_infinity date,
    timestamp_infinity timestamp,
    timestamp_neg_infinity timestamp,
    timestamptz_infinity timestamptz,
    timestamptz_neg_infinity timestamptz,
    timestamp_micros timestamp,
    timestamptz_dst timestamptz,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".property_edge_cases VALUES (
    'all',
    '',
    'emoji 😀 combining é RTL ‮abc‬ non-BMP 𝄞',
    E'line1\nline2\ttab',
    repeat('x', 1000000),
    'AB',
    'dotted',
    'umlaut',
    -32768,
    32767,
    -2147483648,
    2147483647,
    -9223372036854775808,
    9223372036854775807,
    9007199254740993,
    12345678901234567890.123456789,
    'NaN'::numeric,
    'Infinity'::numeric,
    '-Infinity'::numeric,
    'NaN'::float4,
    'Infinity'::float4,
    '-Infinity'::float4,
    1.401298464324817e-45::float4,
    3.4028234663852886e+38::float4,
    'NaN'::float8,
    'Infinity'::float8,
    '-Infinity'::float8,
    5e-324::float8,
    1.7976931348623157e+308::float8,
    '4713-01-01 BC'::date,
    '10000-01-01'::date,
    'infinity'::date,
    '-infinity'::date,
    'infinity'::timestamp,
    '-infinity'::timestamp,
    'infinity'::timestamptz,
    '-infinity'::timestamptz,
    '2024-01-02 03:04:05.123456'::timestamp,
    '2024-03-31 03:30:00+02'::timestamptz,
    ST_GeomFromText('POINT(11.5 48.1)', 4326)
);

CREATE TABLE "{{schema}}".id_edge_cases (
    case_name text PRIMARY KEY,
    id_text text,
    label text,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".id_edge_cases (case_name, id_text, label, geom) VALUES
    ('int2_min', '-32768', 'int2_min', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('int2_max', '32767', 'int2_max', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('int4_min', '-2147483648', 'int4_min', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('int4_max', '2147483647', 'int4_max', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('int8_min', '-9223372036854775808', 'int8_min', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('int8_max', '9223372036854775807', 'int8_max', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('int8_above_2_53', '9007199254740993', 'int8_above_2_53', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('zero', '0', 'zero', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('text', 'abc', 'text', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('uuid', '00000000-0000-0000-0000-000000000042', 'uuid', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('float', '1.5', 'float', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('bool', 'true', 'bool', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('array', '{1,2}', 'array', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('json', '{"a": 1}', 'json', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('numeric', '12345678901234567890.123', 'numeric', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('oversized', '9223372036854775808', 'oversized', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('dup1', '1', 'dup1', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    ('dup2', '1', 'dup2', ST_GeomFromText('POINT(11.5 48.1)', 4326));

CREATE TABLE "{{schema}}".geometry_edge_cases (
    id bigint PRIMARY KEY,
    name text,
    kind text,
    geom geometry
);

INSERT INTO "{{schema}}".geometry_edge_cases (id, name, kind, geom) VALUES
    (1, 'point', 'point', ST_GeomFromText('POINT(11.5 48.1)', 4326)),
    (2, 'multipoint', 'multipoint', ST_GeomFromText('MULTIPOINT((11.495 48.095), (11.51 48.105))', 4326)),
    (3, 'linestring', 'linestring', ST_GeomFromText('LINESTRING(11.493 48.094, 11.5 48.1, 11.512 48.106)', 4326)),
    (4, 'multilinestring', 'multilinestring', ST_GeomFromText('MULTILINESTRING((11.493 48.094, 11.497 48.098), (11.505 48.102, 11.512 48.106))', 4326)),
    (5, 'polygon', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094))', 4326)),
    (6, 'polygon_hole', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094), (11.499 48.098, 11.506 48.098, 11.506 48.102, 11.499 48.102, 11.499 48.098))', 4326)),
    (7, 'multipolygon', 'multipolygon', ST_GeomFromText('MULTIPOLYGON(((11.493 48.094, 11.498 48.094, 11.498 48.099, 11.493 48.099, 11.493 48.094)), ((11.507 48.101, 11.512 48.101, 11.512 48.106, 11.507 48.106, 11.507 48.101)))', 4326)),
    (8, 'collection_homogeneous', 'geometrycollection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(11.495 48.095), POINT(11.51 48.105))', 4326)),
    (9, 'collection_mixed', 'geometrycollection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(11.5 48.1), LINESTRING(11.493 48.094, 11.512 48.106))', 4326)),
    (10, 'collection_nested', 'geometrycollection', ST_GeomFromText('GEOMETRYCOLLECTION(POINT(11.5 48.1), GEOMETRYCOLLECTION(LINESTRING(11.493 48.094, 11.512 48.106)))', 4326)),
    (11, 'point_empty', 'point', ST_GeomFromText('POINT EMPTY', 4326)),
    (12, 'linestring_empty', 'linestring', ST_GeomFromText('LINESTRING EMPTY', 4326)),
    (13, 'polygon_empty', 'polygon', ST_GeomFromText('POLYGON EMPTY', 4326)),
    (14, 'multipoint_empty', 'multipoint', ST_GeomFromText('MULTIPOINT EMPTY', 4326)),
    (15, 'multilinestring_empty', 'multilinestring', ST_GeomFromText('MULTILINESTRING EMPTY', 4326)),
    (16, 'multipolygon_empty', 'multipolygon', ST_GeomFromText('MULTIPOLYGON EMPTY', 4326)),
    (17, 'collection_empty', 'geometrycollection', ST_GeomFromText('GEOMETRYCOLLECTION EMPTY', 4326)),
    (18, 'point_z', 'point', ST_GeomFromText('POINT Z(11.5 48.1 100)', 4326)),
    (19, 'linestring_z', 'linestring', ST_GeomFromText('LINESTRING Z(11.493 48.094 10, 11.512 48.106 20)', 4326)),
    (20, 'polygon_z', 'polygon', ST_GeomFromText('POLYGON Z((11.493 48.094 0, 11.512 48.094 0, 11.512 48.106 0, 11.493 48.106 0, 11.493 48.094 0))', 4326)),
    (21, 'point_m', 'point', ST_GeomFromText('POINT M(11.5 48.1 5)', 4326)),
    (22, 'linestring_m', 'linestring', ST_GeomFromText('LINESTRING M(11.493 48.094 10, 11.512 48.106 20)', 4326)),
    (23, 'polygon_m', 'polygon', ST_GeomFromText('POLYGON M((11.493 48.094 0, 11.512 48.094 0, 11.512 48.106 0, 11.493 48.106 0, 11.493 48.094 0))', 4326)),
    (24, 'point_zm', 'point', ST_GeomFromText('POINT ZM(11.5 48.1 100 5)', 4326)),
    (25, 'circularstring', 'circularstring', ST_GeomFromText('CIRCULARSTRING(11.493 48.094, 11.5 48.1, 11.512 48.106)', 4326)),
    (26, 'compoundcurve', 'compoundcurve', ST_GeomFromText('COMPOUNDCURVE(CIRCULARSTRING(11.493 48.094, 11.5 48.1, 11.512 48.106), (11.512 48.106, 11.513 48.107))', 4326)),
    (27, 'curvepolygon', 'curvepolygon', ST_GeomFromText('CURVEPOLYGON(CIRCULARSTRING(11.493 48.094, 11.5 48.106, 11.512 48.094, 11.503 48.1, 11.493 48.094))', 4326)),
    (28, 'multicurve', 'multicurve', ST_GeomFromText('MULTICURVE(CIRCULARSTRING(11.493 48.094, 11.5 48.1, 11.512 48.094))', 4326)),
    (29, 'multisurface', 'multisurface', ST_GeomFromText('MULTISURFACE(CURVEPOLYGON(CIRCULARSTRING(11.493 48.094, 11.5 48.106, 11.512 48.094, 11.503 48.1, 11.493 48.094)))', 4326)),
    (30, 'triangle', 'triangle', ST_GeomFromText('TRIANGLE((11.493 48.094, 11.499 48.094, 11.493 48.100, 11.493 48.094))', 4326)),
    (31, 'tin', 'tin', ST_GeomFromText('TIN(((11.493 48.094 0, 11.499 48.094 0, 11.493 48.100 0, 11.493 48.094 0)))', 4326)),
    (32, 'polyhedralsurface', 'polyhedralsurface', ST_GeomFromText('POLYHEDRALSURFACE(((11.493 48.094 0, 11.499 48.094 0, 11.493 48.100 0, 11.493 48.094 0)))', 4326));

CREATE TABLE "{{schema}}".geometry_degeneracy_cases (
    id bigint PRIMARY KEY,
    name text,
    kind text,
    geom geometry
);

INSERT INTO "{{schema}}".geometry_degeneracy_cases (id, name, kind, geom) VALUES
    (1, 'zero_length_line', 'line', ST_GeomFromText('LINESTRING(11.5 48.1, 11.5 48.1)', 4326)),
    (2, 'duplicate_points_line', 'line', ST_GeomFromText('LINESTRING(11.493 48.094, 11.493 48.094, 11.512 48.106)', 4326)),
    (3, 'collinear_line', 'line', ST_GeomFromText('LINESTRING(11.493 48.094, 11.5 48.1, 11.507 48.106)', 4326)),
    (4, 'zero_area_polygon', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.5 48.1, 11.507 48.106, 11.493 48.094))', 4326)),
    (5, 'bowtie_polygon', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.507 48.106, 11.507 48.094, 11.493 48.106, 11.493 48.094))', 4326)),
    (6, 'spike_polygon', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.5 48.094, 11.5 48.106, 11.507 48.094, 11.5 48.094, 11.5 48.086, 11.493 48.094))', 4326)),
    (7, 'cw_exterior', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.493 48.106, 11.512 48.106, 11.512 48.094, 11.493 48.094))', 4326)),
    (8, 'ccw_exterior', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094))', 4326)),
    (9, 'hole_correct', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094), (11.499 48.098, 11.499 48.102, 11.506 48.102, 11.506 48.098, 11.499 48.098))', 4326)),
    (10, 'hole_incorrect', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094), (11.499 48.098, 11.506 48.098, 11.506 48.102, 11.499 48.102, 11.499 48.098))', 4326)),
    (11, 'multiple_holes', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094), (11.496 48.097, 11.499 48.097, 11.499 48.100, 11.496 48.100, 11.496 48.097), (11.505 48.100, 11.508 48.100, 11.508 48.103, 11.505 48.103, 11.505 48.100))', 4326)),
    (12, 'nested_holes', 'polygon', ST_GeomFromText('POLYGON((11.493 48.094, 11.512 48.094, 11.512 48.106, 11.493 48.106, 11.493 48.094), (11.496 48.097, 11.509 48.097, 11.509 48.103, 11.496 48.103, 11.496 48.097), (11.500 48.099, 11.505 48.099, 11.505 48.101, 11.500 48.101, 11.500 48.099))', 4326)),
    (13, 'collapsed_polygon', 'polygon', ST_GeomFromText('POLYGON((11.50270 48.10010, 11.50271 48.10010, 11.50271 48.10011, 11.50270 48.10011, 11.50270 48.10010))', 4326)),
    (14, 'antimeridian_line', 'line', ST_GeomFromText('LINESTRING(179.9 48, -179.9 48)', 4326)),
    (15, 'antimeridian_polygon', 'polygon', ST_GeomFromText('POLYGON((179.8 48, -179.8 48, -179.8 48.2, 179.8 48.2, 179.8 48))', 4326)),
    (16, 'north_pole', 'point', ST_GeomFromText('POINT(0 89.999)', 4326)),
    (17, 'south_pole', 'point', ST_GeomFromText('POINT(0 -89.999)', 4326)),
    (18, 'mercator_max', 'point', ST_GeomFromText('POINT(0 85.0511)', 4326)),
    (19, 'mercator_min', 'point', ST_GeomFromText('POINT(0 -85.0511)', 4326)),
    (20, 'large_coordinates', 'line', ST_GeomFromText('LINESTRING(10000000 10000000, 10000001 10000001)', 4326)),
    (21, 'small_coordinates', 'line', ST_GeomFromText('LINESTRING(0.000000001 0.000000001, 0.000000002 0.000000002)', 4326)),
    (22, 'nan_point', 'point', ST_SetSRID(ST_MakePoint('NaN'::float8, 'NaN'::float8), 4326)),
    (23, 'infinite_point', 'point', ST_SetSRID(ST_MakePoint('Infinity'::float8, 48.1), 4326));

CREATE TABLE "{{schema}}".srid_edge_cases (
    id bigint PRIMARY KEY,
    name text,
    geom geometry
);

INSERT INTO "{{schema}}".srid_edge_cases (id, name, geom) VALUES
    (1, 'srid_4326', ST_SetSRID(ST_MakePoint(11.5, 48.1), 4326)),
    (2, 'srid_3857', ST_SetSRID(ST_MakePoint(11.5, 48.1), 3857)),
    (3, 'srid_0', ST_SetSRID(ST_MakePoint(11.5, 48.1), 0)),
    (4, 'null_geometry', NULL),
    (5, 'srid_32633', ST_SetSRID(ST_MakePoint(11.5, 48.1), 32633));

CREATE TABLE "{{schema}}".geometry_column_edge_cases (
    id bigint PRIMARY KEY,
    name text,
    geometry geometry(Point, 4326),
    shape geometry(Point, 4326),
    "select" geometry(Point, 4326),
    "GEOM" geometry(Point, 4326),
    geom_text text
);

INSERT INTO "{{schema}}".geometry_column_edge_cases (
    id, name, geometry, shape, "select", "GEOM", geom_text
) VALUES (
    1, 'all-columns',
    ST_GeomFromText('POINT(11.5 48.1)', 4326),
    ST_GeomFromText('POINT(11.501 48.101)', 4326),
    ST_GeomFromText('POINT(11.502 48.102)', 4326),
    ST_GeomFromText('POINT(11.503 48.103)', 4326),
    'not geometry'
);

CREATE TABLE "{{schema}}".non_geometry_geom (
    id bigint PRIMARY KEY,
    name text,
    geom text
);

INSERT INTO "{{schema}}".non_geometry_geom (id, name, geom) VALUES
    (1, 'text-geom', 'POINT(11.5 48.1)');

CREATE TABLE "{{schema}}".bytea_geometry (
    id bigint PRIMARY KEY,
    name text,
    geom bytea
);

INSERT INTO "{{schema}}".bytea_geometry (id, name, geom) VALUES
    (1, 'truncated', '\x0101000000000000000000F03F'::bytea);

CREATE TABLE "{{schema}}".geometry_join (
    id bigint PRIMARY KEY,
    name text,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".geometry_join (id, name, geom) VALUES
    (1, 'join-row', ST_GeomFromText('POINT(11.5 48.1)', 4326));

CREATE TABLE "{{schema}}".clip_edge_features (
    id bigint PRIMARY KEY,
    name text,
    geom geometry(Point, 4326)
);

INSERT INTO "{{schema}}".clip_edge_features (id, name, geom) VALUES
    (1, 'north_west', ST_GeomFromText('POINT(11.49169921875 48.1074311884804)', 4326)),
    (2, 'north_east', ST_GeomFromText('POINT(11.513671875 48.1074311884804)', 4326)),
    (3, 'south_east', ST_GeomFromText('POINT(11.513671875 48.09275716032736)', 4326)),
    (4, 'south_west', ST_GeomFromText('POINT(11.49169921875 48.09275716032736)', 4326)),
    (5, 'north_center', ST_GeomFromText('POINT(11.502685546875 48.1074311884804)', 4326)),
    (6, 'east_center', ST_GeomFromText('POINT(11.513671875 48.10009417440378)', 4326)),
    (7, 'just_outside', ST_GeomFromText('POINT(11.5137 48.10009417440378)', 4326));
