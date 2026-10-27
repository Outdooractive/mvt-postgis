import Foundation
import GISTools
import SwiftyXMLParser

/// Loads the Postgis configuration from a Mapnik XML source file.
enum MapnikXMLSource {

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
        let xmlParser = XML.parse(data)

        var name = ""
        var description = ""
        var attribution = ""
        var layerFields: [String: [String: String]] = [:]
        var layerDescriptions: [String: String] = [:]
        var center = Coordinate3D.zero
        var defaultZoom = 13
        var minZoom = 0
        var maxZoom = 20

        var layers: [PostgisLayer] = []

        let mapSRS = xmlParser.Map.attributes["srs"] ?? ""

        xmlParser.Map.Parameters.Parameter.all?.forEach({ element in
            guard let nameAttribute = element.attributes["name"],
                  let value = element.text ?? element.CDATA?.asUTF8EncodedString
            else { return }

            switch nameAttribute {
            case "name":
                name = value

            case "description":
                description = value

            case "attribution":
                attribution = value

            case "minzoom":
                minZoom = Int(value) ?? 0

            case "maxzoom":
                maxZoom = Int(value) ?? 20

            case "json":
                layerFields = MapnikXMLSource.parseFields(from: value)
                layerDescriptions = MapnikXMLSource.parseDescriptions(from: value)

            case "center":
                let components = value.split(separator: ",").compactMap({ Double($0) })
                guard components.count == 3 else { return }

                center = Coordinate3D(latitude: components[1], longitude: components[0])
                defaultZoom = Int(components[2])

            default:
                return
            }
        })

        guard name.isNotEmpty else {
            throw MVTPostgisError.xmlError(message: "Missing 'name' parameter")
        }

        for element in xmlParser.Map.Layer.all ?? [] {
            guard let name = element.attributes["name"] else {
                throw MVTPostgisError.xmlError(message: "Layer without a name")
            }

            if layerAllowlist.isNotEmpty,
               layerAllowlist.contains(name) == false
            {
                continue
            }

            let srs = element.attributes["srs"] ?? mapSRS
            let bufferSize = element.attributes["buffer-size"]?.toInt ?? 0

            guard let datasourceElement = element.childElements.first(where: { $0.name == "Datasource" }) else {
                throw MVTPostgisError.xmlError(message: "Layer '\(name)' is missing a Datasource")
            }

            var user = ""
            var password = ""
            var host = ""
            var port = 5432

            var databaseName = ""
            var geometryField = ""

            var extent = ""
            var srid = ""
            var type = ""
            var sql = ""

            for element in datasourceElement.childElements {
                guard let nameAttribute = element.attributes["name"],
                      let value = element.text ?? element.CDATA?.asUTF8EncodedString
                else { continue }

                switch nameAttribute {
                case "user": user = value
                case "password": password = value
                case "host": host = value
                case "port": port = value.toInt ?? 5432
                case "dbname": databaseName = value
                case "geometry_field": geometryField = value
                case "extent": extent = value
                case "srid": srid = value
                case "type": type = value
                case "table": sql = value
                default: continue
                }
            }

            guard user.isNotEmpty,
                  host.isNotEmpty,
                  databaseName.isNotEmpty,
                  type.isNotEmpty,
                  sql.isNotEmpty
            else {
                throw MVTPostgisError.xmlError(message: "Layer '\(name)' has incomplete datasource parameters")
            }

            let layerFields = layerFields[name] ?? [:]

            let layerProjection = MapnikSRS.projection(from: srs)

            var datasourceProjection = layerProjection
            if let srid = Int(srid), srid > 0 {
                datasourceProjection = Projection(srid: srid) ?? layerProjection
            }

            var datasourceBoundingBox: BoundingBox?
            let components = extent.components(separatedBy: ",").compactMap(\.toDouble)
            if components.count == 4 {
                datasourceBoundingBox = BoundingBox(
                    southWest: Coordinate3D(x: components[0], y: components[1], projection: datasourceProjection),
                    northEast: Coordinate3D(x: components[2], y: components[3], projection: datasourceProjection))
            }

            let datasource = PostgisDatasource(
                user: user,
                password: password,
                host: host,
                port: port,
                databaseName: databaseName,
                geometryField: geometryField.nilIfEmpty,
                boundingBox: datasourceBoundingBox,
                srid: datasourceProjection,
                type: type,
                sql: sql)
            let layer = PostgisLayer(
                id: name,
                description: layerDescriptions[name],
                fields: layerFields,
                properties: .init(bufferSize: bufferSize),
                datasource: datasource)
            layers.append(layer)
        }

        guard layers.isNotEmpty else {
            throw MVTPostgisError.xmlError(message: "Datasource without layers")
        }

        return PostgisSource(
            name: name,
            description: description,
            attribution: attribution,
            center: center,
            defaultZoom: defaultZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            layers: layers,
            origin: .xml)
    }

    // MARK: -

    private static func parseFields(from jsonString: String) -> [String: [String: String]] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let layers = json["vector_layers"] as? [[String: Any]]
        else { return [:] }

        var fields: [String: [String: String]] = [:]

        for layer in layers {
            guard let name = layer["id"] as? String,
                  let layerFields = layer["fields"] as? [String: String]
            else { continue }

            fields[name] = layerFields
        }

        return fields
    }

    private static func parseDescriptions(from jsonString: String) -> [String: String] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let layers = json["vector_layers"] as? [[String: Any]]
        else { return [:] }

        return layers.reduce(into: [:]) { partialResult, layer in
            if let description = layer["description"] as? String,
               let name = layer["id"] as? String
            {
                partialResult[name] = description
            }
        }
    }

}
