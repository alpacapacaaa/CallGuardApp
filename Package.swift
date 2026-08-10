// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CallGuard",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        // G10 운영자 승인(2026-08-11): 옵트인 세션 저장(P4-T4, AGENTS.md §4 확정 스택 "GRDB(SQLite) + 필드 암호화").
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
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
        .target(
            name: "SessionStore",
            dependencies: ["Session", "Detection", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "CallGuardApp",
            dependencies: [
                "Capture", "Session", "Preprocess", "STT",
                "Detection", "AlertPolicy", "CallGuardUI", "SessionStore",
            ]
        ),
        // P1-T2 스파이크: SCK 시스템 오디오 전용 캡처 → WAV 저장 CLI 데모.
        .executableTarget(
            name: "CaptureDemo",
            dependencies: ["Capture"]
        ),
        // 테스트 레인 (AGENTS.md §7, P0-T2): fast = 단위·룰·정책, slow = STT 통합·E2E·부하·페이싱.
        // 레인 분리는 타깃으로 강제 — swift test CLI에 태그 필터 없음(P0-T2 실증).
        // 후속 `--filter <Feature>Tests` DoD 호환을 위해 클래스명은 레인 접미사 없이 짓는다.
        // TestSupport: 레인 공용 합성 픽스처 빌더(G5 — 커밋 픽스처는 합성만).
        .target(name: "TestSupport", path: "Tests/TestSupport"),
        .testTarget(
            name: "CallGuardFastTests",
            dependencies: ["Capture", "Session", "Preprocess", "Detection", "SessionStore", "TestSupport"]
        ),
        .testTarget(
            name: "CallGuardSlowTests",
            dependencies: ["Capture", "TestSupport"]
        ),
    ]
)
