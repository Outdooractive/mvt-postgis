import Foundation
import GISTools
import Logging
@testable import MVTPostgis
import Testing

struct PoolDistributorTests {

    @Test
    func poolDistributorShutdownClearsPools() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.shutdown()
        let infos = await distributor.poolInfos()
        #expect(infos.isEmpty)
    }

    @Test
    func poolInfosBeforeAnyConnectionIsEmpty() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        let infos = await distributor.poolInfos()
        #expect(infos.isEmpty)
    }

    @Test
    func closeIdleConnectionsOnEmptyDistributor() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.closeIdleConnections()
    }

    @Test
    func abortBatchOnEmptyDistributor() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.abortBatch(42)
    }

}
