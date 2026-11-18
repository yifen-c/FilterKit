//
//  PlistReadStatus.swift
//  FilterKit Core — PlistParser Reader（C3-B）
//
//  Reader 内部读取状态：只回答「指定路径能否成功读取为 Data」，不判断
//  plist 内容是否合法，也不等同于 Parser 五态。notFound / accessDenied /
//  readFailed 是读取层分类；映射到解析五态由 Engine 层按 C3-A 契约 §7 执行。
//

import Foundation

/// plist 文件读取状态（Reader 内部封闭集）。
public enum PlistReadStatus: String, Codable, Equatable {
    /// 文件成功读取为 Data（内容是否合法由 Decoder 判断）。
    case success
    /// 文件不存在。
    case notFound
    /// 权限拒绝 / 不可读。
    case accessDenied
    /// 其他 I/O 读取错误。
    case readFailed
}
