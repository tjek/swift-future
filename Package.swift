// swift-tools-version:5.0
import Foundation
import PackageDescription

let package = Package(
  name: "Future",
  products: [
    .library(name: "Future", targets: ["Future"])
  ],
  targets: [
    .target(name: "Future", dependencies: []),
    .testTarget(name: "FutureTests", dependencies: ["Future"]),
  ]
)
