// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BCMacScroll",
    platforms: [.macOS(.v13)],
    targets: [
        // Exposes the IOKit HID headers used to toggle mouse acceleration.
        .target(name: "CHIDSupport", path: "Sources/CHIDSupport"),
        .executableTarget(
            name: "BCMacScroll",
            dependencies: ["CHIDSupport"],
            path: "Sources/BCMacScroll",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
