[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOutdooractive%2Fmvt-postgis%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Outdooractive/mvt-postgis)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOutdooractive%2Fmvt-postgis%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Outdooractive/mvt-postgis)

# MVTPostgis

Creates vector tiles from Postgis databases.

## Installation with Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/mvt-postgis", from: "1.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "MVTPostgis", package: "mvt-postgis"),
    ]),
]
```

## Features

TODO

## Usage

TODO

## Contributing

Please create an issue or open a pull request with a fix

## TODOs and future improvements

- Restart queries after timeout
- Explore ST_AsMVTGeom
- Define a JSON source format
- Documentation (!)
- Tests

## Links

- Libraries
    - https://github.com/Outdooractive/gis-tools
    - https://github.com/Outdooractive/mvt-tools

- Mapnik Postgis documentation:
    - https://github.com/mapnik/mapnik/wiki/PostGIS
    - https://github.com/mapnik/mapnik/wiki/OptimizeRenderingWithPostGIS

- Mapnik files:
    - https://github.com/mapnik/mapnik/blob/master/test/unit/datasource/postgis.cpp
    - https://github.com/mapnik/mapnik/blob/master/plugins/input/postgis/postgis_datasource.cpp

- Other:
    - https://github.com/plarson/fluent-postgis
    - https://github.com/koher/swift-image
    - https://github.com/t-ae/swim
    - https://github.com/GEOSwift/GEOSwift

## License

MIT

## Author

Thomas Rasch, Outdooractive
