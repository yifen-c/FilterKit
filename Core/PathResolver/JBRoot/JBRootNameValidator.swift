//
//  JBRootNameValidator.swift
//  FilterKit Core — JBROOT 容器命名校验（B3 / S1-02）
//
//  规则对齐 Stage 1 resolver.js 的 `isJbrootName` / `parseJbrand` / `basename`：
//  - 容器名前缀恰为 `.jbroot-`，后缀恰为 16 位十六进制（大小写均可）；
//  - 后缀数值非零；校验位：对解析出的数值依次位移 8/16/24/32/40/48/56 异或，
//    结果低 8 位等于原值低 8 位；
//  - `parseJbrand` 仅按命名规则返回大写后缀，不猜测 jbrand 语义；
//  - 本文件只做纯字符串/数值判断，不访问文件系统，不做路线或存在性裁决。
//

import Foundation

/// JBROOT 容器命名校验器（静态纯函数；规则冻结自 S1-02 基线，B3 不得改动长度/字符集/校验位口径）。
public enum JBRootNameValidator {

    /// 基线前缀常量（长度固定，勿改）。
    public static let prefix = ".jbroot-"
    /// 后缀十六进制位数固定为 16。
    public static let suffixLength = 16

    /// 取路径最后一段（对齐 resolver.js basename）：去尾斜杠后取最后一个 `/` 之后部分；
    /// 无分隔符时返回整段。
    public static func basename(of path: String) -> String {
        var trimmed = path
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let slash = trimmed.lastIndex(of: "/") else { return trimmed }
        return String(trimmed[trimmed.index(after: slash)...])
    }

    /// 校验容器命名是否合法（含前缀、16 位 hex、非零、校验位通过）。
    public static func isJbrootName(_ path: String) -> Bool {
        let name = basename(of: path)
        let expectedCount = prefix.count + suffixLength
        guard name.count == expectedCount, name.hasPrefix(prefix) else { return false }

        let suffix = String(name.dropFirst(prefix.count))
        guard suffix.allSatisfy({ $0.hexDigitValue != nil }),
              let value = UInt64(suffix, radix: 16),
              value != 0
        else { return false }

        var x: UInt64 = 0
        for shift in [8, 16, 24, 32, 40, 48, 56] {
            x ^= value >> UInt64(shift)
        }
        return (x & 0xff) == (value & 0xff)
    }

    /// 解析 jbrand：命名校验通过时返回大写 16 位后缀；否则返回 `nil`。
    /// 只做大小写归一，不附加任何语义推断（对齐基线 parseJbrand：先过校验位）。
    public static func parseJbrand(_ path: String) -> String? {
        let name = basename(of: path)
        guard isJbrootName(name) else { return nil }
        let suffix = String(name.dropFirst(prefix.count))
        return suffix.uppercased()
    }
}
