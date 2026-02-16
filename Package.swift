// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KordNative",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // System library target wrapping the Rust static library
        .systemLibrary(
            name: "CKordCore",
            path: "Sources/CKordCore"
        ),
        .executableTarget(
            name: "KordNative",
            dependencies: ["CKordCore"],
            path: "Sources/KordNative",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", ".",  // libkord_core.dylib in project root
                ]),
                .linkedLibrary("kord_core"),
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
