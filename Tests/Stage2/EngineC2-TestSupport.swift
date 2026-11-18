//
//  EngineC2-TestSupport.swift
//  FilterKit Stage 2 — Engine-C2（A~C）测试共享桩与构造器（测试目标专用）
//
//  按 plist 路径回灌受控 Reader / Decoder 结果；Parser 计数包装委托真实
//  RootHide / Rootless 实现。桩只用于调用顺序、受控故障注入与计数核对；
//  真实解析行为一律由真实 Parser 产出，不以 Mock 成功结果冒充端到端验证。
//  不实例化 Adapter、不访问真实文件系统；桩类型不进生产目标。
//

import Foundation
@testable import Core
@testable import Models

/// C2 单条 plist 桩输入。
struct EngineC2PlistStub {
    /// 与配对记录 plist 侧证据路径对齐。
    let plistPath: String
    /// Reader 状态；`nil` 表示成功。
    var readStatus: PlistReadStatus?
    /// Decoder 成功回灌的根对象。
    var decodeRoot: Any?
    /// Decoder 是否返回 `parse_failed`。
    var decodeFailed: Bool
    /// 解码格式信号。
    var format: PropertyListSerialization.PropertyListFormat

    init(plistPath: String,
         readStatus: PlistReadStatus? = nil,
         decodeRoot: Any? = nil,
         decodeFailed: Bool = false,
         format: PropertyListSerialization.PropertyListFormat = .xml) {
        self.plistPath = plistPath
        self.readStatus = readStatus
        self.decodeRoot = decodeRoot
        self.decodeFailed = decodeFailed
        self.format = format
    }
}

/// 测试协调器：串联最近路径与 Reader / Decoder / 双 Parser 调用计数。
final class EngineC2Coordinator {
    var stubs: [EngineC2PlistStub]
    var lastPath: String?
    var readerCallCount = 0
    var decoderCallCount = 0
    var hideCallCount = 0
    var lessCallCount = 0

    init(stubs: [EngineC2PlistStub]) {
        self.stubs = stubs
    }

    func stub(for path: String?) -> EngineC2PlistStub? {
        guard let path else { return nil }
        return stubs.first { $0.plistPath == path }
    }
}

/// Reader 桩：按路径回灌受控读取状态；默认成功。
final class EngineC2StubReader: PlistDataReading {
    private let coordinator: EngineC2Coordinator

    init(_ coordinator: EngineC2Coordinator) {
        self.coordinator = coordinator
    }

    func read(path: String) -> PlistReadResult {
        coordinator.readerCallCount += 1
        coordinator.lastPath = path
        guard let stub = coordinator.stub(for: path),
              let status = stub.readStatus,
              status != .success else {
            return PlistReadResult(status: .success, data: Data([0x00]), path: path)
        }
        return PlistReadResult(status: status, data: nil, path: path)
    }
}

/// Decoder 桩：按路径回灌根对象或 `parse_failed`。
final class EngineC2StubDecoder: PlistDecoding {
    private let coordinator: EngineC2Coordinator

    init(_ coordinator: EngineC2Coordinator) {
        self.coordinator = coordinator
    }

    func decode(data: Data) -> PlistDecodeResult {
        coordinator.decoderCallCount += 1
        guard let stub = coordinator.stub(for: coordinator.lastPath) else {
            return PlistDecodeResult(status: .parseFailed, object: nil,
                                     errorDescription: "unknown plist path")
        }
        if stub.decodeFailed {
            return PlistDecodeResult(status: .parseFailed, object: nil,
                                     errorDescription: "invalid plist")
        }
        let object = PlistDecodedObject(rootObject: stub.decodeRoot ?? NSNull(),
                                         format: stub.format)
        return PlistDecodeResult(status: .success, object: object, errorDescription: nil)
    }
}

/// Parser 计数侧别。
enum EngineC2ParserSide {
    case hide, less
}

