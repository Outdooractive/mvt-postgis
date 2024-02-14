import Foundation
import GISTools
import SwiftyXMLParser

/// Loads the Postgis configuration from a Mapnik XML source file.
struct MapnikXMLSource {

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
        let xmlParser = XML.parse(data)

        var name = ""
        var description = ""
        var attribution = ""
        var fields: [String: [String: String]] = [:]
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
            case "name": name = value
            case "description": description = value
            case "attribution": attribution = value
            case "minzoom": minZoom = Int(value) ?? 0
            case "maxzoom": maxZoom = Int(value) ?? 20
            case "json": fields = MapnikXMLSource.parseFields(from: value)
            case "center":
                let components = value.split(separator: ",").compactMap({ Double($0) })
                guard components.count == 3 else { return }
                center = Coordinate3D(latitude: components[1], longitude: components[0])
                defaultZoom = Int(components[2])
            default: return
            }
        })

        guard name.isNotEmpty, fields.isNotEmpty else {
            throw MVTPostgisError.xmlError(message: "Missing name parameter")
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
            var geometryTable = ""
            var keyField = ""
            var keyFieldAsAttribute = ""

            var extent = ""
            var srid = ""
            var type = ""
            var maxSize = 0
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
                case "geometry_table": geometryTable = value
                case "key_field": keyField = value
                case "key_field_as_attribute": keyFieldAsAttribute = value
                case "extent": extent = value
                case "srid": srid = value
                case "type": type = value
                case "max_size": maxSize = value.toInt ?? 512
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

            let layerFields = fields[name] ?? [:]

            let datasource = PostgisDatasource(
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
            let layer = PostgisLayer(
                id: name,
                description: "",
                srs: srs,
                fields: layerFields,
                datasource: datasource,
                bufferSize: bufferSize)
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

}
