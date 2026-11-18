/**
 * S1-07 插件来源识别 — 离线校验识别器（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-07-Plugin-Source-Identification.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续迁移 Core/Adapters。
 * 输入为上游 Parsed Plugin Model 快照 + dpkg 清单信号 + 管理标记信号（虚拟注入），
 * 不访问真实文件系统，不读/写 dpkg 数据库，不回写设备。
 *
 * 归属判定优先级：dpkg `.list` 精确命中 → FilterKit 自管标记 → 用户导入标记 → unknown。
 * 来源识别 ≠ 管理授权；识别结果不产生操作放行结论。
 */

const INSTALLED_STATE = 'install ok installed';

function sameSet(a, b) {
  const x = [...(a || [])].sort();
  const y = [...(b || [])].sort();
  return x.length === y.length && x.every((v, i) => v === y[i]);
}

function matchOf(owners) {
  if (!owners.length) return 'none';
  if (owners.length > 1) return 'conflict';
  return 'exact';
}

/** 仅 installed 状态包的清单精确路径命中才计入归属。 */
function packageOwners(packages, path) {
  return packages
    .filter((p) => p.state === INSTALLED_STATE && Array.isArray(p.files) && p.files.includes(path))
    .map((p) => p.id)
    .sort();
}

function packageById(packages, id) {
  return packages.find((p) => p.id === id) || null;
}

function markerState(markers, kind, base) {
  const m = markers && markers[kind] && markers[kind].byBase && markers[kind].byBase[base];
  return m && m.state ? m.state : 'absent';
}

function zeroCounts() {
  return { owned_package: 0, filterkit_managed: 0, manual_import: 0, unknown: 0, conflict: 0, dpkg_unavailable: 0 };
}

