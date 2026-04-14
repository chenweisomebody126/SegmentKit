// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SegmentKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SegmentKit",
            targets: ["SegmentKit"]
        ),
    ],
    targets: [
        // 预编译的 XCFramework（通过 GitHub Release 分发）
        .binaryTarget(
            name: "SegmentKit",
            url: "https://github.com/chenweisomebody126/SegmentKit/releases/download/v0.4.1/SegmentKit.xcframework.zip",
            checksum: "f5f2c0c5b88e6b33af95208cd48821fe3ae07af59a214973a5e230f0b4a5e826"
        ),
    ]
)
