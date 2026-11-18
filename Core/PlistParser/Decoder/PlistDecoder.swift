//
//  PlistDecoder.swift
//  FilterKit Core — PlistParser Decoder（C3-B）
//
//  把 Reader 交付的 `Data` 解码为 Foundation 属性列表对象。本层只判断
//  「字节能否构成合法 plist」，不做根节点/字段类型业务规则核对（归 C3-C
//  路线 Parser）。支持 XML 与 Binary；非法字节 / 空数据 → `parse_failed`。
//

import Foundation

/// Decoder 协议（便于测试层替换只读桩）。
public protocol PlistDecoding {
    func decode(data: Data) -> PlistDecodeResult
}

/// 默认属性列表解码器（`PropertyListSerialization`）。
public final class PlistDecoder: PlistDecoding {

    public init() {}

    public func decode(data: Data) -> PlistDecodeResult {
        if data.isEmpty {
            return PlistDecodeResult(
                status: .parseFailed,
                object: nil,
                errorDescription: "empty_data"
            )
        }

        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let object = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            )
            return PlistDecodeResult(
                status: .success,
                object: PlistDecodedObject(rootObject: object, format: format),
                errorDescription: nil
            )
        } catch {
            return PlistDecodeResult(
                status: .parseFailed,
                object: nil,
                errorDescription: String(describing: error)
            )
        }
    }
}