function identifyEntry(entry, packages, markers, dbAvailable) {
  const dylibOwners = packageOwners(packages, entry.dylibPath);
  const plistOwners = entry.plistPath ? packageOwners(packages, entry.plistPath) : [];
  const dylibMatch = matchOf(dylibOwners);
  const plistMatch = entry.plistPath ? matchOf(plistOwners) : 'none';

  const markerStates = {
    filterkit: markerState(markers, 'filterkit', entry.base),
    manual: markerState(markers, 'manual', entry.base),
  };

  const fileOwnership = {
    dylib: { owners: dylibOwners, match: dylibMatch },
    plist: { owners: plistOwners, match: plistMatch },
  };

  const result = {
    base: entry.base,
    dylibPath: entry.dylibPath,
    plistPath: entry.plistPath ?? null,
    sourceType: 'unknown',
    ownership: 'unknown',
    packageID: null,
    packageVersion: null,
    architecture: null,
    listPath: null,
    fileOwnership,
    confidence: 'unknown',
    writablePolicy: 'read_only',
    markers: markerStates,
    conflicts: [],
    notes: [],
  };

  // 数据库级：不可读/缺失 → 整体降级 unknown，不回退、不猜归属。
  if (!dbAvailable) {
    result.ownership = 'unknown';
    result.sourceType = 'unknown';
    result.confidence = 'unknown';
    result.writablePolicy = 'read_only';
    result.notes.push('dpkg_unavailable');
    return { result, bucket: 'dpkg_unavailable' };
  }

  const allOwners = [...new Set([...dylibOwners, ...plistOwners])].sort();
  const conflict = dylibMatch === 'conflict' || plistMatch === 'conflict';
  const mixed = dylibOwners.length > 0 && plistOwners.length > 0 && !sameSet(dylibOwners, plistOwners);

  if (allOwners.length > 0) {
    // dpkg 归属优先；FilterKit 标记不能覆盖实际 package 所有权。
    const commonOwners = dylibOwners.length && plistOwners.length ? dylibOwners.filter((x) => plistOwners.includes(x)) : dylibOwners.length ? dylibOwners : plistOwners;
    const ownerPkg = commonOwners.length === 1 ? packageById(packages, commonOwners[0]) : null;

    if (conflict) {
      result.sourceType = 'dpkg_sileo';
      result.ownership = 'owned_package';
      result.confidence = 'heuristic';
      result.writablePolicy = 'read_only';
      result.conflicts = [
        { path: entry.dylibPath, packages: dylibOwners },
        ...(entry.plistPath && plistOwners.length > 1 ? [{ path: entry.plistPath, packages: plistOwners }] : []),
      ];
      result.notes.push('ownership_conflict');
      if (markerStates.filterkit === 'present') result.notes.push('marker_not_overridden');
      return { result, bucket: 'conflict' };
    }

    result.sourceType = 'dpkg_sileo';
    result.ownership = 'owned_package';
    result.confidence = 'exact_record';
    result.writablePolicy = 'read_only';
    if (ownerPkg) {
      result.packageID = ownerPkg.id;
      result.packageVersion = ownerPkg.version ?? null;
      result.architecture = ownerPkg.architecture ?? null;
      result.listPath = ownerPkg.listPath ?? null;
    }
    if (mixed) result.notes.push('mixed_package_ownership');
    if (markerStates.filterkit === 'present') result.notes.push('marker_not_overridden');
    return { result, bucket: 'owned_package' };
  }

  // 无 dpkg 归属：按本地标记判定；标记损坏不提升为有效归属。
  if (markerStates.filterkit === 'present') {
    result.sourceType = 'filterkit';
    result.ownership = 'filterkit_managed';
    result.confidence = 'exact_record';
    result.writablePolicy = 'managed';
    return { result, bucket: 'filterkit_managed' };
  }
  if (markerStates.manual === 'present') {
    result.sourceType = 'manual';
    result.ownership = 'manual_import';
    result.confidence = 'exact_record';
    result.writablePolicy = 'read_only'; // 默认只读；管理需后续门禁确认，不自动授权
    return { result, bucket: 'manual_import' };
  }

  // 证据不足：unknown，不以位置/文件名/无标记反推导入。
  result.sourceType = 'unknown';
  result.ownership = 'unknown';
  result.confidence = 'unknown';
  result.writablePolicy = 'read_only';
  if (markerStates.filterkit === 'corrupt' || markerStates.manual === 'corrupt') result.notes.push('marker_corrupt');
  return { result, bucket: 'unknown' };
}

function identifySources(env) {
  const upstream = env.upstream || {};
  const route = upstream.route || 'unknown';
  const sourceDirectory = upstream.sourceDirectory ?? null;
  const warnings = [];

  if (sourceDirectory === null) {
    return {
      route,
      sourceDirectory,
      status: 'unresolved',
      sources: [],
      unresolved: [],
      counts: zeroCounts(),
      warnings: ['inventory_unresolved'],
    };
  }

  const dpkg = env.dpkg || {};
  const dbAvailable = dpkg.dbStatus === 'ok';
  const packages = dpkg.packages || [];
  const entries = env.entries || [];
  const markers = env.markers || {};

  const sources = [];
  const unresolved = [];
  const counts = zeroCounts();

  for (const entry of entries) {
    const { result, bucket } = identifyEntry(entry, packages, markers, dbAvailable);
    counts[bucket] += 1;
    sources.push(result);
    if (bucket === 'unknown' || bucket === 'conflict' || bucket === 'dpkg_unavailable') {
      unresolved.push({ base: result.base, path: result.dylibPath, ownership: result.ownership, reason: result.notes[0] || 'unresolved' });
    }
  }

  if (!dbAvailable) warnings.push('dpkg_unavailable');
  if (counts.conflict > 0) warnings.push('ownership_conflict');

  const partial = counts.unknown > 0 || counts.conflict > 0 || counts.dpkg_unavailable > 0;
  const status = partial ? 'partial' : 'enumerated';

  return { route, sourceDirectory, status, sources, unresolved, counts, warnings: [...new Set(warnings)] };
}

module.exports = { identifySources, identifyEntry, packageOwners, INSTALLED_STATE };
