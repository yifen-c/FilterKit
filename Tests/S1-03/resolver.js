/**
 * S1-03 ElleKit 目录定位 — 离线校验解析模块（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-03-ElleKit-Directory-Resolution.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续迁移 Core/Adapters。
 * 虚拟文件系统以信号注入模拟，不访问真实设备文件系统。
 *
 * 分层：路线+上游 JBROOT 推导目录路径 → 目录状态校验 → 软链核对与裁决。
 * 红线：RootHide 禁止回退 /var/jb 或 /；realpath/存在 不推出可读/可枚举。
 */

const TI_SUFFIX = '/usr/lib/TweakInject/';
const DL_SUFFIX = '/Library/MobileSubstrate/DynamicLibraries';

function normalizeLexical(p) {
  if (typeof p !== 'string' || p === '') return null;
  const parts = [];
  for (const seg of p.split('/')) {
    if (seg === '' || seg === '.') continue;
    if (seg === '..') { if (parts.length) parts.pop(); continue; }
    parts.push(seg);
  }
  return '/' + parts.join('/');
}

function tiPath(route, jbroot) {
  if (route === 'rootless') return '/var/jb' + TI_SUFFIX;
  if (route === 'rootful') return TI_SUFFIX;
  if (route === 'roothide') return jbroot ? jbroot + TI_SUFFIX : null;
  return null;
}

function dlPath(route, jbroot) {
  if (route === 'rootless') return '/var/jb' + DL_SUFFIX;
  if (route === 'rootful') return DL_SUFFIX;
  if (route === 'roothide') return jbroot ? jbroot + DL_SUFFIX : null;
  return null;
}

function resolveDirectory(env) {
  const upstream = (env && env.upstream) || {};
  const fs = (env && env.fs) || {};
  const route = upstream.route || 'unknown';
  const jbroot = upstream.jbroot ?? null;
  const ti = fs.tweakInject || {};
  const dl = fs.dynamicLibraries || {};
  const warnings = [];

  const tPath = tiPath(route, jbroot);
  const dPath = dlPath(route, jbroot);

  let tiStatus;
  if (tPath === null) {
    tiStatus = 'unresolved';
    warnings.push('directory_unresolved');
  } else if (!ti.exists) {
    tiStatus = 'not_found';
    warnings.push('directory_not_found');
  } else if (!ti.readable || !ti.enumerable) {
    tiStatus = 'partial';
    warnings.push('access_limited');
  } else {
    tiStatus = 'confirmed';
  }

  const dlState = dl.symlinkState || 'not_symlink';
  let targetMatch = false;
  if (dlState === 'resolved' && dl.symlinkTarget && tPath) {
    targetMatch = normalizeLexical(dl.symlinkTarget) === normalizeLexical(tPath);
  }

  if (dlState === 'broken') warnings.push('symlink_broken');
  else if (dlState === 'loop') warnings.push('symlink_loop');
  else if (dlState === 'denied') warnings.push('symlink_target_denied');
  else if (dlState === 'not_symlink' && dl.exists) warnings.push('not_a_symlink');

  if (dlState === 'resolved' && tPath && !targetMatch) warnings.push('structure_conflict');
  if (route === 'rootful') warnings.push('rootful_route_not_profile');

  let outcome;
  if (tPath === null) outcome = 'unresolved';
  else if (tiStatus === 'not_found') outcome = 'not_found';
  else if (dlState === 'resolved' && !targetMatch) outcome = 'structure_conflict';
  else if (route === 'rootful') outcome = 'rootful_diagnostic';
  else if (tiStatus === 'confirmed' && dlState === 'resolved' && targetMatch) outcome = 'resolved';
  else outcome = 'partial';

  return {
    route,
    tweakInject: {
      value: tPath,
      exists: Boolean(ti.exists),
      readable: Boolean(ti.readable),
      enumerable: Boolean(ti.enumerable),
      realpath: ti.realpath ?? null,
      structureMatch: Boolean(ti.structureMatch),
      status: tiStatus,
    },
    dynamicLibraries: {
      value: dPath,
      isSymlink: Boolean(dl.isSymlink),
      symlinkTarget: dl.symlinkTarget ?? null,
      realpath: dl.realpath ?? null,
      symlinkState: dlState,
      targetMatch,
    },
    outcome,
    warnings,
  };
}

module.exports = { resolveDirectory, tiPath, dlPath, normalizeLexical };
