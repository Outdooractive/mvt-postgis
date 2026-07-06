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
        .package(url: "https://github.com/Outdooractive/mvt-tools", from: "2.0.0"),
        .package(url: "https://github.com/Outdooractive/gis-tools", from: "2.0.0"),
        .package(url: "https://github.com/Outdooractive/PostgresConnectionPool.git", from: "0.8.1"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.26.2"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.1"),
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
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SwiftyXMLParser", package: "SwiftyXMLParser"),
                .product(name: "Yams", package: "Yams"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]),
        .testTarget(
            name: "MVTPostgisTests",
            dependencies: ["MVTPostgis"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ])
    ]
)
