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
            url: "https://github.com/chenweisomebody126/SegmentKit/releases/download/v1.1.0/SegmentKit.xcframework.zip",
            checksum: "e6ab4fb857a27248a2bb9536900a5891139252364208d35528917d00a7c839d0"
        ),
    ]
)
