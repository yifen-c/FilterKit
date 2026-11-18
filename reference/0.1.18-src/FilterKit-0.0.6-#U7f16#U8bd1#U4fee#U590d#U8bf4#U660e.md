# FilterKit 0.0.6 编译修复说明

## 基线

以用户上传的 `FilterKit-0.0.6-full-source.zip` 解压工程为唯一代码基线。GitHub Actions（roothide, arm64e, Xcode 26.6 / iPhoneOS 26.5 SDK）在编译 `Sources/FKDPKGAnalyzer.m` 阶段失败，其余源文件已编译通过。

## 失败根因

日志三处编译错误：

```
FKDPKGAnalyzer.m:97  error: 'CC_MD5_Init'    is deprecated ... [-Werror,-Wdeprecated-declarations]
FKDPKGAnalyzer.m:99  error: 'CC_MD5_Update'  is deprecated ... [-Werror,-Wdeprecated-declarations]
FKDPKGAnalyzer.m:103 error: 'CC_MD5_Final'   is deprecated ... [-Werror,-Wdeprecated-declarations]
```

- CommonCrypto 的 `CC_MD5_*` 流式 API 自 iOS 13 起被标记 deprecated。
- Theos 在未设 `GO_EASY_ON_ME` 时默认开启 `-Werror`，把 `deprecated-declarations` 告警升级为编译错误。

## 为什么不能换成 SHA256

`FKDMD5` 用于比对 dpkg 的 `info/<package>.md5sums`：该清单固定以 **32 位十六进制 MD5** 记录期望校验值。换成 SHA256 会与期望值格式不符，导致全部校验失效。此处是完整性核对，不是安全签名用途（代码中已注明）。因此算法必须保留 MD5。

## 本次修改

1. `Sources/FKDPKGAnalyzer.m`：仅在 `FKDMD5` 函数外层用函数级 pragma 局部抑制 `-Wdeprecated-declarations`，不放宽全局告警级别：

```objc
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static NSString *FKDMD5(NSString *path) { /* CC_MD5_Init/Update/Final */ }
#pragma clang diagnostic pop
```

2. `Sources/FKMainViewController.m`：导出报告文件名由残留的 `FilterKit-0.0.5-report.json` 更正为 `FilterKit-0.0.6-report.json`。

未改动：既有扫描流程、插件↔App 关联分析、dpkg 深度解析、17 项验收 ID、只读边界（无 Helper / Daemon / IPC / 启停 / 卸载 / 配置写入）。

## 验证状态

- 已完成：源码静态审计、`node scripts/validate-project.js` 结构与关键实现校验通过、plist/XML 合法性检查、括号配对检查、版本号一致性核对。
- 未在本环境执行：Theos 实编译（本地 Linux 无 clang / iOS SDK）、设备真机测试。
- 待 Actions / 真机确认：编译链接是否通过；若链接期出现 `undefined symbol: _CC_MD5_*`，再按 CommonCrypto 链接配置补链接库。
