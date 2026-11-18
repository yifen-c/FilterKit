//
//  PluginFileEvidenceBuilder.swift
//  FilterKit Core — 条目证据构建（C1 / S1-04）
//
//  把离线条目信号转换为统一 `PluginFileEvidence`；只做事实位搬运与分类，
//  不访问真实文件系统，不计算哈希，不解析软链目标。三态 `Bool?` 原样保留，
//  信号缺失为 `nil`，不做 `nil → false` 转换。
//

import Foundation
import Models

/// 条目证据构建器。
public struct PluginFileEvidenceBuilder {

    private let classifier: PluginEntryClassifier

    public init(classifier: PluginEntryClassifier = PluginEntryClassifier()) {
        self.classifier = classifier
    }

    /// 由上游目录与条目信号构建单条证据。
    public func build(sourceDirectory: String?,
                      entry: PluginInventoryFixtureSignal.EntrySignal) -> PluginFileEvidence {
        let name = entry.name ?? ""
        let kind = classifier.classify(name: name, type: entry.type, isSymlink: entry.isSymlink)
        let status = PluginEntryStatus(rawValue: entry.entryStatus ?? "") ?? .ok

        return PluginFileEvidence(
            path: Self.joinPath(sourceDirectory, name: name),
            name: name,
            extension: PluginEntryClassifier.fileExtension(of: name),
            kind: kind,
            exists: entry.exists,
            readable: entry.readable,
            isSymlink: entry.isSymlink,
            symlinkTarget: entry.symlinkTarget,
            symlinkState: entry.symlinkState,
            realpath: entry.realpath,
            size: entry.size,
            hash: entry.hash,
            hidden: entry.hidden ?? false,
            entryStatus: status
        )
    }

    /// 目录与文件名拼接；目录未定位时路径为 `nil`。
    private static func joinPath(_ directory: String?, name: String) -> String? {
        guard let directory else { return nil }
        return directory.hasSuffix("/") ? directory + name : directory + "/" + name
    }
}
