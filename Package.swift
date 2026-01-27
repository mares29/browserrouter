// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrowserRouter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BrowserRouter",
            path: "BrowserRouter",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "BrowserRouterTests",
            dependencies: ["BrowserRouter"],
            path: "BrowserRouterTests"
        )
    ]
)
