import Foundation
import GISTools
import Yams

// MARK: MapnikYMLSource

/// Loads the Postgis configuration from a Mapnik YML source file.
struct MapnikYMLSource: Decodable {

    static func load(
        from url: URL,
        layerAllowlist: [String])
        throws -> PostgisSource
    {
        let data = try Data(contentsOf: url)
        return try load(from: data, layerAllowlist: layerAllowlist)
    }

    static func load(
        from data: Data,
        layerAllowlist: [String])
        throws -> PostgisSource
    {
        let ymlSource = try YAMLDecoder().decode(MapnikYMLSource.self, from: data)
        let ymlLayers = ymlSource.layers
            .filter({ layer in
                guard layerAllowlist.isNotEmpty else { return true }
                return layerAllowlist.contains(layer.id)
            })
            .map(\.asMapnikLayer)

        return PostgisSource(
            name: ymlSource.name,
            description: ymlSource.description,
            attribution: ymlSource.attribution,
            center: ymlSource.center,
            defaultZoom: ymlSource.defaultZoom,
            minZoom: ymlSource.minZoom,
            maxZoom: ymlSource.maxZoom,
            layers: ymlLayers)
    }

    // MARK: - Private

    private let name: String
    private let description: String
    private let attribution: String

    private let _center: [Double]
    private var center: Coordinate3D {
        guard _center.count >= 2 else { return Coordinate3D(latitude: 0.0, longitude: 0.0) }
        return Coordinate3D(latitude: _center[1], longitude: _center[0])
    }
    private var defaultZoom: Int {
        guard _center.count >= 3 else { return 14 }
        return Int(_center[2])
    }
    private let minZoom: Int
    private let maxZoom: Int

    private let layers: [MapnikYMLLayer]

    enum CodingKeys: String, CodingKey {
        case name, description, attribution

        case _center = "center"
        case minZoom = "minzoom"
        case maxZoom = "maxzoom"

        case layers = "Layer"
    }

}

// MARK: - MapnikYMLLayer

private struct MapnikYMLLayer: Decodable {

    let id: String
    let description: String
    let srs: String
    let fields: [String: String]
    let datasource: MapnikYMLDatasource

    private let properties: MapnikYMLProperties
    var bufferSize: Int {
        return properties.bufferSize
    }

    var asMapnikLayer: PostgisLayer {
        PostgisLayer(
            id: id,
            description: description,
            srs: srs,
            fields: fields,
            datasource: datasource.asMapnikDatasource,
            bufferSize: bufferSize)
    }

    enum CodingKeys: String, CodingKey {
        case id, description, srs, properties, fields

        case datasource = "Datasource"
    }

    private struct MapnikYMLProperties: Decodable {
        let bufferSize: Int

        enum CodingKeys: String, CodingKey {
            case bufferSize = "buffer-size"
        }
    }

}

// MARK: - MapnikYMLDatasource

private struct MapnikYMLDatasource: Decodable {

    let user: String
    let password: String
    let host: String
    let port: Int

    let databaseName: String
    let geometryField: String
    let geometryTable: String
    let keyField: String
    let keyFieldAsAttribute: String

    let extent: String
    let srid: String
    let type: String
    let maxSize: Int
    let sql: String

    var asMapnikDatasource: PostgisDatasource {
        PostgisDatasource(
            user: user,
            password: password,
            host: host,
            port: port,
            databaseName: databaseName,
            geometryField: geometryField,
            geometryTable: geometryTable,
            keyField: keyField,
            keyFieldAsAttribute: keyFieldAsAttribute,
            extent: extent,
            srid: srid,
            type: type,
            maxSize: maxSize,
            sql: sql)
    }

    enum CodingKeys: String, CodingKey {
        case user, password, host, port

        case databaseName = "dbname"
        case geometryField = "geometry_field"
        case geometryTable = "geometry_table"
        case keyField = "key_field"
        case keyFieldAsAttribute = "key_field_as_attribute"

        case extent, srid, type
        case maxSize = "max_size"
        case sql = "table"
    }

}
