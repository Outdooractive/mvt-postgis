// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "mvt-postgis",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "MVTPostgis", targets: ["MVTPostgis"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Outdooractive/mvt-tools", from: "1.8.5"),
        .package(url: "https://github.com/Outdooractive/gis-tools", from: "1.8.5"),
        .package(url: "https://github.com/Outdooractive/PostgresConnectionPool.git", from: "0.8.1"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.22.1"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.1"),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", from: "5.6.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.3"),
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
