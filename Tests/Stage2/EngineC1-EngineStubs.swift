//
//  EngineC1-EngineStubs.swift
//  FilterKit Stage 2 — Engine-C1 Engine 基线测试桩（测试目标专用）
//
//  按夹具 plist 路径回灌 Reader / Decoder 结果，并记录 Reader / Decoder /
//  双 Parser 调用次数；Parser 委托真实 RootHide / Rootless 实现，只叠加计数。
//  不实例化 Adapter、不访问真实文件系统；桩类型不进生产目标。
//

import Foundation
@testable import Core
@testable import Models

/// 基线桩协调器：串联 Reader 最近路径与各下游调用计数。
final class EngineC1Coordinator {
    let inputs: [EngineC1PlistInput]
    var lastPath: String?
    var readerCallCount = 0
    var decoderCallCount = 0
    var hideCallCount = 0
    var lessCallCount = 0

    init(inputs: [EngineC1PlistInput]) {
        self.inputs = inputs
    }

    func input(for path: String?) -> EngineC1PlistInput? {
        guard let path else { return nil }
        return inputs.first { $0.plistPath == path }
    }
}

/// Reader 桩：按路径回灌成功字节；读取失败不在基线桩内伪造（由专项覆盖）。
final class EngineC1StubReader: PlistDataReading {
    private let coordinator: EngineC1Coordinator

    init(_ coordinator: EngineC1Coordinator) {
        self.coordinator = coordinator
    }

    func read(path: String) -> PlistReadResult {
        coordinator.readerCallCount += 1
        coordinator.lastPath = path
        return PlistReadResult(status: .success, data: Data([0x00]), path: path)
    }
}

/// Decoder 桩：payloadInvalid 回 parse_failed，否则按桩输入回灌解码对象。
final class EngineC1StubDecoder: PlistDecoding {
    private let coordinator: EngineC1Coordinator

    init(_ coordinator: EngineC1Coordinator) {
        self.coordinator = coordinator
    }

    func decode(data: Data) -> PlistDecodeResult {
        coordinator.decoderCallCount += 1
        guard let input = coordinator.input(for: coordinator.lastPath) else {
            return PlistDecodeResult(status: .parseFailed, object: nil,
                                     errorDescription: "unknown plist path")
        }
        if input.payloadInvalid {
            return PlistDecodeResult(status: .parseFailed, object: nil,
                                     errorDescription: "invalid plist")
        }
        let format: PropertyListSerialization.PropertyListFormat =
            input.format == "binary" ? .binary : .xml
        let object = PlistDecodedObject(rootObject: input.root ?? NSNull(), format: format)
        return PlistDecodeResult(status: .success, object: object, errorDescription: nil)
    }
}

/// Parser 计数侧别。
enum EngineC1ParserSide {
    case hide, less
}

/// Parser 计数包装：委托真实 Parser，记录本路线调用次数。
final class EngineC1CountingParser: FilterParsing {
    private let delegate: FilterParsing
    private let coordinator: EngineC1Coordinator
    private let side: EngineC1ParserSide

    init(coordinator: EngineC1Coordinator,
         side: EngineC1ParserSide,
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
        return delegate.parse(object: object,
                              pairingKey: pairingKey,
                              dylibPath: dylibPath,
                              plistPath: plistPath,
                              route: route,
                              plistFormat: plistFormat,
                              readStatus: readStatus)
    }
}
