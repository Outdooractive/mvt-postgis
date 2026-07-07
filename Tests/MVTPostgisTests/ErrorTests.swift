import Foundation
@testable import MVTPostgis
import Testing

struct MVTPostgisErrorTests {

    @Test
    func cancelled() {
        #expect(MVTPostgisError.cancelled.description == "Cancelled")
    }

    @Test
    func connectionFailed() {
        #expect(MVTPostgisError.connectionFailed.description == "Connection failed")
    }

    @Test
    func needLayers() {
        #expect(MVTPostgisError.needLayers.description == "Need layers")
    }

    @Test
    func tileOutOfBounds() {
        #expect(MVTPostgisError.tileOutOfBounds.description == "Tile out of bounds")
    }

    @Test
    func tileTimedOut() {
        let error = MVTPostgisError.tileTimedOut(queries: ["SELECT 1"])
        #expect(error.description == "Tile timed out:\nQuery #1:\nSELECT 1")
    }

    @Test
    func unsupportedSRID() {
        #expect(MVTPostgisError.unsupportedSRID.description == "Unsupported SRID")
    }

    @Test
    func unsupportedSRS() {
        #expect(MVTPostgisError.unsupportedSRS.description == "Unsupported SRS")
    }

    @Test
    func wrongDatasourceType() {
        let error = MVTPostgisError.wrongDatasourceType(message: "test")
        #expect(error.description == "Wrong datasource type: test")
    }

    @Test
    func xmlError() {
        let error = MVTPostgisError.xmlError(message: "parse error")
        #expect(error.description == "XML error: parse error")
    }

    @Test
    func layerAllowlistFiltersJSON() throws {
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

        let all = try PostgisSource.load(from: data, layerAllowlist: nil)
        #expect(all.layers.count == 2)

        let filtered = try PostgisSource.load(from: data, layerAllowlist: ["roads"])
        #expect(filtered.layers.count == 1)
    }

}
