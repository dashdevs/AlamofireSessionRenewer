// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlamofireSessionRenewer",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v12), .watchOS(.v4)],
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
    swiftLanguageModes: [.v6]
)
