import Foundation
@testable import MVTPostgis
import Testing

struct MVTPostgisErrorTests {

    @Test
    func cancelled() throws {
        let error = MVTPostgisError.cancelled
        #expect(error != nil)
    }

    @Test
    func connectionFailed() throws {
        let error = MVTPostgisError.connectionFailed
        #expect(error != nil)
    }

    @Test
    func needLayers() throws {
        let error = MVTPostgisError.needLayers
        #expect(error != nil)
    }

    @Test
    func tileOutOfBounds() throws {
        let error = MVTPostgisError.tileOutOfBounds
        #expect(error != nil)
    }

    @Test
    func tileTimedOut() throws {
        let error = MVTPostgisError.tileTimedOut(queries: ["SELECT 1"])
        #expect(error != nil)
    }

    @Test
    func unsupportedSRID() throws {
        let error = MVTPostgisError.unsupportedSRID
        #expect(error != nil)
    }

    @Test
    func unsupportedSRS() throws {
        let error = MVTPostgisError.unsupportedSRS
        #expect(error != nil)
    }

    @Test
    func wrongDatasourceType() throws {
        let error = MVTPostgisError.wrongDatasourceType(message: "test")
        #expect(error != nil)
    }

    @Test
    func xmlError() throws {
        let error = MVTPostgisError.xmlError(message: "test")
        #expect(error != nil)
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

        let filtered = try PostgisSource.load(from: data, layerWhitelist: ["roads"])
        #expect(filtered.layers.count == 2)
    }

}