/// Parser 计数包装：委托真实 Parser，记录次数、最后路线与格式信号。
final class EngineC2CountingParser: FilterParsing {
    private let delegate: FilterParsing
    private let coordinator: EngineC2Coordinator
    private let side: EngineC2ParserSide
    var lastRoute: String?
    var lastPlistFormat: String?

    init(coordinator: EngineC2Coordinator,
         side: EngineC2ParserSide,
         delegate: FilterParsing) {
        self.coordinator = coordinator
        self.side = side
        self.delegate = delegate
    }

    func parse(object: Any?,
               pairingKey: String?,
               dylibPath: String?,
               plistPath: String?,
               route: String?,
               plistFormat: String,
               readStatus: String) -> FilterParseResult {
        switch side {
        case .hide: coordinator.hideCallCount += 1
        case .less: coordinator.lessCallCount += 1
        }
        lastRoute = route
        lastPlistFormat = plistFormat
        return delegate.parse(object: object,
                              pairingKey: pairingKey,
                              dylibPath: dylibPath,
                              plistPath: plistPath,
                              route: route,
                              plistFormat: plistFormat,
                              readStatus: readStatus)
    }
}

// MARK: - 构造器

/// 文件证据桩。
func engineC2Evidence(name: String,
                      kind: PluginFileKind,
                      path: String?) -> PluginFileEvidence {
    PluginFileEvidence(
        path: path,
        name: name,
        extension: name.components(separatedBy: ".").last,
        kind: kind,
        exists: true,
        readable: true
    )
}

/// 配对记录桩。
func engineC2Record(key: String,
                    category: PairingCategory = .paired,
                    pairing: Pairing? = .paired,
                    plistPath: String? = nil,
                    dylibPath: String? = nil,
                    reason: String? = nil,
                    basis: PairingEvidenceBasis = .exactFilenameMatch) -> PluginPairingRecord {
    let plistPath = plistPath ?? "/dir/\(key).plist"
    let dylibPath = dylibPath ?? "/dir/\(key).dylib"
    return PluginPairingRecord(
        category: category,
        pairing: pairing,
        pairingKey: key,
        dylib: engineC2Evidence(name: (dylibPath as NSString?)?.lastPathComponent ?? "\(key).dylib",
                                kind: .dylib, path: dylibPath),
        plist: engineC2Evidence(name: (plistPath as NSString?)?.lastPathComponent ?? "\(key).plist",
                                kind: .plist, path: plistPath),
        reason: reason,
        basis: basis
    )
}

/// 配对快照桩。
func engineC2Snapshot(route: String?,
                      records: [PluginPairingRecord],
                      unknownItems: [UnknownItem] = [],
                      warnings: [ReportWarning] = [],
                      status: PairingStatus = .enumerated,
                      sourceDirectory: String? = "/dir") -> PluginPairingSnapshot {
    PluginPairingSnapshot(
        route: route,
        sourceDirectory: sourceDirectory,
        status: status,
        records: records,
        unknownItems: unknownItems,
        counts: PluginPairingCounts(),
        warnings: warnings
    )
}

/// RootHide 合法 Filter 根对象（三数组齐备，避免缺失字段告警干扰合并顺序断言）。
func engineC2ValidRoot(bundles: [String],
                       classes: [String] = [],
                       executables: [String] = []) -> [String: Any] {
    ["Filter": [
        "Bundles": bundles,
        "Classes": classes,
        "Executables": executables
    ] as [String: Any]]
}

/// 构造 Engine：Reader / Decoder 走桩，双 Parser 由调用方注入（真实实现或计数包装）。
func engineC2Engine(coordinator: EngineC2Coordinator,
                    hide: FilterParsing,
                    less: FilterParsing) -> PluginFilterParseEngine {
    PluginFilterParseEngine(
        reader: EngineC2StubReader(coordinator),
        decoder: EngineC2StubDecoder(coordinator),
        rootHideParser: hide,
        rootlessParser: less
    )
}
