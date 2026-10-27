import Foundation
import GISTools
import Yams

/// Loads the PostGIS configuration from a Mapnik YML source file.
struct MapnikYMLSource: Decodable {

    static func load(
        from url: URL,
        layerAllowlist: [String],
    ) throws -> PostgisSource {
        let data = try Data(contentsOf: url)
        return try load(from: data, layerAllowlist: layerAllowlist)
    }

    static func load(
        from data: Data,
        layerAllowlist: [String],
    ) throws -> PostgisSource {
        let ymlSource = try YAMLDecoder().decode(MapnikYMLSource.self, from: data)
        let ymlLayers = ymlSource.layers
            .filter({ layer in
                guard layerAllowlist.isNotEmpty else { return true }

                return layerAllowlist.contains(layer.id)
            })
            .map(\.asPostgisLayer)

        return PostgisSource(
            name: ymlSource.name,
            description: ymlSource.description,
            attribution: ymlSource.attribution,
            center: ymlSource.center,
            defaultZoom: ymlSource.defaultZoom,
            minZoom: ymlSource.minZoom,
            maxZoom: ymlSource.maxZoom,
            layers: ymlLayers,
            origin: .yml)
    }

    // MARK: - Private

    private let name: String
    private let description: String
    private let attribution: String

    private let _center: [Double]?
    private var center: Coordinate3D {
        guard let center = _center, center.count >= 2 else {
            return Coordinate3D(latitude: 0.0, longitude: 0.0)
        }

        return Coordinate3D(latitude: center[1], longitude: center[0])
    }

    private var defaultZoom: Int {
        guard let center = _center, center.count >= 3 else { return 14 }

        return Int(center[2])
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.attribution = try container.decodeIfPresent(String.self, forKey: .attribution) ?? ""
        self._center = try container.decodeIfPresent([Double].self, forKey: ._center)
        self.minZoom = try container.decodeIfPresent(Int.self, forKey: .minZoom) ?? 0
        self.maxZoom = try container.decodeIfPresent(Int.self, forKey: .maxZoom) ?? 20
        self.layers = try container.decodeIfPresent([MapnikYMLLayer].self, forKey: .layers) ?? []
    }

}

// MARK: - MapnikYMLLayer

private struct MapnikYMLLayer: Decodable {

    let id: String
    let description: String?
    let srs: String?
    let fields: [String: String]?
    let datasource: MapnikYMLDatasource

    private let properties: MapnikYMLProperties?

    var bufferSize: Int {
        properties?.bufferSize ?? 0
    }

    var asPostgisLayer: PostgisLayer {
        let projection = MapnikSRS.projection(from: srs ?? "")

        return PostgisLayer(
            id: id,
            description: description,
            fields: fields ?? [:],
            properties: .init(bufferSize: bufferSize),
            datasource: datasource.asPostgisDatasource(layerProjection: projection))
    }

    enum CodingKeys: String, CodingKey {

        case id, description, srs, properties, fields

        case datasource = "Datasource"

    }

    private struct MapnikYMLProperties: Decodable {

        let bufferSize: Int?

        enum CodingKeys: String, CodingKey {

            case bufferSize = "buffer-size"

        }

    }

}

// MARK: - MapnikYMLDatasource

private struct MapnikYMLDatasource: Decodable {

    let user: String
    let password: String?
    let host: String
    let port: Int?

    let databaseName: String
    let geometryField: String?

    let extent: String?
    let srid: String?
    let type: String
    let sql: String

    func asPostgisDatasource(layerProjection: Projection) -> PostgisDatasource {
        var projection = layerProjection
        if let srid, let srid = Int(srid), srid > 0 {
            projection = Projection(srid: srid) ?? layerProjection
        }

        var boundingBox: BoundingBox?
        if let extent {
            let components = extent.components(separatedBy: ",").compactMap(\.toDouble)
            if components.count == 4 {
                boundingBox = BoundingBox(
                    southWest: Coordinate3D(x: components[0], y: components[1], projection: projection),
                    northEast: Coordinate3D(x: components[2], y: components[3], projection: projection))
            }
        }

        return PostgisDatasource(
            user: user,
            password: password ?? "",
            host: host,
            port: port ?? 5432,
            databaseName: databaseName,
            geometryField: geometryField?.nilIfEmpty,
            boundingBox: boundingBox,
            srid: projection,
            type: type,
            sql: sql)
    }

    enum CodingKeys: String, CodingKey {

        case user, password, host, port

        case databaseName = "dbname"
        case geometryField = "geometry_field"

        case extent, srid, type
        case sql = "table"

    }

}
