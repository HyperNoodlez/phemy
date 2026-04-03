import Foundation

extension Foundation.Bundle {
    /// Custom resource bundle accessor that works in both .app bundles and SwiftPM build directories.
    static let module: Bundle = {
        let bundleName = "PhemyNative_PhemyNative"

        let candidates = [
            // Inside .app bundle: Contents/Resources/
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName).bundle"),
            // Alongside executable (SwiftPM build output)
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
            // Alongside the binary directly
            Bundle(for: BundleFinder.self).bundleURL.appendingPathComponent("\(bundleName).bundle"),
        ]

        for candidate in candidates {
            if let bundle = Bundle(path: candidate.path) {
                return bundle
            }
        }

        fatalError("Unable to find resource bundle \(bundleName)")
    }()
}

private class BundleFinder {}
