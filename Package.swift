// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PhemyNative",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // System library target wrapping the Rust static library
        .systemLibrary(
            name: "CPhemyCore",
            path: "Sources/CPhemyCore"
        ),
        .executableTarget(
            name: "PhemyNative",
            dependencies: ["CPhemyCore"],
            path: "Sources/PhemyNative",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", ".",  // libphemy_core.dylib in project root
                ]),
                .linkedLibrary("phemy_core"),
                .linkedLibrary("c++"),  // whisper.cpp / llama.cpp need C++ stdlib
                // System frameworks needed by Rust dependencies
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Accelerate"),           // ggml BLAS/vDSP
                .linkedFramework("Carbon"),               // enigo keyboard input source
                .linkedFramework("Metal"),                // llama.cpp Metal GPU
                .linkedFramework("MetalKit"),             // llama.cpp Metal
                .linkedFramework("MetalPerformanceShaders"),
                .linkedFramework("Foundation"),
            ]
        )
    ]
)
