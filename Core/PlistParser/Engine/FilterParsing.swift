//
//  FilterParsing.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B）
//
//  路线 Parser 的内部注入接缝：便于 Engine 测试以只读桩替换真实 Parser，
//  记录下游调用次数与入参。接缝仅在 Core 内部使用，不演进 Adapters 七方法
//  协议，不新增公共 Models 类型。既有 RootHide / Rootless Parser 经本文件
//  扩展声明接入，不改动其各自源文件。
//

import Foundation

/// 单条已解码对象的路线 Parser 接缝。
public protocol FilterParsing {
    /// 解析单条 Decoder 已成功解码的根对象。
    /// - Parameters:
    ///   - object: Decoder 产出的根对象；
    ///   - pairingKey / dylibPath / plistPath: 上游配对记录透传信号；
    ///   - route: 路线原值透传；
    ///   - plistFormat / readStatus: Reader / Decoder 层信号透传。
    func parse(object: Any?,
               pairingKey: String?,
               dylibPath: String?,
               plistPath: String?,
               route: String?,
               plistFormat: String,
               readStatus: String) -> FilterParseResult
}

extension RootHideFilterParser: FilterParsing {}
extension RootlessFilterParser: FilterParsing {}
