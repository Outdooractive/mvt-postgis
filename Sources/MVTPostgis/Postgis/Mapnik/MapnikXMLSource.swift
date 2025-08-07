import Foundation
import GISTools
import SwiftyXMLParser

/// Loads the Postgis configuration from a Mapnik XML source file.
struct MapnikXMLSource {

    static func load(
        from url: URL,
        layerAllowlist: [String]
    ) throws -> PostgisSource {
        let data = try Data(contentsOf: url)
        return try load(from: data, layerAllowlist: layerAllowlist)
    }

    static func load(
        from data: Data,
        layerAllowlist: [String]
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

        guard name.isNotEmpty, layerFields.isNotEmpty else {
            throw MVTPostgisError.xmlError(message: "Missing 'name' or 'json' parameter")
        }

        xmlParser.Map.Layer.all?.forEach({ element in
            guard let name = element.attributes["name"],
                  let srs = element.attributes["srs"],
                  let bufferSize = element.attributes["buffer-size"]?.toInt
            else {
                print("Missing attributes for Layer \(element.attributes)")
                return
            }

            if layerAllowlist.isNotEmpty,
               !layerAllowlist.contains(name)
            {
                return
            }

            guard let datasourceElement = element.childElements.first,
                  datasourceElement.name == "Datasource"
            else {
                print("Missing Datasource for Layer \(name)")
                return
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

            datasourceElement.childElements.forEach({ element in
                guard let nameAttribute = element.attributes["name"],
                      let value = element.text ?? element.CDATA?.asUTF8EncodedString
                else { return }

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
                default: return
                }
            })

            guard user.isNotEmpty,
                  password.isNotEmpty,
                  host.isNotEmpty,
                  databaseName.isNotEmpty,
                  type.isNotEmpty,
                  sql.isNotEmpty
            else {
                print("Missing datasource info in layer \(name)")
                return
            }

            let layerFields = layerFields[name] ?? [:]

            // Supported:
            // srs: +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs
            // srs: +proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0.0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs +over
            let layerProjection: Projection = switch srs.lowercased() {
            case "+proj=longlat +ellps=wgs84 +datum=wgs84 +no_defs": .epsg4326
            case "+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0.0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs +over": .epsg3857
            default: .noSRID
            }

            var datasourceProjection = layerProjection
            if let srid = Int(srid), srid > 0 {
                datasourceProjection = Projection(srid: srid) ?? layerProjection
            }

            var datasourceBoundingBox: BoundingBox?
            let components = extent.components(separatedBy: ",").compactMap({ $0.toDouble })
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
                geometryField: geometryField,
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
        })

        guard layers.isNotEmpty else {
            throw MVTPostgisError.xmlError(message: "Datasource without layers")
        }

        let source = PostgisSource(
            name: name,
            description: description,
            attribution: attribution,
            center: center,
            defaultZoom: defaultZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            layers: layers)

        return source
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
