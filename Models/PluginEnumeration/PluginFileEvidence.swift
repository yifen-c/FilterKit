//
//  PluginFileEvidence.swift
//  FilterKit Models — 插件文件条目证据（G-C1，契约冻结 §3.2 / §3.3）
//
//  枚举阶段逐条条目中性证据；过程信号独立于最终 `Plugin`，不在本结构内
//  做配对、解析或加载结论。三态事实位 `nil`=未验证，不得填 `false`；
//  信号缺失按未提供处理，不反推补齐，不留空串冒充已知。
//
//  首版不纳入：修改时间、权限位、inode、UID/GID、loaded/configured/installed
//  等运行层或基线外字段。`hash` 仅承载离线信号，C1 不执行哈希计算。
//

import Foundation

/// 插件文件条目证据（枚举快照条目载体）。
public struct PluginFileEvidence: Codable, Equatable {
    /// 完整路径（原始身份键）；上游目录未定位时可为 `nil`。
    public let path: String?
    /// 原始文件名，原样保留，不改写大小写、空格、尾字符或扩展名。
    public let name: String
    /// 最后一个 `.` 之后的原始后缀，保留大小写；无扩展名（含点开头且无第二段点号）为 `nil`。
    public let `extension`: String?
    /// 分类结果（封闭集五值）。
    public let kind: PluginFileKind
    /// 在位事实位（三态：`nil`=未验证）。
    public let exists: Bool?
    /// 可读事实位（三态；不可读 ≠ 不存在）。
    public let readable: Bool?
    /// 软链标志（三态：`false`=已确认非软链，`nil`=未检查；记录自身，不跟随目标）。
    public let isSymlink: Bool?
    /// 软链目标信号；不为获取目标而解析跟随。
    public let symlinkTarget: String?
    /// 软链状态开放字符串口径（`resolved/broken/loop/denied/not_symlink`），首版不强枚举。
    public let symlinkState: String?
    /// 解析真实路径；元数据不可获取为 `nil`，不反推补齐。
    public let realpath: String?
    /// 文件大小；不可获取为 `nil`。
    public let size: Int?
    /// 只读摘要信号；C1 不计算哈希，失败/未提供为 `nil` 且不阻断枚举。
    public let hash: String?
    /// 文件名以 `.` 开头；缺省 `false`。
    public let hidden: Bool
    /// 条目级异常分层（封闭集五值）；缺省 `.ok`。
    public let entryStatus: PluginEntryStatus

    public init(path: String? = nil,
                name: String,
                extension: String? = nil,
                kind: PluginFileKind,
                exists: Bool? = nil,
                readable: Bool? = nil,
                isSymlink: Bool? = nil,
                symlinkTarget: String? = nil,
                symlinkState: String? = nil,
                realpath: String? = nil,
                size: Int? = nil,
                hash: String? = nil,
                hidden: Bool = false,
                entryStatus: PluginEntryStatus = .ok) {
        self.path = path
        self.name = name
        self.`extension` = `extension`
        self.kind = kind
        self.exists = exists
        self.readable = readable
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.symlinkState = symlinkState
        self.realpath = realpath
        self.size = size
        self.hash = hash
        self.hidden = hidden
        self.entryStatus = entryStatus
    }

    private enum CodingKeys: String, CodingKey {
        case path, name, `extension`, kind, exists, readable, isSymlink
        case symlinkTarget, symlinkState, realpath, size, hash, hidden, entryStatus
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decodeIfPresent(String.self, forKey: .path)
        name = try c.decode(String.self, forKey: .name)
        `extension` = try c.decodeIfPresent(String.self, forKey: .`extension`)
        kind = try c.decode(PluginFileKind.self, forKey: .kind)
        exists = try c.decodeIfPresent(Bool.self, forKey: .exists)
        readable = try c.decodeIfPresent(Bool.self, forKey: .readable)
        isSymlink = try c.decodeIfPresent(Bool.self, forKey: .isSymlink)
        symlinkTarget = try c.decodeIfPresent(String.self, forKey: .symlinkTarget)
        symlinkState = try c.decodeIfPresent(String.self, forKey: .symlinkState)
        realpath = try c.decodeIfPresent(String.self, forKey: .realpath)
        size = try c.decodeIfPresent(Int.self, forKey: .size)
        hash = try c.decodeIfPresent(String.self, forKey: .hash)
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        entryStatus = try c.decodeIfPresent(PluginEntryStatus.self, forKey: .entryStatus) ?? .ok
    }
}
