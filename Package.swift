// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mochi",
    platforms: [.macOS(.v13)],
    targets: [
        // On Windows: Direct2D / DirectWrite drawing (shapes, gradients, colour emoji) for AppKitLite.
        .target(
            name: "LiteCanvas",
            path: "Sources/LiteCanvas",
            cxxSettings: [
                // Newer Visual Studio C++ libraries refuse clang versions older than the one they were tested
                // with; the little C++ here only uses the basics, so any Swift toolchain's clang is fine.
                .define("_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH", .when(platforms: [.windows])),
            ],
            linkerSettings: [
                .linkedLibrary("d2d1", .when(platforms: [.windows])),
                .linkedLibrary("dwrite", .when(platforms: [.windows])),
                .linkedLibrary("windowscodecs", .when(platforms: [.windows])),
                .linkedLibrary("ole32", .when(platforms: [.windows])),
            ]
        ),
        // On Windows: a small stand-in for the parts of AppKit and Combine that Mochi uses (windows, screens,
        // the cursor, Bézier drawing, @Published), built on Win32. On macOS it compiles to nothing.
        .target(
            name: "AppKitLite",
            dependencies: [.target(name: "LiteCanvas", condition: .when(platforms: [.windows]))],
            path: "Sources/AppKitLite",
            linkerSettings: [
                .linkedLibrary("user32", .when(platforms: [.windows])),
                .linkedLibrary("gdi32", .when(platforms: [.windows])),
                .linkedLibrary("shell32", .when(platforms: [.windows])),
                .linkedLibrary("shcore", .when(platforms: [.windows])),
                .linkedLibrary("dwmapi", .when(platforms: [.windows])),
                .linkedLibrary("powrprof", .when(platforms: [.windows])),
            ]
        ),
        .executableTarget(
            name: "Mochi",
            dependencies: [.target(name: "AppKitLite", condition: .when(platforms: [.windows]))],
            path: "Sources/Mochi",
            linkerSettings: [
                // Embed Info.plist in the binary, so `swift run` has the same identity (and saved data)
                // as the built Mochi.app, and macOS can show the calendar permission prompt.
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                              "-Xlinker", "\(Context.packageDirectory)/Support/Info.plist"], .when(platforms: [.macOS])),
                .linkedLibrary("advapi32", .when(platforms: [.windows])),
                .linkedLibrary("ws2_32", .when(platforms: [.windows])),
                .linkedLibrary("powrprof", .when(platforms: [.windows])),
            ]
        )
    ]
)
