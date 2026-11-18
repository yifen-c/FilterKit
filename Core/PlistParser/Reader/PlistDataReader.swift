//
//  PlistDataReader.swift
//  FilterKit Core — PlistParser Reader（C3-B）
//
//  只读文件读取：指定路径读取为 `Data`。本层不判断 plist 内容合法性、
//  不做进程命中、不回退猜测路径（不拼 /var/jb）、不递归搜索、不替换
//  C2 已提供路径、不修改文件。读取失败不返回空 Data 冒充成功。
//

import Foundation

/// Reader 协议（便于测试层替换只读桩；生产实现见 `PlistDataReader`）。
public protocol PlistDataReading {
    func read(path: String) -> PlistReadResult
}

/// 默认文件读取器（Foundation `Data(contentsOf:)`）。
public final class PlistDataReader: PlistDataReading {

    public init() {}

    public func read(path: String) -> PlistReadResult {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return PlistReadResult(status: .success, data: data, path: path)
        } catch {
            let (status, code) = Self.classify(error: error)
            return PlistReadResult(
                status: status,
                data: nil,
                path: path,
                errorCode: code,
                errorDescription: String(describing: error)
            )
        }
    }

    /// 底层错误 → Reader 读取状态分类（测试可直接复用的纯函数接缝）。
    static func classify(error: Error) -> (status: PlistReadStatus, code: Int?) {
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            let mapped = Self.classify(error: underlying as Error)
            if mapped.status != PlistReadStatus.readFailed {
                return mapped
            }
        }

        switch ns.domain {
        case NSCocoaErrorDomain:
            switch ns.code {
            case CocoaError.fileNoSuchFile.rawValue,
                 CocoaError.fileReadNoSuchFile.rawValue:
                return (.notFound, ns.code)
            case CocoaError.fileReadNoPermission.rawValue:
                return (.accessDenied, ns.code)
            default:
                return (.readFailed, ns.code)
            }
        case NSPOSIXErrorDomain:
            guard let posix = POSIXErrorCode(rawValue: Int32(ns.code)) else {
                return (.readFailed, ns.code)
            }
            switch posix {
            case .ENOENT:
                return (.notFound, ns.code)
            case .EACCES, .EPERM:
                return (.accessDenied, ns.code)
            default:
                return (.readFailed, ns.code)
            }
        default:
            return (.readFailed, ns.code)
        }
    }
}
