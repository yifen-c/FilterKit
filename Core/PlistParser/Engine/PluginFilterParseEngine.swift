//
//  PluginFilterParseEngine.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B，契约 §3 流水线）
//
//  统一只读解析编排：消费 C2 配对快照，按 Stage 0~5 短路顺序串联 Reader、
//  Decoder 与双路线 Parser。Engine 只做编排，不重新实现读取/解码；不修改
//  上游快照、记录或夹具；单条失败不中断整轮；解析成功不推断 loaded。
//
//  短路顺序（下游调用次数矩阵见 Engine-A 测试计划 §4）：
//  Stage 0 目录未定位 → 空快照 + inventory_unresolved，下游零调用；
//  Stage 1 非 paired → notParsed，Reader/Decoder/Parser 零调用；
//  Stage 2 路线 unknown → notParsed，Reader/Decoder/Parser 零调用；
//  Stage 3 Reader 失败 → read_failed；
//  Stage 4 Decoder 失败 → parse_failed（invalid_plist）；
//  Stage 5 唯一可信路线 Parser，五态直传；失败不跨路线重试。
//

import Foundation
import Models

/// 双路线 Filter 解析引擎。
public final class PluginFilterParseEngine {

    private let reader: PlistDataReading
    private let decoder: PlistDecoding
    private let rootHideParser: FilterParsing
    private let rootlessParser: FilterParsing
    private let resolver: FilterParseRouteResolver
    private let builder: FilterParseSnapshotBuilder

    /// 依赖均可注入测试桩；生产默认接 C3-B / C3-C1 / C3-C2 冻结实现。
    public init(reader: PlistDataReading = PlistDataReader(),
                decoder: PlistDecoding = PlistDecoder(),
                rootHideParser: FilterParsing = RootHideFilterParser(),
                rootlessParser: FilterParsing = RootlessFilterParser(),
                resolver: FilterParseRouteResolver = FilterParseRouteResolver(),
                builder: FilterParseSnapshotBuilder = FilterParseSnapshotBuilder()) {
        self.reader = reader
        self.decoder = decoder
        self.rootHideParser = rootHideParser
        self.rootlessParser = rootlessParser
        self.resolver = resolver
        self.builder = builder
    }

    /// 对一份 C2 配对快照执行只读解析编排。
    public func parse(snapshot: PluginPairingSnapshot) -> FilterParseSnapshot {
        // Stage 0：目录未定位 → 空快照，下游零调用。
        if snapshot.status == .unresolved || snapshot.sourceDirectory == nil {
            return builder.buildUnresolved(upstream: snapshot)
        }

        let route = resolver.resolve(route: snapshot.route)
        var parsed: [FilterParseResult] = []
        var notParsed: [UnknownItem] = []

        for record in snapshot.records {
            // Stage 1：非 paired 不进入 Reader。
            guard record.category == .paired else {
                notParsed.append(Self.makeUnknownItem(
                    from: record,
                    reason: Self.nonPairedReason(record)
                ))
                continue
            }

            // Stage 2：未知路线不进入 Reader。
            guard route != .unknown else {
                notParsed.append(Self.makeUnknownItem(
                    from: record,
                    reason: "unknown_route",
                    extraDetail: ["route": Self.snapshotRouteValue(snapshot.route)]
                ))
                continue
            }

            parsed.append(parsePaired(record: record, route: route, snapshotRoute: snapshot.route))
        }

        // 上游 unknownItems 原样归集，不重分类。
        notParsed.append(contentsOf: snapshot.unknownItems)

        return builder.build(upstream: snapshot, parsed: parsed, notParsed: notParsed)
    }

    // MARK: - 单条配对记录流水线

