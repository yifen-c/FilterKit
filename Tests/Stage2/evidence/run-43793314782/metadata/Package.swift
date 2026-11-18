// swift-tools-version:5.7
//
// Package.swift — Stage 2.1 离线草稿（未在 Apple 工具链验证）。
//
// 用途：为 macOS runner 提供一个不依赖 Xcode 工程文件的编译入口，先编译
// Models / Adapters / Core 非界面层并跑 Models Codable 往返测试；UI App target
// 待 SwiftUI/UIKit 选型（子规格 B4）与 Xcode 工程补齐后再接入。
//
// 注意：tools-version、Deployment Target、Theos/Swift 工具链配置均为待确认项
// （Stage-2.1 子规格 §14 B1/B2/B5）；本文件不得视为已可构建。

import PackageDescription

let package = Package(
    name: "FilterKit",
    products: [
        // 供 Xcode App target 链接的本地库产品；非界面层编译路径不变。
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Adapters", targets: ["Adapters"]),
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        // 公共模型：无路线依赖
        .target(
            name: "Models",
            path: "Models"
        ),
        // 双路线 Adapter：依赖 Models；RootHide / Rootless 独立编译、互不引用
        .target(
            name: "Adapters",
            dependencies: ["Models"],
            path: "Adapters",
            sources: [
                "ElleKitAdapter.swift",
                "RootHide/RootHideAdapter.swift",
                "Rootless/RootlessAdapter.swift"
            ]
        ),
        // 共享核心：依赖 Models 与 Adapters 协议
        .target(
            name: "Core",
            dependencies: ["Models", "Adapters"],
            path: "Core",
            exclude: [
                "README.md",
                "Environment/.gitkeep",
                "OwnershipResolver/.gitkeep",
                "PathResolver/.gitkeep",
                "PlistParser/.gitkeep",
                "PluginPairing/.gitkeep",
                "PluginScanner/.gitkeep",
                "ReportExporter/.gitkeep"
            ],
            sources: [
                "CoreServices.swift",
                "Environment/EnvironmentSnapshot.swift",
                "Environment/VersionParser.swift",
                "Environment/EnvironmentDetector.swift"
            ]
        ),
        // 骨架阶段模型单测（Codable 往返 / 枚举口径）；2.2 接入 Stage 1 夹具回归
        .testTarget(
            name: "Stage2Tests",
            dependencies: ["Models", "Adapters", "Core"],
            path: "Tests/Stage2",
            exclude: [
                "evidence",
                "README.md",
                "repo-boundary.md",
                "2.1-bootstrap-acceptance.md",
                "Stage-2.1-CI-Acceptance.md",
                "Stage-2.1-Final-Acceptance.md"
            ],
            sources: [
                "ModelsCodableTests.swift",
                "EnvironmentDetectionTests.swift"
            ]
        )
    ]
)
