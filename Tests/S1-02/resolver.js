/**
 * S1-02 JBROOT 路径定位 — 离线校验解析模块（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-02-JBROOT-Path-Resolution.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续随工程落地迁移 Core/Adapters。
 * 全程只读：不访问真实文件系统，候选状态由夹具信号模拟。
 *
 * 分层：发现候选 → 校验候选（命名/存在/结构/可读/realpath）→ 裁决选择。
 * 红线：.jbroot-* 前缀不等于确认 JBROOT；realpath 成功不等于可读；jbrand 不猜语义。
 */

const JB_ROOT_PREFIX = '.jbroot-';
const JBRAND_LENGTH = 16;

function basename(p) {
  const norm = p.replace(/\/+$/, '');
  const idx = norm.lastIndexOf('/');
  return idx === -1 ? norm : norm.slice(idx + 1);
}

function checksumOk(value) {
  let x = 0n;
  for (const sh of [8, 16, 24, 32, 40, 48, 56]) x ^= value >> BigInt(sh);
  return (x & 0xffn) === (value & 0xffn);
}

/** 复刻 libroothide is_jbroot_name：前缀 + 16 hex + 校验位 + 非零。 */
function isJbrootName(name) {
  if (typeof name !== 'string') return false;
  if (name.length !== JB_ROOT_PREFIX.length + JBRAND_LENGTH) return false;
  if (name.slice(0, JB_ROOT_PREFIX.length) !== JB_ROOT_PREFIX) return false;
  const hex = name.slice(JB_ROOT_PREFIX.length);
  if (!/^[0-9A-Fa-f]{16}$/.test(hex)) return false;
  const value = BigInt('0x' + hex);
  if (value === 0n) return false;
  return checksumOk(value);
}

function parseJbrand(name) {
  if (!isJbrootName(name)) return null;
  return name.slice(JB_ROOT_PREFIX.length).toUpperCase();
}

/** 词法规范化：折叠重复分隔符、解析 . / ..、去尾斜杠；不访问文件系统。 */
function normalizeLexical(pathStr) {
  if (typeof pathStr !== 'string' || pathStr === '') return null;
  const parts = [];
  for (const seg of pathStr.split('/')) {
    if (seg === '' || seg === '.') continue;
    if (seg === '..') { if (parts.length) parts.pop(); continue; }
    parts.push(seg);
  }
  const out = '/' + parts.join('/');
  return out === '/' ? '/' : out;
}

function routeOfSource(source) {
  if (source === 'rootless') return 'rootless';
  if (source === 'rootful') return 'rootful';
  return 'roothide'; // api / scan / bootstrap
}

function resolvePaths(env) {
  const signals = (env && env.signals) || {};
  const rawCandidates = Array.isArray(signals.candidates) ? signals.candidates : [];
  const warnings = [];

  const candidates = rawCandidates.map((c) => {
    const root = normalizeLexical(c.root);
    const base = basename(root || '');
    const route = routeOfSource(c.source);
    const symlinkFailed = c.symlinkState === 'broken' || c.symlinkState === 'loop';

    let nameValid = null;
    if (route === 'roothide') nameValid = isJbrootName(base);

    const cand = {
      root,
      source: c.source,
      route,
      nameValid,
      exists: Boolean(c.exists),
      structureMatch: Boolean(c.structureMatch),
      readable: Boolean(c.readable),
      realpath: symlinkFailed ? null : (c.realpath ?? null),
      warnings: [],
      status: 'pending',
    };

    if (route === 'rootless') {
      cand.status = 'cross_route';
      cand.warnings.push('rootless_route_not_jbroot');
    } else if (route === 'rootful') {
      cand.status = 'cross_route';
      cand.warnings.push('rootful_route_not_jbroot');
    } else if (symlinkFailed) {
      cand.status = 'resolve_failed';
      cand.warnings.push('symlink_resolve_failed');
    } else if (nameValid === false) {
      cand.status = 'rejected_invalid';
      cand.warnings.push('invalid_container_name');
    } else if (!cand.exists) {
      cand.status = 'rejected_missing';
      cand.warnings.push('candidate_missing');
    } else if (!cand.readable) {
      cand.status = 'partial';
      cand.warnings.push('access_limited');
    } else {
      cand.status = 'confirmed';
    }
    return cand;
  });

  const rhEligible = candidates.filter(
    (c) => c.route === 'roothide' && c.status !== 'rejected_invalid' &&
      c.status !== 'rejected_missing' && c.status !== 'resolve_failed'
  );
  const crossRoute = candidates.filter((c) => c.route === 'rootless' || c.route === 'rootful');

  let jbroot = null;
  let jbrand = null;
  let realpath = null;
  let ambiguous = false;
  let outcome;
  let selectedSource = null;

  for (const c of candidates) for (const w of c.warnings) if (!warnings.includes(w)) warnings.push(w);

  if (rhEligible.length > 1) {
    ambiguous = true;
    outcome = 'ambiguous';
    warnings.push('multiple_candidates');
  } else if (rhEligible.length === 1) {
    const sel = rhEligible[0];
    jbroot = sel.root;
    jbrand = parseJbrand(basename(sel.root));
    realpath = sel.realpath;
    selectedSource = sel.source;
    outcome = sel.status === 'confirmed' ? 'resolved' : 'partial';
  } else if (candidates.some((c) => c.status === 'resolve_failed')) {
    outcome = 'resolve_failed';
  } else if (crossRoute.length > 0 && !candidates.some((c) => c.route === 'roothide')) {
    outcome = 'cross_route_only';
  } else if (candidates.length === 0) {
    outcome = 'no_candidate';
    warnings.push('no_jbroot_candidate');
  } else {
    outcome = 'no_candidate';
  }

  return {
    jbroot,
    jbrand,
    realpath,
    ambiguous,
    outcome,
    selectedSource,
    candidateCount: candidates.length,
    candidates,
    warnings,
  };
}

module.exports = { resolvePaths, isJbrootName, parseJbrand, normalizeLexical };
