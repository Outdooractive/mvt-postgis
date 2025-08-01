import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct JSONSourceTests {

    private static let jsonSource = """
    {
      "name": "Test Source",
      "description": "A test source for testing",
      "attribution": "Here goes the copyright",
      "center": [
        10.22,
        47.56
      ],
      "defaultZoom": 10,
      "minZoom": 1,
      "maxZoom": 16,
      "layers": [
        {
          "id": "First layer",
          "description": "This is the first layer",
          "fields": {
            "type": "The object's type",
            "geometry": ""
          },
          "properties": {
            "bufferSize": 128
          },
          "datasource": {
            "user": "user",
            "password": "password",
            "host": "host",
            "port": 5432,
            "databaseName": "osm",
            "geometryField": "geometry",
            "boundingBox": [
              10,
              47,
              11,
              48
            ],
            "srid": 4326,
            "type": "postgis",
            "sql": "(SELECT type, geometry FROM some_table) AS data"
          }
        }
      ]
    }
    """

    @Test
    func JSONSource() async throws {
        let data = try #require(JSONSourceTests.jsonSource.data(using: .utf8))
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
        #expect(layer.fields.count == 2)
        #expect(layer.fields.hasKey("type"))
        #expect(layer.fields.hasKey("geometry"))
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
