import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct SourceDefaultsTests {

    @Test
    func `json minimal source uses defaults`() throws {
        let json = """
        {
          "name": "Minimal",
          "layers": [
            {
              "id": "layer",
              "datasource": {
                "user": "u",
                "host": "h",
                "databaseName": "db",
                "srid": 4326,
                "type": "postgis",
                "sql": "SELECT * FROM t"
              }
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerAllowlist: nil)

        #expect(source.description == "")
        #expect(source.attribution == "")
        #expect(source.center == .zero)
        #expect(source.defaultZoom == 14)
        #expect(source.minZoom == 0)
        #expect(source.maxZoom == 20)
        #expect(source.origin == .json)

        let layer = try #require(source.layers.first)
        #expect(layer.description == nil)
        #expect(layer.fields.isEmpty)
        #expect(layer.properties.bufferSize == 0)
        #expect(layer.datasource.password == "")
        #expect(layer.datasource.port == 5432)
        #expect(layer.datasource.geometryField == nil)
        #expect(layer.datasource.boundingBox == nil)
    }

    @Test
    func `json detects leading whitespace and BOM`() throws {
        let json = """
        {
          "name": "Whitespace",
          "layers": []
        }
        """
        let plain = Data(" \n\t".utf8) + Data(json.utf8)
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data(json.utf8)

        #expect(try PostgisSource.load(from: plain, layerAllowlist: nil).name == "Whitespace")
        #expect(try PostgisSource.load(from: bom, layerAllowlist: nil).name == "Whitespace")
    }

    @Test
    func `yml minimal source uses defaults`() throws {
        let yml = """
        name: Minimal
        Layer:
        - id: layer
          srs: +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs
          Datasource:
            user: u
            host: h
            dbname: db
            type: postgis
            table: (SELECT * FROM t) AS data
        """
        let data = try #require(yml.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerAllowlist: nil)

        #expect(source.description == "")
        #expect(source.attribution == "")
        #expect(source.center == .zero)
        #expect(source.defaultZoom == 14)
        #expect(source.minZoom == 0)
        #expect(source.maxZoom == 20)
        #expect(source.origin == .yml)

        let layer = try #require(source.layers.first)
        #expect(layer.description == nil)
        #expect(layer.fields.isEmpty)
        #expect(layer.properties.bufferSize == 0)
        #expect(layer.datasource.password == "")
        #expect(layer.datasource.port == 5432)
        #expect(layer.datasource.geometryField == nil)
        #expect(layer.datasource.boundingBox == nil)
    }

    @Test
    func `yml clamps negative buffer size`() throws {
        let yml = """
        name: Buffered
        Layer:
        - id: layer
          srs: +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs
          properties:
            buffer-size: -10
          Datasource:
            user: u
            host: h
            dbname: db
            type: postgis
            table: (SELECT * FROM t) AS data
        """
        let data = try #require(yml.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerAllowlist: nil)
        #expect(source.layers.first?.properties.bufferSize == 0)
    }

    @Test
    func `xml style element before datasource is ignored`() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <Map srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Parameters>
        <Parameter name="name">Styled</Parameter>
        <Parameter name="center">0,0,10</Parameter>
        </Parameters>
        <Layer name="roads">
        <StyleName>roads</StyleName>
        <Datasource>
           <Parameter name="user">u</Parameter>
           <Parameter name="password"></Parameter>
           <Parameter name="host">h</Parameter>
           <Parameter name="dbname">osm</Parameter>
           <Parameter name="type">postgis</Parameter>
           <Parameter name="table">(SELECT * FROM roads) AS data</Parameter>
        </Datasource>
        </Layer>
        </Map>
        """
        let data = try #require(xml.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerAllowlist: nil)
        let layer = try #require(source.layers.first)

        #expect(layer.id == "roads")
        #expect(layer.properties.bufferSize == 0)
        #expect(layer.fields.isEmpty)
        #expect(layer.datasource.password == "")
        #expect(layer.datasource.geometryField == nil)
    }

    @Test
    func `xml uses map SRS when layer has none`() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <Map srs="+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0.0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs">
        <Parameters>
        <Parameter name="name">MapSRS</Parameter>
        </Parameters>
        <Layer name="roads">
        <Datasource>
           <Parameter name="user">u</Parameter>
           <Parameter name="host">h</Parameter>
           <Parameter name="dbname">osm</Parameter>
           <Parameter name="type">postgis</Parameter>
           <Parameter name="table">(SELECT * FROM roads) AS data</Parameter>
        </Datasource>
        </Layer>
        </Map>
        """
        let data = try #require(xml.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerAllowlist: nil)
        #expect(source.layers.first?.datasource.srid == .epsg3857)
    }

}

// MARK: - URL loading

struct SourceURLLoadingTests {

    @Test
    func `loads JSONYML and XML from URLs`() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mvt-postgis-source-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let jsonURL = directory.appendingPathComponent("source.json")
        let ymlURL = directory.appendingPathComponent("source.yml")
        let xmlURL = directory.appendingPathComponent("source.xml")

        try Data(#"{"name":"JSON"}"#.utf8).write(to: jsonURL)
        try Data("name: YML\n".utf8).write(to: ymlURL)
        try Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <Map srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">
        <Parameters><Parameter name="name">XML</Parameter></Parameters>
        <Layer name="layer">
        <Datasource>
        <Parameter name="user">u</Parameter>
        <Parameter name="host">h</Parameter>
        <Parameter name="dbname">db</Parameter>
        <Parameter name="type">postgis</Parameter>
        <Parameter name="table">(SELECT * FROM t) AS data</Parameter>
        </Datasource>
        </Layer>
        </Map>
        """.utf8).write(to: xmlURL)

        #expect(try PostgisSource.load(from: jsonURL, layerAllowlist: nil).name == "JSON")
        #expect(try PostgisSource.load(from: ymlURL, layerAllowlist: nil).name == "YML")
        #expect(try PostgisSource.load(from: xmlURL, layerAllowlist: nil).name == "XML")
    }

    @Test
    func `source codable round trip`() throws {
        let datasource = PostgisDatasource(
            user: "u",
            host: "h",
            databaseName: "db",
            geometryField: "geometry",
            srid: .epsg3857,
            type: "postgis",
            sql: "(SELECT * FROM t) AS data")
        let source = PostgisSource(
            name: "Roundtrip",
            layers: [
                PostgisLayer(
                    id: "layer",
                    description: "Description",
                    fields: ["name": "Name"],
                    properties: .init(bufferSize: 32),
                    datasource: datasource),
            ])

        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(PostgisSource.self, from: data)

        #expect(decoded.name == source.name)
        #expect(decoded.layers.count == 1)
        #expect(decoded.layers[0].id == "layer")
        #expect(decoded.layers[0].description == "Description")
        #expect(decoded.layers[0].fields == ["name": "Name"])
        #expect(decoded.layers[0].properties.bufferSize == 32)
        #expect(decoded.layers[0].datasource.srid == .epsg3857)
    }

    @Test
    func `mapnik SRS parsing`() {
        #expect(MapnikSRS.projection(
            from: "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs") == .epsg4326)
        #expect(MapnikSRS.projection(
            from: "+proj=merc +a=6378137 +b=6378137 +units=m") == .epsg3857)
        #expect(MapnikSRS.projection(
            from: "+proj=merc +a=6378137 +b=6378137 +units=m +over") == .epsg3857)
        #expect(MapnikSRS.projection(from: "unknown") == .noSRID)
    }

}
