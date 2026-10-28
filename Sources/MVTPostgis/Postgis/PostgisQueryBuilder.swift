import Foundation
import GISTools

/// Builds the SQL query for one PostGIS layer.
///
/// The builder is internal so the generated SQL can be unit-tested without a
/// live PostGIS database.
struct PostgisQueryBuilder {

    private static let metersPerDegree = GISTool.earthCircumference / 360.0

    let layer: PostgisLayer
    let sql: String
    let envelope: String
    let simplificationTolerance: Double
    let clipping: MVTClippingOption
    let simplification: MVTSimplificationOption
    let validation: MVTMakeValidOption

    init(
        layer: PostgisLayer,
        sql: String? = nil,
        envelope: String,
        simplificationTolerance: Double,
        clipping: MVTClippingOption,
        simplification: MVTSimplificationOption,
        validation: MVTMakeValidOption,
    ) {
        self.layer = layer
        self.sql = sql ?? layer.datasource.sql
        self.envelope = envelope
        self.simplificationTolerance = simplificationTolerance
        self.clipping = clipping
        self.simplification = simplification
        self.validation = validation
    }

    /// Whether geometry simplification has to be performed locally after
    /// loading the features.
    var usesLocalSimplification: Bool {
        if case .local = simplification {
            return true
        }
        return false
    }

    /// The complete `SELECT` statement for the layer.
    var query: String {
        let geometryField = layer.datasource.geometryField?.nilIfEmpty ?? "geometry"
        let quotedGeometryField = Self.quotedIdentifier(geometryField)

        var columns = layer.fields
            .keys
            .filter { $0.isNotEmpty && $0 != geometryField }
            .sorted()
            .map(Self.quotedIdentifier)

        var geometryExpression = "ST_AsBinary("

        switch validation {
        case .none:
            break
        case .default, .linework, .structure:
            geometryExpression.append("ST_MakeValid(")
        }

        switch simplification {
        case .meters, .postgis:
            geometryExpression.append("ST_Simplify(")
        case .local, .none:
            break
        }

        if case .postgis = clipping {
            geometryExpression.append("ST_ClipByBox2D(")
        }

        geometryExpression.append("ST_Force2D(")
        geometryExpression.append(quotedGeometryField)
        geometryExpression.append("::geometry)")

        if case .postgis = clipping {
            geometryExpression.append(",\(envelope))")
        }

        switch simplification {
        case let .postgis(preserveCollapsed):
            geometryExpression.append(",\(toleranceInLayerUnits(simplificationTolerance))")
            if preserveCollapsed {
                geometryExpression.append(",true")
            }
            geometryExpression.append(")")

        case let .meters(meters, preserveCollapsed):
            geometryExpression.append(",\(toleranceInLayerUnits(meters))")
            if preserveCollapsed {
                geometryExpression.append(",true")
            }
            geometryExpression.append(")")

        case .local, .none:
            break
        }

        switch validation {
        case .none:
            break
        case .default, .linework:
            geometryExpression.append(")")
        case let .structure(keepCollapsed):
            geometryExpression.append(", 'method=structure keepcollapsed=\(keepCollapsed)')")
        }

        geometryExpression.append(")")
        geometryExpression.append(" AS \(quotedGeometryField)")
        columns.append(geometryExpression)

        return "SELECT \(columns.joined(separator: ",")) FROM \(sql)"
    }

    /// Quotes a PostgreSQL identifier, including embedded double quotes.
    static func quotedIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacing("\"", with: "\"\""))\""
    }

    /// Converts a metre tolerance into the layer's PostGIS coordinate units.
    ///
    /// EPSG:3857 uses metres. EPSG:4326 uses degrees, so the tolerance is
    /// converted with the spherical metres-per-degree constant. This is an
    /// approximation for longitude at high latitudes, but avoids treating a
    /// metre value as a degree value.
    private func toleranceInLayerUnits(_ meters: Double) -> Double {
        guard layer.datasource.srid == .epsg4326 else { return meters }

        return meters / Self.metersPerDegree
    }

}
