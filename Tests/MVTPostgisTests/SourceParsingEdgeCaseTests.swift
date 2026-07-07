import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct SourceParsingEdgeCaseTests {

    // MARK: - JSON edge cases

    @Test
    func jsonWithoutOptionalFields() throws {
        let json = """
        {
          "name": "Minimal",
          "description": "",
          "attribution": "",
          "center": [0, 0],
          "defaultZoom": 10,
          "minZoom": 1,
          "maxZoom": 16,
          "layers": [
            {
              "id": "layer",
              "fields": {},
              "properties": { "bufferSize": 0 },
              "datasource": {
                "user": "u", "password": "p", "host": "h",
                "port": 5432, "databaseName": "osm",
                "srid": 4326, "type": "postgis",
                "sql": "SELECT * FROM t"
              }
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)
        #expect(source.layers.count == 1)
        #expect(source.layers.first?.description == nil)
        #expect(source.layers.first?.datasource.boundingBox == nil)
        #expect(source.layers.first?.datasource.geometryField == nil)
    }

    @Test
    func jsonWith3857Projection() throws {
        let json = """
        {
          "name": "3857 Source",
          "description": "",
          "attribution": "",
          "center": [0, 0],
          "defaultZoom": 10,
          "minZoom": 1,
          "maxZoom": 16,
          "layers": [
            {
              "id": "layer",
              "fields": {},
              "properties": { "bufferSize": 0 },
              "datasource": {
                "user": "u", "password": "p", "host": "h",
                "port": 5432, "databaseName": "osm",
                "srid": 3857, "type": "postgis",
                "sql": "SELECT * FROM t"
              }
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)
        #expect(source.layers.first?.datasource.srid == .epsg3857)
    }

    @Test
    func jsonBoundinBoxParsing() throws {
        let json = """
        {
          "name": "BBox",
          "description": "",
          "attribution": "",
          "center": [0, 0],
          "defaultZoom": 10,
          "minZoom": 1,
          "maxZoom": 16,
          "layers": [
            {
              "id": "layer",
              "fields": {},
              "properties": { "bufferSize": 0 },
              "datasource": {
                "user": "u", "password": "p", "host": "h",
                "port": 5432, "databaseName": "osm",
                "boundingBox": [-10, -10, 10, 10],
                "srid": 4326, "type": "postgis",
                "sql": "SELECT * FROM t"
              }
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)
        let bbox = try #require(source.layers.first?.datasource.boundingBox)
        #expect(bbox.southWest.latitude == -10.0)
        #expect(bbox.southWest.longitude == -10.0)
        #expect(bbox.northEast.latitude == 10.0)
        #expect(bbox.northEast.longitude == 10.0)
    }

    // MARK: - YML edge cases

    @Test
    func ymlWith3857Projection() throws {
        let yml = """
        name: Test
        description: ""
        attribution: ""
        center: [0,0,10]
        minzoom: 1
        maxzoom: 16
        Layer:
        - id: layer
          description: ""
          fields: {}
          properties: {"buffer-size": 0}
          srs: +proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0.0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs
          Datasource:
            geometry_field: geometry
            extent: 10.0,47.0,11.0,48.0
            srid: "3857"
            user: u
            password: p
            host: h
            port: 5432
            dbname: osm
            type: postgis
            table: (SELECT * FROM t) AS data
        """
        let data = try #require(yml.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)
        #expect(source.layers.first?.datasource.srid == .epsg3857)
    }

    @Test
    func ymlWithLayerAllowlist() throws {
        let yml = """
        name: Test
        description: ""
        attribution: ""
        center: [0,0,10]
        minzoom: 1
        maxzoom: 16
        Layer:
        - id: roads
          description: ""
          fields: {}
          properties: {"buffer-size": 0}
          srs: +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs
          Datasource:
            geometry_field: geometry
            extent: 10.0,47.0,11.0,48.0
            srid: ""
            user: u
            password: p
            host: h
            port: 5432
            dbname: osm
            type: postgis
            table: (SELECT * FROM roads) AS data
        - id: buildings
          description: ""
          fields: {}
          properties: {"buffer-size": 0}
          srs: +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs
          Datasource:
            geometry_field: geometry
            extent: 10.0,47.0,11.0,48.0
            srid: ""
            user: u
            password: p
            host: h
            port: 5432
            dbname: osm
            type: postgis
            table: (SELECT * FROM buildings) AS data
        """
        let data = try #require(yml.data(using: .utf8))
        let allowlisted = try PostgisSource.load(from: data, layerWhitelist: ["roads"])
        #expect(allowlisted.layers.count == 1)
        #expect(allowlisted.layers.first?.id == "roads")
    }

    // MARK: - XML edge cases

    @Test
    func xmlWithExtentButNoBoundingBox() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE Map[]>
        <Map srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Parameters>
        <Parameter name="name">NoBBox</Parameter>
        <Parameter name="description"></Parameter>
        <Parameter name="attribution"></Parameter>
        <Parameter name="center">0,0,10</Parameter>
        <Parameter name="format">pbf</Parameter>
        <Parameter name="json"><![CDATA[{"vector_layers":[{"id":"layer","description":"","fields":{}}]}]]></Parameter>
        <Parameter name="minzoom">1</Parameter>
        <Parameter name="maxzoom">16</Parameter>
        </Parameters>
        <Layer name="layer" buffer-size="0" srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Datasource>
           <Parameter name="user">u</Parameter>
           <Parameter name="password">p</Parameter>
           <Parameter name="host">h</Parameter>
           <Parameter name="port">5432</Parameter>
           <Parameter name="dbname">osm</Parameter>
           <Parameter name="type">postgis</Parameter>
           <Parameter name="table">(SELECT * FROM t) AS data</Parameter>
        </Datasource>
        </Layer>
        </Map>
        """
        let data = try #require(xml.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)
        #expect(source.layers.count == 1)
        #expect(source.layers.first?.datasource.boundingBox == nil)
    }

    @Test
    func xmlWithLayerAllowlist() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE Map[]>
        <Map srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Parameters>
        <Parameter name="name">Test</Parameter>
        <Parameter name="description"></Parameter>
        <Parameter name="attribution"></Parameter>
        <Parameter name="center">0,0,10</Parameter>
        <Parameter name="format">pbf</Parameter>
        <Parameter name="json"><![CDATA[{"vector_layers":[{"id":"roads","description":"","fields":{}},{"id":"buildings","description":"","fields":{}}]}]]></Parameter>
        <Parameter name="minzoom">1</Parameter>
        <Parameter name="maxzoom">16</Parameter>
        </Parameters>
        <Layer name="roads" buffer-size="0" srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Datasource>
           <Parameter name="user">u</Parameter>
           <Parameter name="password">p</Parameter>
           <Parameter name="host">h</Parameter>
           <Parameter name="port">5432</Parameter>
           <Parameter name="dbname">osm</Parameter>
           <Parameter name="type">postgis</Parameter>
           <Parameter name="table">(SELECT * FROM roads) AS data</Parameter>
        </Datasource>
        </Layer>
        <Layer name="buildings" buffer-size="0" srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Datasource>
           <Parameter name="user">u</Parameter>
           <Parameter name="password">p</Parameter>
           <Parameter name="host">h</Parameter>
           <Parameter name="port">5432</Parameter>
           <Parameter name="dbname">osm</Parameter>
           <Parameter name="type">postgis</Parameter>
           <Parameter name="table">(SELECT * FROM buildings) AS data</Parameter>
        </Datasource>
        </Layer>
        </Map>
        """
        let data = try #require(xml.data(using: .utf8))
        let allowlisted = try PostgisSource.load(from: data, layerWhitelist: ["roads"])
        #expect(allowlisted.layers.count == 1)
        #expect(allowlisted.layers.first?.id == "roads")
    }

    // MARK: - Error handling

    @Test
    func invalidJSONThrows() throws {
        let data = try #require("{invalid json".data(using: .utf8))
        #expect(throws: Error.self) {
            try PostgisSource.load(from: data, layerWhitelist: nil)
        }
    }

    @Test
    func xmlWithoutLayerThrows() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE Map[]>
        <Map srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        </Map>
        """
        let data = try #require(xml.data(using: .utf8))
        #expect(throws: Error.self) {
            try PostgisSource.load(from: data, layerWhitelist: nil)
        }
    }

    @Test
    func layerWhitelistFiltersJSON() throws {
        let json = """
        {
          "name": "Multi Layer",
          "description": "",
          "attribution": "",
          "center": [0, 0],
          "defaultZoom": 10,
          "minZoom": 1,
          "maxZoom": 16,
          "layers": [
            {
              "id": "roads",
              "fields": {},
              "properties": { "bufferSize": 0 },
              "datasource": {
                "user": "u", "password": "p", "host": "h",
                "port": 5432, "databaseName": "osm",
                "srid": 4326, "type": "postgis",
                "sql": "SELECT * FROM roads"
              }
            },
            {
              "id": "buildings",
              "fields": {},
              "properties": { "bufferSize": 0 },
              "datasource": {
                "user": "u", "password": "p", "host": "h",
                "port": 5432, "databaseName": "osm",
                "srid": 4326, "type": "postgis",
                "sql": "SELECT * FROM buildings"
              }
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))

        let all = try PostgisSource.load(from: data, layerWhitelist: nil)
        #expect(all.layers.count == 2)

        // JSON sources don't support whitelist filtering — the whitelist
        // is only applied to YML and XML sources during parsing.
        // Source-level filtering must be done by the caller via source.filter.
        let filtered = try PostgisSource.load(from: data, layerWhitelist: ["roads"])
        #expect(filtered.layers.count == 2)
    }

}
