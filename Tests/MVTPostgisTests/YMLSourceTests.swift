import Foundation
import GISTools
@testable import MVTPostgis
import XCTest

final class YMLSourceTests: XCTestCase {

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

    func testYMLSource() throws {
        let data = try XCTUnwrap(YMLSourceTests.ymlSource.data(using: .utf8))
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
        XCTAssertEqual(layer.fields.count, 1)
        XCTAssertTrue(layer.fields.hasKey("type"))
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