    private func parsePaired(record: PluginPairingRecord,
                             route: FilterParseRoute,
                             snapshotRoute: String?) -> FilterParseResult {
        let pairingKey = record.pairingKey
        let dylibPath = record.dylib?.path
        let plistPath = record.plist?.path
        let routeString = snapshotRoute ?? route.rawValue

        // Stage 3：Reader。
        guard let plistPath else {
            return Self.makeReadFailed(
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: nil,
                route: routeString,
                reason: "read_failed",
                readStatus: "read_failed"
            )
        }
        let readResult = reader.read(path: plistPath)
        guard readResult.status == .success, let data = readResult.data else {
            let readStatus = Self.readStatusWord(readResult.status)
            return Self.makeReadFailed(
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: plistPath,
                route: routeString,
                reason: readStatus,
                readStatus: readStatus
            )
        }

        // Stage 4：Decoder。
        let decodeResult = decoder.decode(data: data)
        guard decodeResult.status == .success, let object = decodeResult.object else {
            return FilterParseResult(
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: plistPath,
                route: routeString,
                status: .parseFailed,
                reason: "invalid_plist",
                warnings: [Self.warning("invalid_plist")],
                plistFormat: "unknown",
                readStatus: "ok"
            )
        }

        // Stage 5：按唯一可信路线调用对应 Parser；无跨路线 fallback / 重试。
        let format = Self.formatWord(object.format)
        switch route {
        case .rootHide:
            return rootHideParser.parse(
                object: object.rootObject,
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: plistPath,
                route: routeString,
                plistFormat: format,
                readStatus: "ok"
            )
        case .rootless:
            return rootlessParser.parse(
                object: object.rootObject,
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: plistPath,
                route: routeString,
                plistFormat: format,
                readStatus: "ok"
            )
        case .unknown:
            // Stage 2 已拦截，此处为防御性兜底，不进入任一 Parser。
            return FilterParseResult(
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: plistPath,
                route: routeString,
                status: .notParsed,
                reason: "unknown_route",
                plistFormat: format,
                readStatus: "ok"
            )
        }
    }

    // MARK: - 信号映射

    private static func readStatusWord(_ status: PlistReadStatus) -> String {
        switch status {
        case .success: return "ok"
        case .accessDenied: return "access_denied"
        case .notFound, .readFailed: return "read_failed"
        }
    }

    private static func formatWord(_ format: PropertyListSerialization.PropertyListFormat) -> String {
        switch format {
        case .xml: return "xml"
        case .binary: return "binary"
        default: return "unknown"
        }
    }

    // MARK: - 归集构造

    private static func nonPairedReason(_ record: PluginPairingRecord) -> String {
        switch record.category {
        case .missingPlist: return record.reason ?? "missing_plist"
        case .orphanPlist: return record.reason ?? "missing_dylib"
        case .ambiguous: return "ambiguous"
        case .uncertain: return record.reason ?? "uncertain"
        case .paired: return "not_parsed"
        }
    }

    private static func makeUnknownItem(from record: PluginPairingRecord,
                                        reason: String,
                                        extraDetail: [String: String] = [:]) -> UnknownItem {
        var detail: [String: String] = ["pairing": record.category.rawValue]
        if let dylib = record.dylib?.path { detail["dylibPath"] = dylib }
        if let plist = record.plist?.path { detail["plistPath"] = plist }
        if !record.candidates.isEmpty {
            detail["candidateCount"] = String(record.candidates.count)
        }
        detail.merge(extraDetail) { _, rhs in rhs }
        let path: String? = record.dylib?.path ?? record.plist?.path
        return UnknownItem(
            path: path,
            base: record.pairingKey,
            reason: reason,
            sourceStage: "stage2.2-c3",
            detail: detail
        )
    }

    private static func makeReadFailed(pairingKey: String?,
                                       dylibPath: String?,
                                       plistPath: String?,
                                       route: String?,
                                       reason: String,
                                       readStatus: String) -> FilterParseResult {
        FilterParseResult(
            pairingKey: pairingKey,
            dylibPath: dylibPath,
            plistPath: plistPath,
            route: route,
            status: .readFailed,
            reason: reason,
            warnings: [warning(readStatus)],
            plistFormat: "unknown",
            readStatus: readStatus
        )
    }

    private static func warning(_ code: String) -> ReportWarning {
        ReportWarning(code: code, message: warningMessage(code), sourceStage: "stage2.2-c3")
    }

    private static func warningMessage(_ code: String) -> String {
        switch code {
        case "inventory_unresolved": return "配对目录未定位，未执行解析"
        case "partial_parsing": return "部分条目解析失败，快照按 partial 汇总"
        case "invalid_plist": return "plist 解码失败"
        case "access_denied": return "plist 访问受限"
        case "read_failed": return "plist 读取失败"
        default: return code
        }
    }

    private static func snapshotRouteValue(_ route: String?) -> String {
        route ?? "nil"
    }
}
