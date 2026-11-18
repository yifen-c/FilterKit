/**
 * S1-08 统一模型 / JSON 导出 — 离线模型映射与导出器（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-08-Unified-Model-JSON-Export.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续迁移 Core/Models。
 * 输入为 S1-01~S1-07 产物快照（虚拟注入），不访问真实文件系统，不回写设备。
 *
 * 五项原则：证据不丢失；installed/configured/loaded 三层不互推；
 * 来源与权限分离；不确定状态保留；信封版本化且除 generatedAt 外确定性可重复。
 */

const SCHEMA_VERSION = '0.1.0';
const GENERATOR_VERSION = '0.1.0';

function nullIfMissing(v) { return v === undefined ? null : v; }

function indexByBase(list) {
  const m = new Map();
  for (const x of list || []) {
    if (x && x.base !== undefined) m.set(x.base, x);
  }
  return m;
}

function inventoryItem(s104, dylibPath) {
  if (!s104 || !Array.isArray(s104.items)) return null;
  return s104.items.find((i) => i.dylibPath === dylibPath) || null;
}

function defaultOwnership() {
  return { sourceType: 'unknown', packageID: null, listPath: null, confidence: 'unknown', writablePolicy: 'read_only' };
}

function buildEnvironment(up) {
  const s101 = up.s101 || {};
  const s102 = up.s102 || {};
  const s103 = up.s103 || {};
  const profileId = s101.adapterProfile
    || (s101.ellekitVersionStatus === 'unknown' ? 'unknown-profile' : 'unknown-profile');

  return {
    jailbreakType: s101.jailbreakType || 'unknown',
    ellekitImplementation: nullIfMissing(s101.ellekitImplementation),
    ellekitVersion: nullIfMissing(s101.ellekitVersion),
    profileId,
    jbroot: nullIfMissing(s102.jbroot),
    jbrand: nullIfMissing(s102.jbrand),
    iosVersion: nullIfMissing(s101.iosVersion),
    architecture: nullIfMissing(s101.architecture),
    evidenceLevel: (s101.evidence && s101.evidence.level) || 'partial',
    pathEvidence: {
      tweakInject: s103.tweakInject ?? null,
      dynamicLibraries: s103.dynamicLibraries ?? null,
      jbrootCandidates: s102.candidates || [],
    },
  };
}

function buildPlugin(pair, up, profileId) {
  const s104 = up.s104 || {};
  const s106 = up.s106 || {};
  const s107 = up.s107 || {};

  const parsedByBase = indexByBase(s106.parsed);
  const sourceByBase = indexByBase(s107.sources);
  const parsed = parsedByBase.get(pair.base) || null;
  const src = sourceByBase.get(pair.base) || null;

  const inv = inventoryItem(s104, pair.dylibPath);
  // installed 仅来自 S1-04 在位/可读证据；上游缺失或条目未列入库存 → null，不反推补齐
  const installed = s104.items === undefined || !inv ? null : !!inv.readable;
  // configured 仅来自 S1-06 parseStatus=valid；不由 installed/归属推导
  const configured = !!(parsed && parsed.parseStatus === 'valid');
  const loaded = 'unknown'; // 运行层：本阶段无独立运行时证据，恒 unknown

  const ownership = src
    ? {
        sourceType: src.sourceType || 'unknown',
        packageID: nullIfMissing(src.packageID),
        listPath: nullIfMissing(src.listPath),
        confidence: src.confidence || 'unknown',
        writablePolicy: src.writablePolicy || 'read_only',
      }
    : defaultOwnership();

  const ownershipDetails = src
    ? {
        fileOwnership: src.fileOwnership || null,
        markers: src.markers || null,
        conflicts: src.conflicts || [],
        notes: src.notes || [],
        packageVersion: nullIfMissing(src.packageVersion),
        architecture: nullIfMissing(src.architecture),
      }
    : null;

  const validation = parsed
    ? {
        status: parsed.validation?.status || parsed.parseStatus,
        warnings: parsed.validation?.warnings || [],
        skippedFields: parsed.skippedFields || [],
      }
    : { status: 'unknown', warnings: [], skippedFields: [] };

  const pluginID = src && src.packageID ? `${src.packageID}:${pair.base}` : pair.base;

  return {
    pluginID,
    name: src?.packageID || pair.base,
    version: nullIfMissing(src?.packageVersion),
    dylibPath: nullIfMissing(pair.dylibPath),
    plistPath: nullIfMissing(pair.plistPath),
    pairing: pair.pairing || 'paired',
    source: ownership.sourceType,
    ownership,
    ownershipDetails,
    filter: parsed?.filter ?? null,
    isTweakManager: parsed?.isTweakManager ?? false,
    loadCategory: 'unknown',
    installed,
    configured,
    loaded,
    validation,
    permission: { decision: 'undetermined', reason: 'authorization_gate_not_evaluated' },
    profileId,
    evidence: {
      sourceStages: ['S1-04', 'S1-05', 'S1-06', 'S1-07'].filter((s) => up[`s${s.slice(1)}`]),
      evidenceType: 'fixture',
      evidenceLevel: 'partial',
    },
  };
}

