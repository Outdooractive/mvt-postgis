import GISTools
@testable import MVTPostgis
import Testing

struct MVTPostgisConfigurationTests {

    @Test
    func configurationDefaults() {
        let config = MVTPostgisConfiguration()
        #expect(config.applicationName == "MVTPostgis")
        #expect(config.connectTimeout == 5.0)
        #expect(config.queryTimeout == 10.0)
        #expect(config.tileTimeout == 60.0)
        #expect(config.poolSize == 10)
        #expect(config.maxIdleConnections == nil)
        #expect(config.trackRuntimes == false)
        #expect(config.featureMapping == nil)
    }

    @Test
    func configurationCustomValues() {
        let config = MVTPostgisConfiguration(
            applicationName: "Custom",
            connectTimeout: 3.0,
            queryTimeout: 30.0,
            tileTimeout: 120.0,
            poolSize: 5,
            maxIdleConnections: 3,
            trackRuntimes: true)
        #expect(config.applicationName == "Custom")
        #expect(config.connectTimeout == 3.0)
        #expect(config.queryTimeout == 30.0)
        #expect(config.tileTimeout == 120.0)
        #expect(config.poolSize == 5)
        #expect(config.maxIdleConnections == 3)
        #expect(config.trackRuntimes == true)
    }

    @Test
    func configurationClampsMinimumValues() {
        let config = MVTPostgisConfiguration(
            connectTimeout: 0.1,
            queryTimeout: 0.1,
            tileTimeout: 0.1,
            poolSize: 0)
        #expect(config.connectTimeout == 1.0)
        #expect(config.queryTimeout == 1.0)
        #expect(config.tileTimeout == 1.0)
        #expect(config.poolSize == 1)
    }

    @Test
    func configurationDisablesQueryTimeout() {
        let config = MVTPostgisConfiguration(queryTimeout: nil)
        #expect(config.queryTimeout == nil)
    }

    @Test
    func clippingOptionAllCases() {
        let _: MVTClippingOption = .none
        let _: MVTClippingOption = .postgis
        let _: MVTClippingOption = .local
    }

    @Test
    func simplificationOptionAllCases() {
        let _: MVTSimplificationOption = .none
        let _: MVTSimplificationOption = .local
        let _: MVTSimplificationOption = .postgis(preserveCollapsed: true)
        let _: MVTSimplificationOption = .postgis(preserveCollapsed: false)
        let _: MVTSimplificationOption = .meters(10.0, preserveCollapsed: true)
        let _: MVTSimplificationOption = .meters(10.0, preserveCollapsed: false)
    }

    @Test
    func validationOptionAllCases() {
        let _: MVTMakeValidOption = .none
        let _: MVTMakeValidOption = .default
        let _: MVTMakeValidOption = .linework
        let _: MVTMakeValidOption = .structure(keepCollapsed: true)
        let _: MVTMakeValidOption = .structure(keepCollapsed: false)
    }

    @Test
    func configurationClosures() {
        let clipBlock: @Sendable (Int, PostgisSource?) -> MVTClippingOption = { _, _ in .postgis }
        let simplBlock: @Sendable (Int, PostgisSource?) -> MVTSimplificationOption = { _, _ in .local }
        let validBlock: @Sendable (Int, PostgisSource?) -> MVTMakeValidOption = { _, _ in .linework }

        let config = MVTPostgisConfiguration(
            clipping: clipBlock,
            simplification: simplBlock,
            validation: validBlock)
        _ = config
    }

}

struct TileOutputFormatTests {

    @Test
    func allCases() {
        #expect(TileOutputFormat.allCases == [.mvt, .mlt])
    }

    @Test
    func rawValues() {
        #expect(TileOutputFormat.mvt.rawValue == "mvt")
        #expect(TileOutputFormat.mlt.rawValue == "mlt")
    }

    @Test
    func configurationClosuresAreInvoked() {
        let source = PostgisSource(name: "Closures", layers: [])
        let config = MVTPostgisConfiguration(
            clipping: { zoom, _ in zoom > 10 ? .local : .postgis },
            simplification: { zoom, _ in zoom > 10 ? .local : .postgis(preserveCollapsed: true) },
            validation: { zoom, _ in zoom > 10 ? .structure(keepCollapsed: true) : .none },
            featureMapping: { feature in
                var mapped = feature
                mapped.setProperty(true, for: "mapped")
                return mapped
            })

        if case .local = config.clipping(11, source) {
            // expected
        }
        else {
            Issue.record("Unexpected clipping closure result")
        }

        if case .local = config.simplification(11, source) {
            // expected
        }
        else {
            Issue.record("Unexpected simplification closure result")
        }

        if case .structure(true) = config.validation(11, source) {
            // expected
        }
        else {
            Issue.record("Unexpected validation closure result")
        }

        let mapped = config.featureMapping?(Feature(Point(Coordinate3D(latitude: 0, longitude: 0))))
        #expect(mapped?.properties["mapped"] as? Bool == true)
    }

}
