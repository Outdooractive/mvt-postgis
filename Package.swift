// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "mvt-postgis",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "MVTPostgis", targets: ["MVTPostgis"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Outdooractive/mvt-tools", from: "1.10.0"),
        .package(url: "https://github.com/Outdooractive/gis-tools", from: "1.13.2"),
        .package(url: "https://github.com/Outdooractive/PostgresConnectionPool.git", from: "0.8.1"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.26.2"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.1"),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", from: "5.6.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.4.0"),
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
            ]),
        .testTarget(
            name: "MVTPostgisTests",
            dependencies: ["MVTPostgis"])
    ]
)
