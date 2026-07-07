import Foundation

/// The output format for tile encoding.
public enum TileOutputFormat: String, Sendable, CaseIterable {

    /// Mapbox Vector Tile (MVT) — the standard vector tile format.
    case mvt
    /// MapLibre Tile (MLT) — the MapLibre vector tile format.
    case mlt

}