function collectUnknownItems(up) {
  const items = [];
  const s105 = up.s105 || {};
  const s106 = up.s106 || {};
  const s107 = up.s107 || {};
  const s104 = up.s104 || {};

  for (const x of s105.missingPlist || []) {
    items.push({ path: x.dylibPath || null, base: x.base || null, reason: x.pairing || 'missing_plist', sourceStage: 'S1-05', detail: {} });
  }
  for (const x of s105.orphanPlist || []) {
    items.push({ path: x.plistPath || null, base: x.base || null, reason: 'missing_dylib', sourceStage: 'S1-05', detail: {} });
  }
  for (const x of s105.ambiguous || []) {
    items.push({ path: x.path || null, base: x.base || null, reason: 'ambiguous', sourceStage: 'S1-05', detail: {} });
  }
  for (const x of s105.uncertain || []) {
    items.push({ path: x.path || null, base: x.base || null, reason: 'uncertain', sourceStage: 'S1-05', detail: {} });
  }
  for (const x of s106.notParsed || []) {
    items.push({ path: x.plistPath || x.dylibPath || null, base: x.base || null, reason: x.reason || 'not_parsed', sourceStage: 'S1-06', detail: {} });
  }
  for (const x of s107.unresolved || []) {
    items.push({ path: x.path || null, base: x.base || null, reason: x.reason || 'unresolved', sourceStage: 'S1-07', detail: {} });
  }
  for (const x of s104.unknownItems || []) {
    items.push({ path: x.path || null, base: x.base || null, reason: x.reason || 'unknown_item', sourceStage: 'S1-04', detail: {} });
  }
  return items;
}

function collectWarnings(up) {
  const warnings = [];
  const seen = new Set();
  const stages = [
    ['S1-01', up.s101], ['S1-02', up.s102], ['S1-03', up.s103], ['S1-04', up.s104],
    ['S1-05', up.s105], ['S1-06', up.s106], ['S1-07', up.s107],
  ];
  for (const [stage, snap] of stages) {
    for (const w of snap?.warnings || []) {
      const code = typeof w === 'string' ? w : w.code;
      const message = typeof w === 'string' ? '' : (w.message || '');
      const key = `${stage}:${code}`;
      if (seen.has(key)) continue;
      seen.add(key);
      warnings.push({ code, message, sourceStage: stage });
    }
  }
  return warnings;
}

function exportReport(env) {
  const up = env.upstream || {};
  const s105 = up.s105 || {};
  const sourceDirectory = s105.sourceDirectory ?? (up.s104 && up.s104.sourceDirectory) ?? null;

  const environment = buildEnvironment(up);

  if (sourceDirectory === null) {
    return {
      schemaVersion: SCHEMA_VERSION,
      generatorVersion: GENERATOR_VERSION,
      profile: { id: environment.profileId, route: up.s103?.route || up.s104?.route || 'unknown' },
      generatedAt: env.generatedAt || null,
      environment,
      plugins: [],
      unknownItems: [],
      warnings: [{ code: 'inventory_unresolved', message: '上游目录未定位，未回退扫描', sourceStage: 'S1-03' }],
    };
  }

  const pairs = s105.pairs || [];
  const plugins = pairs.map((pair) => buildPlugin(pair, up, environment.profileId));
  const unknownItems = collectUnknownItems(up);
  const warnings = collectWarnings(up);

  // 确定性排序：pluginID / path||base / code
  plugins.sort((a, b) => a.pluginID.localeCompare(b.pluginID));
  unknownItems.sort((a, b) => (a.path || a.base || '').localeCompare(b.path || b.base || ''));
  warnings.sort((a, b) => a.code.localeCompare(b.code));

  return {
    schemaVersion: SCHEMA_VERSION,
    generatorVersion: GENERATOR_VERSION,
    profile: { id: environment.profileId, route: up.s103?.route || up.s104?.route || 'unknown' },
    generatedAt: env.generatedAt || null,
    environment,
    plugins,
    unknownItems,
    warnings,
  };
}

module.exports = { exportReport, SCHEMA_VERSION, GENERATOR_VERSION };
