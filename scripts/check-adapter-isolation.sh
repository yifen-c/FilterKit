#!/usr/bin/env bash
#
# check-adapter-isolation.sh — Stage 2.2-C3 Engine-C2-E3 三向架构隔离静态检查
#
# 规则（对齐 Architecture.md §7/§8 与 C2-E3 口径）：
# 1. RootHide Adapter / Parser 不得引用 Rootless 类型/规则；
# 2. Rootless Adapter / Parser 不得引用 RootHide 类型/规则；
# 3. Core 不得直接实例化具体 Adapter（仅持有 ElleKitAdapter 协议）；
# 4. UI（App）不得自行实现插件扫描、路径解析或 plist 解析，相关能力必须来自共享 Core。
#
# 本脚本为静态文本检查（先剥离 // 注释再扫描代码），不能替代编译期依赖分析；
# CI 中与 swift build 配合。退出码 0 = 未发现越界引用；非 0 = 疑似交叉依赖。
# 除原始文本输出外，结尾追加机器可读 JSON 摘要（checks[].id/name/status + failed 计数）；
# 若设置环境变量 ISOLATION_SUMMARY_PATH，摘要同时写入该路径文件。
# 静态检查只是架构证据，不代表真机权限或真实插件加载行为已经通过。

set -u
cd "$(dirname "$0")/.."

fail=0

# 机器可读检查注册表
check_ids=()
check_names=()
check_status=()

record_check() {
  local id="$1" name="$2" status="$3"
  check_ids+=("$id")
  check_names+=("$name")
  check_status+=("$status")
}

rh_adapter="Adapters/RootHide/RootHideAdapter.swift"
rl_adapter="Adapters/Rootless/RootlessAdapter.swift"
rh_parser_dir="Core/PlistParser/RootHide"
rl_parser_dir="Core/PlistParser/Rootless"

strip_comments() { sed 's://.*$::' "$1"; }

echo "== 1a. 检查 RootHide Adapter 未引用 Rootless =="
if strip_comments "$rh_adapter" | grep -nE "Rootless|rootless|UpstreamElleKit"; then
  echo "FAIL: RootHide Adapter 代码引用了 Rootless 符号"
  fail=1
  record_check "1a" "RootHide adapter isolation" "failed"
else
  echo "OK"
  record_check "1a" "RootHide adapter isolation" "passed"
fi

echo "== 1b. 检查 RootHide Parser 未引用 Rootless 类型 =="
if grep -rnE "RootlessFilterParser|RootlessFilterCodable|RootlessFilterMapper" "$rh_parser_dir" --include='*.swift' \
   | sed 's://.*$::' | grep -E "RootlessFilter"; then
  echo "FAIL: RootHide Parser 目录引用了 Rootless 专用类型"
  fail=1
  record_check "1b" "RootHide parser isolation" "failed"
else
  echo "OK"
  record_check "1b" "RootHide parser isolation" "passed"
fi

echo "== 2a. 检查 Rootless Adapter 未引用 RootHide =="
if strip_comments "$rl_adapter" | grep -nE "RootHide|roothide|jbroot\(\)|RootHideProfile"; then
  echo "FAIL: Rootless Adapter 代码引用了 RootHide 符号"
  fail=1
  record_check "2a" "Rootless adapter isolation" "failed"
else
  echo "OK"
  record_check "2a" "Rootless adapter isolation" "passed"
fi

echo "== 2b. 检查 Rootless Parser 未引用 RootHide 类型 =="
if grep -rnE "RootHideFilterParser|RootHideFilterValidator|RootHideFilterTypeChecker|RootHideFilterMapper" "$rl_parser_dir" --include='*.swift' \
   | sed 's://.*$::' | grep -E "RootHideFilter"; then
  echo "FAIL: Rootless Parser 目录引用了 RootHide 专用类型"
  fail=1
  record_check "2b" "Rootless parser isolation" "failed"
else
  echo "OK"
  record_check "2b" "Rootless parser isolation" "passed"
fi

echo "== 3. 检查 Core 未直接实例化具体 Adapter =="
if grep -rnE "RootHideAdapter\(|RootlessAdapter\(" Core/ --include='*.swift'; then
  echo "FAIL: Core 直接实例化了具体 Adapter"
  fail=1
  record_check "3" "Core concrete adapter instantiation" "failed"
else
  echo "OK"
  record_check "3" "Core concrete adapter instantiation" "passed"
fi

echo "== 4. 检查 App 未私有实现扫描 / 解析 / 路径解析 =="
# App 只允许通过协议（ReportProviding / ReportExporting）做组合根注入；
# 不得直接引用 Core 具体扫描器、解析器、解码器、路径解析器或报告组装实现。
ui_forbidden=(
  "PluginDirectoryEnumerator"
  "PluginPairingEngine"
  "RootHideFilterParser"
  "RootlessFilterParser"
  "PlistDataReader"
  "PlistDecoder"
  "JBRootResolver"
  "ElleKitDirectoryResolver"
  "EnvironmentDetector"
  "PluginInventoryBuilder"
  "PluginPairingPipeline"
  "PluginPairingInputAdapter"
  "PluginFilterParseEngine"
  "ReportBuilder"
  "ReportValidator"
  "ReportService"
)
ui_hits=0
for symbol in "${ui_forbidden[@]}"; do
  if grep -rnE "$symbol" App/ --include='*.swift' | sed 's://.*$::' | grep -E "$symbol"; then
    echo "FAIL: App 直接引用了 Core 具体类型 $symbol"
    ui_hits=1
  fi
done
if [ "$ui_hits" -ne 0 ]; then
  fail=1
  record_check "4" "App core implementation isolation" "failed"
else
  echo "OK"
  record_check "4" "App core implementation isolation" "passed"
fi

echo "== 4b. 检查 App 未直接依赖 Adapters 具体适配 =="
if grep -rnE "import Adapters" App/ --include='*.swift'; then
  echo "FAIL: App 直接 import Adapters；适配调用必须经 Core 协议接缝"
  fail=1
  record_check "4b" "App adapter import prohibition" "failed"
else
  echo "OK"
  record_check "4b" "App adapter import prohibition" "passed"
fi

if [ "$fail" -ne 0 ]; then
  echo "== 隔离检查未通过 =="
else
  echo "== 隔离检查通过（静态文本层面） =="
fi

# 机器可读摘要：失败时同样输出，便于 CI 自动比较。
emit_summary() {
  local i last comma
  last=$((${#check_ids[@]} - 1))
  printf '{\n  "checks": [\n'
  for ((i = 0; i < ${#check_ids[@]}; i++)); do
    comma=","
    if [ "$i" -eq "$last" ]; then comma=""; fi
    printf '    {"id": "%s", "name": "%s", "status": "%s"}%s\n' \
      "${check_ids[$i]}" "${check_names[$i]}" "${check_status[$i]}" "$comma"
  done
  printf '  ],\n  "failed": %d\n}\n' "$fail"
}

SUMMARY_JSON="$(emit_summary)"
printf '%s\n' "$SUMMARY_JSON"
if [ -n "${ISOLATION_SUMMARY_PATH:-}" ]; then
  printf '%s\n' "$SUMMARY_JSON" > "$ISOLATION_SUMMARY_PATH"
fi

exit "$fail"
