import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct YMLSourceTests {

    private static let ymlSource = """
    name: Test Source
    description: A test source for testing
    attribution: Here goes the copyright
    center:
    - 10.22
    - 47.56
    - 10
    minzoom: 1
    maxzoom: 16
    Layer:
    - id: First layer
      description: This is the first layer
      fields:
          type: String
      properties:
          "buffer-size": 128
      srs: +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs
      Datasource:
          user: user
          password: password
          host: host
          port: 5432
          dbname: osm
          geometry_field: geometry
          geometry_table: ''
          key_field: ''
          key_field_as_attribute: ''
          extent: 10.0,47.0,11.0,48.0
          srid: ''
          type: postgis
          max_size: 512
          table: |-
            (SELECT type, geometry FROM some_table) AS data
    """

    @Test
    func YMLSource() throws {
        let data = try #require(YMLSourceTests.ymlSource.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)

        #expect(source.name == "Test Source")
        #expect(source.description == "A test source for testing")
        #expect(source.attribution == "Here goes the copyright")
        #expect(source.center == Coordinate3D(latitude: 47.56, longitude: 10.22))
        #expect(source.defaultZoom == 10)
        #expect(source.minZoom == 1)
        #expect(source.maxZoom == 16)
        #expect(source.layers.count == 1)

        let layer = try #require(source.layers.first)
        #expect(layer.id == "First layer")
        #expect(layer.description == "This is the first layer")
        #expect(layer.fields.count == 1)
        #expect(layer.fields.hasKey("type"))
        #expect(layer.properties.bufferSize == 128)

        let datasource = layer.datasource
        #expect(datasource.user == "user")
        #expect(datasource.password == "password")
        #expect(datasource.host == "host")
        #expect(datasource.port == 5432)
        #expect(datasource.databaseName == "osm")
        #expect(datasource.geometryField == "geometry")
        #expect(datasource.boundingBox == BoundingBox(
            southWest: Coordinate3D(latitude: 47.0, longitude: 10.0),
            northEast: Coordinate3D(latitude: 48.0, longitude: 11.0)))
        #expect(datasource.srid == .epsg4326)
        #expect(datasource.type == "postgis")
        #expect(datasource.sql == "(SELECT type, geometry FROM some_table) AS data")
    }

}
