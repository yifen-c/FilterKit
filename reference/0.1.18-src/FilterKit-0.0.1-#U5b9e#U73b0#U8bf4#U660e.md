# FilterKit 0.0.1

RootHide / Rootless 文件系统与已安装 App 枚举只读 PoC。

## 当前版本边界

0.0.1 只做探测和报告，不包含 Helper、Daemon、IPC、插件部署、启用/禁用、删除或任何越狱文件写操作。

启动后以 UITableView 展示 10 项验收结果。右上角可导出 JSON 报告，左上角可重新检测。

## 10 项验收

1. JBROOT 候选路径。
2. DynamicLibraries 候选目录。
3. dylib 文件枚举。
4. plist 文件读取。
5. ElleKit Filter 字典解析。
6. dpkg status 读取。
7. dpkg info/*.list 文件清单探测。
8. ElleKit 包版本识别。
9. LSApplicationWorkspace 应用枚举。
10. App 元数据与图标读取。

注意：LSApplicationWorkspace 和图标选择器均为运行时私有 API。源码采用动态调用，实际可用性必须在目标 RootHide 设备上验证。私有 API 可调用不代表所有应用元数据或图标都可读取。

## 构建

本地 RootHide：

```sh
make package-roothide
```

本地 Rootless：

```sh
make package-rootless
```

RootHide 使用 `roothide/theos`，Rootless 使用上游 `theos/theos`。GitHub Actions 工作流只响应手动 `workflow_dispatch`，运行时选择 `roothide` 或 `rootless`。

## GitHub Actions

进入仓库 Actions → `FilterKit 手动构建` → Run workflow，选择构建目标。构建完成后下载对应 Artifact 中的 DEB。

- RootHide：`macos-latest`、roothide/theos、`THEOS_PACKAGE_SCHEME=roothide`、`ARCHS=arm64e`
- Rootless：`macos-latest`、上游 Theos、`THEOS_PACKAGE_SCHEME=rootless`、`ARCHS=arm64`
- Node.js：`latest`，并启用 `check-latest`

当前工作流只上传 Artifact，不自动创建 Release，也不监听 push、tag 或 schedule 事件。

## 重要限制

- 这是工程起始版，不代表已在 RootHide 真机编译、安装或验证。
- Theos / SDK / macOS latest 会持续变化；GitHub Actions 的真实构建结果是最终验证依据。
- RootHide 访问能力依赖设备环境、签名权限和 entitlements；文件路径存在不等于 App 一定可读取。
- 目录枚举结果为零不必然代表 ElleKit 未安装，需结合实际路径、dpkg 状态和错误码判断。
- 版本路线：0.0.1 → 0.0.2 → … → 0.0.9 → 0.1.0。
