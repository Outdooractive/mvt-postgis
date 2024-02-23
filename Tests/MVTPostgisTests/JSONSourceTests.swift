import Foundation
import GISTools
@testable import MVTPostgis
import XCTest

final class JSONSourceTests: XCTestCase {

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

    func testJSONSource() throws {
        let data = try XCTUnwrap(JSONSourceTests.jsonSource.data(using: .utf8))
        let source = try PostgisSource.load(from: data, layerWhitelist: nil)

        XCTAssertEqual(source.name, "Test Source")
        XCTAssertEqual(source.description, "A test source for testing")
        XCTAssertEqual(source.attribution, "Here goes the copyright")
        XCTAssertEqual(source.center, Coordinate3D(latitude: 47.56, longitude: 10.22))
        XCTAssertEqual(source.defaultZoom, 10)
        XCTAssertEqual(source.minZoom, 1)
        XCTAssertEqual(source.maxZoom, 16)
        XCTAssertEqual(source.layers.count, 1)

        let layer = try XCTUnwrap(source.layers.first)
        XCTAssertEqual(layer.id, "First layer")
        XCTAssertEqual(layer.description, "This is the first layer")
        XCTAssertEqual(layer.fields.count, 2)
        XCTAssertTrue(layer.fields.hasKey("type"))
        XCTAssertTrue(layer.fields.hasKey("geometry"))
        XCTAssertEqual(layer.properties.bufferSize, 128)

        let datasource = layer.datasource
        XCTAssertEqual(datasource.user, "user")
        XCTAssertEqual(datasource.password, "password")
        XCTAssertEqual(datasource.host, "host")
        XCTAssertEqual(datasource.port, 5432)
        XCTAssertEqual(datasource.databaseName, "osm")
        XCTAssertEqual(datasource.geometryField, "geometry")
        XCTAssertEqual(datasource.boundingBox, BoundingBox(
            southWest: Coordinate3D(latitude: 47.0, longitude: 10.0),
            northEast: Coordinate3D(latitude: 48.0, longitude: 11.0)))
        XCTAssertEqual(datasource.srid, .epsg4326)
        XCTAssertEqual(datasource.type, "postgis")
        XCTAssertEqual(datasource.sql, "(SELECT type, geometry FROM some_table) AS data")
    }

}
