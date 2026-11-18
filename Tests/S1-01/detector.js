/**
 * S1-01 环境识别 — 离线校验识别模块（测试 harness）。
 *
 * 说明：本模块为 Stage 1 离线验证用的最小识别逻辑，规则对齐
 * Spec/Stage-1/S1-01-Environment-Detection.md。正式工程落地时迁移至 Core/Adapters，
 * 此处不代表 App 运行时实现，也不构成 RootHide 真机验证证据。
 *
 * 识别规则（只读，无任何设备写入）：
 * - 多信号组合判定，不只凭路径特征；
 * - 版本五态：not_installed / unreadable / unparsable / parsed / conflicted；
 * - 冲突不强行选边，不自动降级到 RootHide / Rootless Profile。
 */

const VERSION_RE = /^\d+\.\d+(?:\.\d+)?(?:-\d+)?$/;

function present(sig) {
  return Boolean(sig && sig.present && sig.value !== null && sig.value !== undefined);
}

function warn(warnings, code) {
  if (!warnings.includes(code)) warnings.push(code);
}

/**
 * @param {object} env 夹具 environment.json 内容
 * @returns {{
 *   jailbreakType: string, architecture: string, iosVersion: string,
 *   bootstrap: {name: string|null, version: string|null},
 *   ellekitImplementation: string, ellekitVersion: string|null,
 *   ellekitVersionStatus: string, adapterProfile: string|null,
 *   outcome: string, warnings: string[]
 * }}
 */
function detectEnvironment(env) {
  const s = (env && env.signals) || {};
  const warnings = [];

  const typeSig = s.jailbreakType || {};
  const archSig = s.architecture || {};
  const iosSig = s.iosVersion || {};
  const bootSig = s.bootstrap || {};
  const implSig = s.ellekitImplementation || {};
  const verSig = s.ellekitVersion || {};

  let jailbreakType = present(typeSig) ? String(typeSig.value).toLowerCase() : 'unknown';
  const architecture = present(archSig) ? String(archSig.value) : 'unknown';
  const iosVersion = present(iosSig) ? String(iosSig.value) : 'unknown';

  let bootstrap = { name: null, version: null };
  if (bootSig.present) {
    bootstrap = { name: bootSig.name ?? null, version: bootSig.version ?? null };
  }

  let ellekitImplementation = present(implSig) ? String(implSig.value).toLowerCase() : 'unknown';

  // 仅在已识别为越狱类型（roothide/rootless）时，才把 bootstrap/impl 缺失记为告警；
  // rootful / unknown 环境下这些信号本就不存在，不重复报缺失。
  const recognizedJb = jailbreakType === 'roothide' || jailbreakType === 'rootless';
  if (!bootSig.present && recognizedJb) warn(warnings, 'bootstrap_missing');
  if (!implSig.present && recognizedJb) warn(warnings, 'implementation_missing');

  // 版本五态推导
  let ellekitVersion = null;
  let ellekitVersionStatus;
  if (!verSig.present) {
    ellekitVersionStatus = 'not_installed';
  } else if (verSig.readability === 'unreadable') {
    ellekitVersionStatus = 'unreadable';
    warn(warnings, 'access_limited');
  } else {
    const raw = verSig.raw ?? verSig.value ?? null;
    if (raw !== null && VERSION_RE.test(String(raw))) {
      ellekitVersionStatus = 'parsed';
      ellekitVersion = String(raw);
    } else {
      ellekitVersionStatus = 'unparsable';
      warn(warnings, 'version_unparsable');
    }
  }

  // 冲突检测：① 路线信号冲突 ② 实现-版本冲突
  const routeConflict = jailbreakType === 'roothide' && s.rootlessPathPresent && s.rootlessPathPresent.value === true;
  const implVersionConflict =
    ellekitImplementation === 'upstream' &&
    ellekitVersionStatus === 'parsed' &&
    /1\.2-3/.test(String(ellekitVersion));

  let adapterProfile = null;
  let outcome;

  if (routeConflict || implVersionConflict) {
    if (routeConflict) warn(warnings, 'route_signal_conflict');
    if (implVersionConflict) warn(warnings, 'impl_version_conflict');
    jailbreakType = 'unknown';
    ellekitImplementation = 'unknown';
    ellekitVersion = null;
    ellekitVersionStatus = 'conflicted';
    outcome = 'conflict_no_profile';
  } else if (jailbreakType === 'rootful') {
    warn(warnings, 'unsupported_rootful');
    outcome = 'unsupported_profile';
  } else if (
    jailbreakType === 'roothide' &&
    ellekitImplementation === 'roothide' &&
    ellekitVersionStatus === 'parsed'
  ) {
    adapterProfile = 'RootHideProfile_1_2_3';
    outcome = 'profile_candidate';
  } else if (
    jailbreakType === 'rootless' &&
    ellekitImplementation === 'upstream' &&
    ellekitVersionStatus === 'parsed'
  ) {
    adapterProfile = 'RootlessProfile_upstream';
    outcome = 'profile_candidate';
  } else if (jailbreakType === 'unknown' && ellekitImplementation === 'unknown' && ellekitVersionStatus === 'not_installed') {
    warn(warnings, 'no_jailbreak_signals');
    outcome = 'unknown';
  } else {
    outcome = 'partial';
  }

  const evidenceSource = env.fixtureId || 'synthetic';
  const statusOf = (known) => (known ? 'confirmed' : 'unknown');
  const versionStatusMap = {
    parsed: 'confirmed',
    not_installed: 'unknown',
    unreadable: 'unverified',
    unparsable: 'partial',
    conflicted: 'unknown',
  };

  const evidence = {
    jailbreakType: { value: jailbreakType, status: statusOf(jailbreakType !== 'unknown'), evidenceType: 'fixture', evidenceSource },
    architecture: { value: architecture, status: statusOf(architecture !== 'unknown'), evidenceType: 'fixture', evidenceSource },
    iosVersion: { value: iosVersion, status: statusOf(iosVersion !== 'unknown'), evidenceType: 'fixture', evidenceSource },
    bootstrap: {
      name: { value: bootstrap.name, status: statusOf(bootstrap.name !== null), evidenceType: 'fixture', evidenceSource },
      version: { value: bootstrap.version, status: statusOf(bootstrap.version !== null), evidenceType: 'fixture', evidenceSource },
    },
    ellekitImplementation: { value: ellekitImplementation, status: statusOf(ellekitImplementation !== 'unknown'), evidenceType: 'fixture', evidenceSource },
    ellekitVersion: { value: ellekitVersion, status: versionStatusMap[ellekitVersionStatus], evidenceType: 'fixture', evidenceSource },
    adapterProfile: { value: adapterProfile, status: statusOf(adapterProfile !== null), evidenceType: 'fixture', evidenceSource: adapterProfile ? 'profile-mapping' : evidenceSource },
  };

  return {
    jailbreakType,
    architecture,
    iosVersion,
    bootstrap,
    ellekitImplementation,
    ellekitVersion,
    ellekitVersionStatus,
    adapterProfile,
    outcome,
    warnings,
    evidence,
  };
}

module.exports = { detectEnvironment, VERSION_RE };
