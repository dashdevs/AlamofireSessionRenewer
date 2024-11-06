// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlamofireSessionRenewer",
    platforms: [.macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "AlamofireSessionRenewer", targets: ["AlamofireSessionRenewer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.4.3"))
    ],
    targets: [
        .target(name: "AlamofireSessionRenewer", dependencies: ["Alamofire"]),
        .testTarget( name: "AlamofireSessionRenewerTests", dependencies: ["AlamofireSessionRenewer"]),
    ],
    swiftLanguageVersions: [.v5]
)
