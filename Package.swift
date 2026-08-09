// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CallGuard",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        // AGENTS.md §4 데이터 흐름 = 모듈 의존 방향. UI→Capture 직접 참조 금지.
        .target(name: "Capture"),
        .target(name: "Session", dependencies: ["Capture"]),
        .target(name: "Preprocess", dependencies: ["Session"]),
        .target(name: "STT", dependencies: ["Preprocess"]),
        .target(name: "Detection", dependencies: ["STT"]),
        .target(name: "AlertPolicy", dependencies: ["Detection"]),
        .target(name: "CallGuardUI", dependencies: ["AlertPolicy"]),
        .target(name: "SessionStore", dependencies: ["Session", "Detection"]),
        .executableTarget(
            name: "CallGuardApp",
            dependencies: [
                "Capture", "Session", "Preprocess", "STT",
                "Detection", "AlertPolicy", "CallGuardUI", "SessionStore",
            ]
        ),
    ]
)
