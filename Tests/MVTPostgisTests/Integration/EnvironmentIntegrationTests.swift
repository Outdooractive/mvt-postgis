import Foundation
import GISTools
@testable import MVTPostgis
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct EnvironmentIntegrationTests {

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    @Test(.timeLimit(.minutes(2)))
    func sessionSettingsDoNotChangeDecoding() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "settings",
                table: "features",
                fields: [
                    "id": "",
                    "name": "",
                    "kind": "",
                    "geom": "",
                    "time_zone": "",
                    "date_style": "",
                    "interval_style": "",
                    "float_digits": "",
                ],
                srid: .epsg4326,
                sql: """
                (SELECT id, name, kind, geom,
                        set_config('TimeZone', 'Europe/Berlin', false) AS time_zone,
                        set_config('DateStyle', 'German', false) AS date_style,
                        set_config('IntervalStyle', 'sql_standard', false) AS interval_style,
                        set_config('extra_float_digits', '3', false) AS float_digits
                 FROM "\(fixture.schema)".features
                 WHERE id = 1) AS data
                """)

            let postgis = try MVTPostgis(
                source: fixture.source(layers: [layer]),
                configuration: MVTPostgisConfiguration(
                    clipping: { _, _ in .none }))
            do {
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "settings").first)

                #expect(feature.geometry is Point)
                #expect(feature.properties["time_zone"] as? String == "Europe/Berlin")
                #expect((feature.properties["date_style"] as? String)?.hasPrefix("German") == true)
                #expect(feature.properties["interval_style"] as? String == "sql_standard")
                #expect(feature.properties["float_digits"] as? String == "3")

                await postgis.shutdown()
            }
            catch {
                await postgis.shutdown()
                throw error
            }
        }
    }

}
