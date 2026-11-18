//
//  PlistDecodedObject.swift
//  FilterKit Core — PlistParser Decoder（C3-B）
//
//  解码后的 Foundation 对象容器。`rootObject` 为 `Any`，严格限制在 Core
//  内部使用，不进入公共 Codable Models；业务 Parser 只消费经类型谓词
//  （`PlistValueClassifier`）验证过的对象结构。
//

import Foundation

/// 解码成功的属性列表对象（Core 中间层）。
public struct PlistDecodedObject {
    /// 根对象（plist 合法类型：字典 / 数组 / 字符串 / 数字 / 布尔 / Data / Date）。
    public let rootObject: Any
    /// 识别出的属性列表格式。
    public let format: PropertyListSerialization.PropertyListFormat

    public init(rootObject: Any,
                format: PropertyListSerialization.PropertyListFormat) {
        self.rootObject = rootObject
        self.format = format
    }
}
