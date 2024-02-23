import Foundation
import GISTools
@testable import MVTPostgis
import XCTest

final class XMLSourceTests: XCTestCase {

    private static let xmlSource = """
    <?xml version="1.0" encoding="utf-8"?>
    <!DOCTYPE Map[]>
    <Map srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">

    <Parameters>
    <Parameter name="name"><![CDATA[Test Source]]></Parameter>
    <Parameter name="description"><![CDATA[A test source for testing]]></Parameter>
    <Parameter name="attribution"><![CDATA[Here goes the copyright]]></Parameter>
    <Parameter name="center">10.22,47.56,10</Parameter>
    <Parameter name="format">pbf</Parameter>
    <Parameter name="json"><![CDATA[{"vector_layers":[{"id":"First layer","description":"This is the first layer","fields":{"type":"String"}}]}]]></Parameter>
    <Parameter name="minzoom">1</Parameter>
    <Parameter name="maxzoom">16</Parameter>
    </Parameters>

    <Layer name="First layer"
    buffer-size="128"
    srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs">

    <Datasource>
       <Parameter name="user"><![CDATA[user]]></Parameter>
       <Parameter name="password"><![CDATA[password]]></Parameter>
       <Parameter name="host"><![CDATA[host]]></Parameter>
       <Parameter name="port"><![CDATA[5432]]></Parameter>
       <Parameter name="dbname"><![CDATA[osm]]></Parameter>
       <Parameter name="geometry_field"><![CDATA[geometry]]></Parameter>
       <Parameter name="geometry_table"><![CDATA[]]></Parameter>
       <Parameter name="key_field"><![CDATA[]]></Parameter>
       <Parameter name="key_field_as_attribute"><![CDATA[]]></Parameter>
       <Parameter name="extent"><![CDATA[10.0,47.0,11.0,48.0]]></Parameter>
       <Parameter name="srid"><![CDATA[]]></Parameter>
       <Parameter name="type"><![CDATA[postgis]]></Parameter>
       <Parameter name="max_size"><![CDATA[512]]></Parameter>
       <Parameter name="table"><![CDATA[(SELECT type, geometry FROM some_table) AS data]]></Parameter>
    </Datasource>
    </Layer>
    </Map>
    """

    func testXMLSource() throws {
        let data = try XCTUnwrap(XMLSourceTests.xmlSource.data(using: .utf8))
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
