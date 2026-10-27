// swift-tools-version:6.3

import PackageDescription

let package = Package(
    name: "mvt-postgis",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "MVTPostgis", targets: ["MVTPostgis"]),
    ],
    dependencies: [
        // mvt-tools 3.0.0 still restricts gis-tools to the 2.x line. Pin main
        // until a tagged mvt-tools release uses the gis-tools 3.0 beta line.
        .package(url: "https://github.com/Outdooractive/mvt-tools", revision: "43e51601083fc91cdbcb1b6a1949075c17dc9e1c", traits: ["EnableMLT"]),
        .package(url: "https://github.com/Outdooractive/gis-tools", exact: "3.0.0-beta.5"),
        .package(url: "https://github.com/Outdooractive/PostgresConnectionPool.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.16.2"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.3.1"),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", from: "5.6.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.2"),
    ],
    targets: [
        .target(
            name: "MVTPostgis",
            dependencies: [
                .product(name: "GISTools", package: "gis-tools"),
                .product(name: "MVTTools", package: "mvt-tools"),
                .product(name: "PostgresConnectionPool", package: "PostgresConnectionPool"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftyXMLParser", package: "SwiftyXMLParser"),
                .product(name: "Yams", package: "Yams"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]),
        .testTarget(
            name: "MVTPostgisTests",
            dependencies: [
                "MVTPostgis",
                .product(name: "PostgresConnectionPool", package: "PostgresConnectionPool"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]),
    ])
