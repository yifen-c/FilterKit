//
//  DisplayStatus.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  纯 Foundation 展示状态：语义分级 + 文案。本层不 import SwiftUI / UIKit，
//  不依赖 Core 具体实现；只消费 Models 冻结类型。分级仅用于界面配色/图标，
//  不改变 Core 状态语义，不把 unknown 升级为 success/failure。
//

import Foundation
import Models

/// 界面展示状态分级。
public enum DisplayStatusKind: String, Equatable, Codable {
    case success
    case warning
    case failure
    case unknown
}

/// 单条展示状态（文案 + 分级 + 可选补充说明）。
public struct DisplayStatus: Equatable, Identifiable {
    public let kind: DisplayStatusKind
    public let text: String
    public let detail: String?

    public var id: String { "\(kind.rawValue)-\(text)" }

    public init(kind: DisplayStatusKind, text: String, detail: String? = nil) {
        self.kind = kind
        self.text = text
        self.detail = detail
    }
}
