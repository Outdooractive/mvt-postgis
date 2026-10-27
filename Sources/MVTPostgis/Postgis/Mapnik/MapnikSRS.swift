import GISTools

/// Converts the Mapnik `srs` strings commonly used by PostGIS datasources
/// into a ``Projection``.
enum MapnikSRS {

    static func projection(from srs: String) -> Projection {
        let tokens = Set(
            srs
                .lowercased()
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init))

        if tokens.contains("+proj=longlat"), tokens.contains("+datum=wgs84") {
            return .epsg4326
        }
        if tokens.contains("+proj=merc"),
           tokens.contains("+a=6378137"),
           tokens.contains("+b=6378137")
        {
            return .epsg3857
        }
        return .noSRID
    }

}
