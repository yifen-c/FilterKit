//
//  EngineC1-BaselineRegistry.swift
//  FilterKit Stage 2 — Engine-C1 S1-06 22 项基线注册表（测试目标专用）
//
//  逐条绑定 Stage 1 `Tests/Fixtures/S1-06/` 夹具与 `run.js` 合成样本；
//  夹具期望由 `EngineC1FixtureLoader` 从 metadata.json 运行时读取，注册表
//  仅补充 metadata 未承载的 CFV、字段级证据与顶层 reason 期望。22 项不增
//  不减；PARSE 编号一对多展开以 `-A/-B/-C` 区分执行样本。
//
//  挂起标记：`pendingRunner` 保留供后续基线在 Runner 出证前挂起；PARSE-015
//  在 C-G2（#151）Parser 专项出证后解除，完整 Engine 链路由 C2-D2 Runner 复验。
//

import Foundation
import Models

public enum EngineC1BaselineRegistry {

    /// 全部 22 项执行基线（顺序对齐 `S1-06-report.json` cases）。
    public static let all: [EngineC1BaselineCase] = [
        // 1. PARSE-003 binary 合法规则
        EngineC1BaselineCase(
            baselineID: "PARSE-003", caseID: "PARSE-003-A",
            route: .rootHide, source: .fixture(name: "parse-binary"),
            expectedRulesByBase: ["Bin": EngineC1ExpectedRule(
                bundles: ["com.bin.app"], classes: [], executables: [])]
        ),

        // 2. PARSE-006 Bundles 非数组
        EngineC1BaselineCase(
            baselineID: "PARSE-006", caseID: "PARSE-006-A",
            route: .rootHide, source: .fixture(name: "parse-bundles-wrong"),
            expectedSkippedByBase: ["BadBundles": [
                EngineC1ExpectedSkipped(key: "Bundles", reason: "not_array",
                                       expectedType: "string[]", observedType: "string")
            ]],
            expectedReasonByBase: ["BadBundles": "field_type"]
        ),

        // 3. PARSE-007 Classes 元素非字符串（index 0, number）
        EngineC1BaselineCase(
            baselineID: "PARSE-007", caseID: "PARSE-007-A",
            route: .rootHide, source: .fixture(name: "parse-classes-wrong"),
            expectedSkippedByBase: ["BadClasses": [
                EngineC1ExpectedSkipped(key: "Classes", reason: "element_type",
                                       expectedType: "string", observedType: "number", index: 0)
            ]],
            expectedReasonByBase: ["BadClasses": "field_type"]
        ),

        // 4. PARSE-016 确定性夹具 Delta
        EngineC1BaselineCase(
            baselineID: "PARSE-016", caseID: "PARSE-016-A",
            route: .rootHide, source: .fixture(name: "parse-determinism"),
            expectedRulesByBase: ["Delta": EngineC1ExpectedRule(
                bundles: ["com.delta.app"], classes: [], executables: ["DeltaApp"])]
        ),

        // 5. PARSE-011 空 Filter 合法
        EngineC1BaselineCase(
            baselineID: "PARSE-011", caseID: "PARSE-011-A",
            route: .rootHide, source: .fixture(name: "parse-empty-filter"),
            expectedRulesByBase: ["Empty": EngineC1ExpectedRule(
                bundles: [], classes: [], executables: [])]
        ),

        // 6. PARSE-008 Executables 非数组
        EngineC1BaselineCase(
            baselineID: "PARSE-008", caseID: "PARSE-008-A",
            route: .rootHide, source: .fixture(name: "parse-executables-wrong"),
            expectedSkippedByBase: ["BadExec": [
                EngineC1ExpectedSkipped(key: "Executables", reason: "not_array",
                                       expectedType: "string[]", observedType: "string")
            ]],
            expectedReasonByBase: ["BadExec": "field_type"]
        ),

        // 7. PARSE-013 非法 plist（Decoder 失败短路）
        EngineC1BaselineCase(
            baselineID: "PARSE-013", caseID: "PARSE-013-A",
            route: .rootHide, source: .fixture(name: "parse-invalid-plist"),
            expectedReasonByBase: ["Broken": "invalid_plist"]
        ),

        // 8. PARSE-011 稀疏字段容忍
        EngineC1BaselineCase(
            baselineID: "PARSE-011", caseID: "PARSE-011-B",
            route: .rootHide, source: .fixture(name: "parse-missing-fields"),
            expectedRulesByBase: ["Sparse": EngineC1ExpectedRule(
                bundles: [], classes: [], executables: [])]
        ),

        // 9. PARSE-005 Filter 缺失
        EngineC1BaselineCase(
            baselineID: "PARSE-005", caseID: "PARSE-005-A",
            route: .rootHide, source: .fixture(name: "parse-missing-filter"),
            expectedSkippedByBase: ["NoFilter": [
                EngineC1ExpectedSkipped(key: "Filter", reason: "filter_missing",
                                       expectedType: "object", observedType: "missing")
            ]],
            expectedReasonByBase: ["NoFilter": "filter_missing"]
        ),

        // 10. PARSE-012 多字段组合规则
        EngineC1BaselineCase(
            baselineID: "PARSE-012", caseID: "PARSE-012-A",
            route: .rootHide, source: .fixture(name: "parse-multi-rule"),
            expectedRulesByBase: ["Multi": EngineC1ExpectedRule(
                bundles: ["com.a.app", "com.b.app", "com.c.app"],
                classes: ["ClassX", "ClassY"],
                executables: ["ProcP", "ProcQ"])]
        ),

        // 11. PARSE-014 双记录 good + corrupt
        EngineC1BaselineCase(
            baselineID: "PARSE-014", caseID: "PARSE-014-A",
            route: .rootHide, source: .fixture(name: "parse-partial-corrupt"),
            expectedRulesByBase: ["Good": EngineC1ExpectedRule(
                bundles: ["com.good.app"], classes: [], executables: [])],
            expectedReasonByBase: ["Bad": "invalid_plist"]
        ),

        // 12. PARSE-015 Rootless 模型（C-G2 已出 Parser 专项证据；完整链路由 C2-D2 Runner 复验）
        EngineC1BaselineCase(
            baselineID: "PARSE-015", caseID: "PARSE-015-A",
            route: .rootless, source: .fixture(name: "parse-rootless-model"),
            expectedRulesByBase: ["RL": EngineC1ExpectedRule(
                bundles: ["com.example.app"], classes: [], executables: ["rlapp"],
                otherKeys: ["Classes", "CoreFoundationVersion", "IsTweakManager"])],
            pendingRunner: false
        ),

        // 13. PARSE-009 CFV 区间 [1500, 1700]
        EngineC1BaselineCase(
            baselineID: "PARSE-009", caseID: "PARSE-009-A",
            route: .rootHide, source: .fixture(name: "parse-versions"),
            expectedRulesByBase: ["Range": EngineC1ExpectedRule(
                bundles: [], classes: [], executables: [],
                cfvMode: .range, cfvMin: 1500, cfvMax: 1700)]
        ),

        // 14. PARSE-009-wrong CFV 字符串元素（顶层 reason 保留 versions_type）
        EngineC1BaselineCase(
            baselineID: "PARSE-009", caseID: "PARSE-009-B",
            route: .rootHide, source: .fixture(name: "parse-versions-wrong"),
            // 注：字符串元素分支的观测类型词与元素下标口径待 Runner 对照复核，
            // 本批只冻结 key / reason / expectedType；不归并为 field_type。
            expectedSkippedByBase: ["BadVer": [
                EngineC1ExpectedSkipped(key: "CoreFoundationVersion", reason: "versions_type",
                                       expectedType: "number[]")
            ]],
            expectedReasonByBase: ["BadVer": "versions_type"]
        ),

        // 15. PARSE-001 xml 全字段合法规则
        EngineC1BaselineCase(
            baselineID: "PARSE-001", caseID: "PARSE-001-A",
            route: .rootHide, source: .fixture(name: "parse-xml-valid"),
            expectedRulesByBase: ["Example": EngineC1ExpectedRule(
                bundles: ["com.example.app"], classes: ["ExampleClass"],
                executables: ["ExampleApp"], cfvMode: .max, cfvMax: 1600)]
        ),

        // 16. PARSE-002 同夹具重复样本（计数不重复累加）
        EngineC1BaselineCase(
            baselineID: "PARSE-002", caseID: "PARSE-002-A",
            route: .rootHide, source: .fixture(name: "parse-xml-valid"),
            expectedRulesByBase: ["Example": EngineC1ExpectedRule(
                bundles: ["com.example.app"], classes: ["ExampleClass"],
                executables: ["ExampleApp"], cfvMode: .max, cfvMax: 1600)]
        ),

        // 17. PARSE-012 目录未定位短路（unresolved）
        EngineC1BaselineCase(
            baselineID: "PARSE-012", caseID: "PARSE-012-B",
            route: .rootHide, source: .fixture(name: "route-guard"),
            expectedWarnings: ["inventory_unresolved"]
        ),

        // 18. PARSE-004 合成：根节点非字典
        EngineC1BaselineCase(
            baselineID: "PARSE-004", caseID: "PARSE-004-A",
            route: .rootHide, source: .synthetic(name: "root-type", root: "not-a-dict"),
            expectedStatusByBase: ["RootType": .typeMismatch],
            expectedSkippedByBase: ["RootType": [
                EngineC1ExpectedSkipped(key: "(root)", reason: "root_type",
                                       expectedType: "object", observedType: "string")
            ]],
            expectedReasonByBase: ["RootType": "root_type"]
        ),

        // 19. PARSE-005 合成：Filter 非字典
        EngineC1BaselineCase(
            baselineID: "PARSE-005", caseID: "PARSE-005-B",
            route: .rootHide, source: .synthetic(name: "filter-type", root: ["Filter": [1, 2]]),
            expectedStatusByBase: ["FilterType": .typeMismatch],
            expectedSkippedByBase: ["FilterType": [
                EngineC1ExpectedSkipped(key: "Filter", reason: "filter_type",
                                       expectedType: "object", observedType: "array")
            ]],
            expectedReasonByBase: ["FilterType": "filter_type"]
        ),

        // 20. PARSE-010 合成：混合类型错误证据（本轮重点补缺）
        EngineC1BaselineCase(
            baselineID: "PARSE-010", caseID: "PARSE-010-A",
            route: .rootHide,
            source: .synthetic(name: "mixed-type",
                               root: ["Filter": ["Bundles": "not-array", "Classes": [123]]]),
            expectedStatusByBase: ["Mixed": .typeMismatch],
            expectedSkippedByBase: ["Mixed": [
                EngineC1ExpectedSkipped(key: "Bundles", reason: "not_array",
                                       expectedType: "string[]", observedType: "string"),
                EngineC1ExpectedSkipped(key: "Classes", reason: "element_type",
                                       expectedType: "string", observedType: "number", index: 0)
            ]],
            expectedReasonByBase: ["Mixed": "field_type"]
        ),

        // 21. PARSE-016 合成：重复解析深比较一致
        EngineC1BaselineCase(
            baselineID: "PARSE-016", caseID: "PARSE-016-B",
            route: .rootHide,
            source: .synthetic(name: "determinism",
                               root: ["Filter": ["Bundles": ["com.delta.app"],
                                                 "Executables": ["DeltaApp"]]]),
            expectedStatusByBase: ["Delta": .valid],
            expectedRulesByBase: ["Delta": EngineC1ExpectedRule(
                bundles: ["com.delta.app"], classes: [], executables: ["DeltaApp"])]
        ),

        // 22. PARSE-012 合成：未知路线隔离，下游零调用
        EngineC1BaselineCase(
            baselineID: "PARSE-012", caseID: "PARSE-012-C",
            route: .unknown, source: .synthetic(name: "route-isolation", root: nil)
        )
    ]

    /// 注册表自校验：22 项、caseID 唯一。
    public static func validate() -> Bool {
        let ids = all.map(\.caseID)
        return ids.count == 22 && Set(ids).count == 22
    }

    /// 按 caseID 取基线。
    public static func first(byID id: String) -> EngineC1BaselineCase? {
        all.first { $0.caseID == id }
    }
}
