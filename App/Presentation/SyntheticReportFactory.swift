//
//  SyntheticReportFactory.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  0.1-C 无真机快照接入；本工厂只产出固定合成信封用于界面预览与空态核对。
//  合成报告不代表真实 RootHide 文件权限、真实加载或扫描结果；真机快照 →
//  `ReportBuildInput` → 信封的在线接入属 0.1-D 探针阶段。
//

import Foundation
import Models

public enum SyntheticReportFactory {

    /// 预览信封：覆盖 paired/valid、parse_failed、not_parsed、missing dylib 等
    /// 展示分支；字段值为演示数据。
    public static func previewEnvelope() -> ReportEnvelope {
        let environment = JailbreakEnvironment(
            jailbreakType: .roothide,
            ellekitImplementation: "ellekit",
            ellekitVersion: "1.0.0",
            profileId: "roothide-preview",
            jbroot: "/private/var/jb",
            jbrand: "preview",
            iosVersion: "17.0.2",
            architecture: "arm64e",
            evidenceLevel: .partial,
            pathEvidence: PathEvidence(
                tweakInject: "/private/var/jb/Library/TweakInject",
                dynamicLibraries: "/private/var/jb/Library/Frameworks",
                jbrootCandidateDetails: [
                    JBRootCandidate(path: "/private/var/jb", source: "scan", route: "roothide",
                                     status: "valid")
                ],
                jbrootCandidates: ["/private/var/jb"]
            )
        )

        let pairedValid = Plugin(
            pluginID: "com.example.preview-tweak",
            name: "Preview Tweak",
            version: "1.2.0",
            dylibPath: "/private/var/jb/Library/MobileSubstrate/DynamicLibraries/PreviewTweak.dylib",
            plistPath: "/private/var/jb/Library/MobileSubstrate/DynamicLibraries/PreviewTweak.plist",
            pairing: .paired,
            source: .dpkgSileo,
            ownership: Ownership(sourceType: .dpkgSileo, packageID: "com.example.preview-tweak",
                                 confidence: .exactRecord, writablePolicy: .readOnly),
            ownershipDetails: OwnershipDetails(conflicts: [], notes: ["synthetic preview entry"]),
            filter: FilterRule(bundles: ["com.example.app"], classes: ["ExampleHook"],
                                executables: ["ExampleApp"]),
            loadCategory: .tweak,
            installed: true,
            configured: true,
            loaded: .unknown,
            validation: ValidationReport(status: "valid"),
            profileId: "roothide-preview",
            evidence: EvidenceBlock(sourceStages: ["enumeration", "pairing", "parsing"],
                                    evidenceType: "synthetic", evidenceLevel: .partial)
        )

        let parseFailed = Plugin(
            pluginID: "com.example.broken-plist",
            name: "Broken Plist",
            version: nil,
            dylibPath: "/private/var/jb/Library/MobileSubstrate/DynamicLibraries/Broken.dylib",
            plistPath: "/private/var/jb/Library/MobileSubstrate/DynamicLibraries/Broken.plist",
            pairing: .paired,
            source: .manual,
            ownership: Ownership(sourceType: .manual, confidence: .heuristic,
                                 writablePolicy: .readOnly),
            filter: nil,
            loadCategory: .tweak,
            installed: true,
            configured: false,
            loaded: .unknown,
            validation: ValidationReport(status: "parse_failed",
                                         warnings: ["plist root is not a dictionary"]),
            profileId: "roothide-preview",
            evidence: EvidenceBlock(sourceStages: ["enumeration", "pairing"],
                                     evidenceType: "synthetic", evidenceLevel: .unverified)
        )

        let missingDylib = Plugin(
            pluginID: "com.example.orphan-plist",
            name: "Orphan Plist",
            version: "0.9.0",
            dylibPath: nil,
            plistPath: "/private/var/jb/Library/MobileSubstrate/DynamicLibraries/Orphan.plist",
            pairing: .orphanPlist,
            source: .unknown,
            ownership: Ownership(sourceType: .unknown, confidence: .unknown,
                                 writablePolicy: .readOnly),
            filter: nil,
            loadCategory: .unknown,
            installed: nil,
            configured: false,
            loaded: .unknown,
            validation: ValidationReport(status: "not_parsed"),
            profileId: "roothide-preview",
            evidence: EvidenceBlock(sourceStages: ["enumeration"],
                                    evidenceType: "synthetic", evidenceLevel: .unverified)
        )

        return ReportEnvelope(
            schemaVersion: "0.1.0",
            generatorVersion: "0.1.0-preview",
            profile: ProfileRef(id: "roothide-preview", route: "roothide"),
            generatedAt: nil,
            environment: environment,
            plugins: [pairedValid, parseFailed, missingDylib],
            unknownItems: [
                UnknownItem(path: "/private/var/jb/Library/MobileSubstrate/DynamicLibraries/Stray.plist",
                            base: "Stray.plist",
                            reason: "orphan entry without paired dylib",
                            sourceStage: "enumeration",
                            detail: ["category": "plist"])
            ],
            warnings: [
                ReportWarning(code: "PREVIEW-001",
                              message: "Synthetic preview report; not a device scan.",
                              sourceStage: "gui-preview")
            ]
        )
    }

    /// 空信封：用于空态界面核对；计数全 0、环境 Unknown。
    public static func emptyEnvelope() -> ReportEnvelope {
        ReportEnvelope(
            schemaVersion: "0.1.0",
            generatorVersion: "0.1.0",
            profile: ProfileRef(id: "unknown-profile", route: "unknown"),
            environment: JailbreakEnvironment()
        )
    }
}
