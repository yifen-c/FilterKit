/**
 * S1-06 Plist & Filter 解析 — 离线校验解析器（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-06-Plist-Filter-Parsing.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续迁移 Core/Adapters。
 * 输入为 S1-05 配对快照 + plist 内容信号（虚拟注入），不访问真实文件系统，不回写设备。
 *
 * 两套独立 Adapter：
 *  - roothide：严格类型核对（RootHide 1.2-3，roothide injector.c）
 *  - rootless：Swift Codable 模型口径（Tweak.swift），C injector 宽松行为仅作风险记录
 */

function typeOf(v) {
  if (v === null || v === undefined) return 'null';
  if (Array.isArray(v)) return 'array';
  return typeof v; // string | number | boolean | object
}

function isDict(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
function isString(v) { return typeof v === 'string'; }
function isNumber(v) { return typeof v === 'number'; }
function isBoolean(v) { return typeof v === 'boolean'; }

const RH_ROOT_KEYS = ['Filter', 'IsTweakManager'];
const RH_FILTER_KEYS = ['Bundles', 'Classes', 'Executables', 'CoreFoundationVersion'];
const RL_ROOT_KEYS = ['Filter', 'UnloadAfter'];
const RL_FILTER_KEYS = ['Bundles', 'Executables'];

function cfvToVersion(arr) {
  if (arr.length === 1 && isNumber(arr[0])) return { mode: 'max', max: arr[0] };
  if (arr.length === 2 && isNumber(arr[0]) && isNumber(arr[1])) {
    return { mode: 'range', min: arr[0], max: arr[1] };
  }
  return null;
}

/** 收集未识别键（只读记录，不臆测语义）；识别集合按路线 Adapter 区分。 */
function collectOtherKeys(rootDict, filterDict, rootRecognized, filterRecognized) {
  const other = [];
  if (isDict(rootDict)) {
    for (const k of Object.keys(rootDict)) {
      if (!rootRecognized.includes(k)) other.push(k);
    }
  }
  if (isDict(filterDict)) {
    for (const k of Object.keys(filterDict)) {
      if (!filterRecognized.includes(k)) other.push(k);
    }
  }
  return [...new Set(other)].sort();
}

/**
 * RootHide 严格 Adapter。
 * 类型不符整份判 type_mismatch；可选字段缺失可容忍；不做进程命中判断。
 */
function parseRootHide(plist) {
  const skippedFields = [];
  const validation = { status: 'valid', warnings: [] };

  if (!isDict(plist.root)) {
    return {
      parseStatus: 'type_mismatch',
      reason: 'root_type',
      filter: null,
      isTweakManager: null,
      skippedFields: [{ key: '(root)', reason: 'root_type', expectedType: 'object', observedType: typeOf(plist.root) }],
      otherKeys: [],
      validation: { status: 'type_mismatch', warnings: ['root_type'] },
    };
  }

  const filter = plist.root.Filter;
  if (filter === undefined || filter === null) {
    return mismatch('filter_missing', skippedFields, 'Filter', 'object', 'missing');
  }
  if (!isDict(filter)) {
    return mismatch('filter_type', skippedFields, 'Filter', 'object', typeOf(filter));
  }

  let isTweakManager = false;
  if (plist.root.IsTweakManager !== undefined && plist.root.IsTweakManager !== null) {
    if (!isBoolean(plist.root.IsTweakManager)) {
      return mismatch('field_type', skippedFields, 'IsTweakManager', 'boolean', typeOf(plist.root.IsTweakManager));
    }
    isTweakManager = plist.root.IsTweakManager;
  }

  const bundles = checkStringArray(filter.Bundles, 'Bundles', skippedFields, { allowNullElement: true });
  const classes = checkStringArray(filter.Classes, 'Classes', skippedFields, { allowNullElement: false });
  const executables = checkStringArray(filter.Executables, 'Executables', skippedFields, { allowNullElement: false });
  if (bundles.mismatch || classes.mismatch || executables.mismatch) {
    return mismatch('field_type', skippedFields);
  }

  let coreFoundationVersion = null;
  if (filter.CoreFoundationVersion !== undefined && filter.CoreFoundationVersion !== null) {
    const v = filter.CoreFoundationVersion;
    if (!Array.isArray(v) || !v.every(isNumber)) {
      return mismatch('versions_type', skippedFields, 'CoreFoundationVersion', 'number[]', typeOf(v));
    }
    coreFoundationVersion = cfvToVersion(v);
    if (coreFoundationVersion === null) {
      skippedFields.push({ key: 'CoreFoundationVersion', reason: 'unsupported_length', expectedType: 'number[1|2]', observedType: `number[${v.length}]` });
      validation.warnings.push('versions_length_unhandled');
    }
  }

  return {
    parseStatus: 'valid',
    reason: null,
    filter: {
      bundles: bundles.value,
      classes: classes.value,
      executables: executables.value,
      coreFoundationVersion,
      otherKeys: collectOtherKeys(plist.root, filter, RH_ROOT_KEYS, RH_FILTER_KEYS),
    },
    isTweakManager,
    skippedFields,
    otherKeys: collectOtherKeys(plist.root, filter, RH_ROOT_KEYS, RH_FILTER_KEYS),
    validation,
  };
}

function checkStringArray(value, key, skippedFields, { allowNullElement }) {
  if (value === undefined || value === null) return { mismatch: false, value: [] };
  if (!Array.isArray(value)) {
    skippedFields.push({ key, reason: 'not_array', expectedType: 'string[]', observedType: typeOf(value) });
    return { mismatch: true, value: null };
  }
  for (let i = 0; i < value.length; i++) {
    const el = value[i];
    if (el === null) {
      if (!allowNullElement) {
        skippedFields.push({ key, reason: 'null_element', expectedType: 'string', observedType: 'null', index: i });
        return { mismatch: true, value: null };
      }
      continue;
    }
    if (!isString(el)) {
      skippedFields.push({ key, reason: 'element_type', expectedType: 'string', observedType: typeOf(el), index: i });
      return { mismatch: true, value: null };
    }
  }
  return { mismatch: false, value: value.slice() };
}

function mismatch(reason, skippedFields, key, expectedType, observedType) {
  const entry = key
    ? { key, reason, expectedType: expectedType || 'object', observedType: observedType || 'unknown' }
    : { reason };
  skippedFields.push(entry);
  return {
    parseStatus: 'type_mismatch',
    reason,
    filter: null,
    isTweakManager: null,
    skippedFields,
    otherKeys: [],
    validation: { status: 'type_mismatch', warnings: [reason] },
  };
}

/**
 * Rootless Adapter（以 Swift Codable 模型为准）。
 * 模型字段：Filter.Bundles [String]?、Filter.Executables [String]?、UnloadAfter Bool?。
 * 未覆盖键入 otherKeys，不判解码失败；C injector 宽松口径不在此套用。
 */
function parseRootless(plist) {
  const skippedFields = [];

  if (!isDict(plist.root)) {
    return fail('root_type', 'root 非字典，Codable 解码失败', 'object', typeOf(plist.root));
  }
  const filter = plist.root.Filter;
  if (filter === undefined || filter === null) {
    return fail('filter_missing', 'Filter 缺失，Codable 解码失败', 'object', 'missing');
  }
  if (!isDict(filter)) {
    return fail('filter_type', 'Filter 非字典，Codable 解码失败', 'object', typeOf(filter));
  }

  const bundles = checkCodableStringArray(filter.Bundles, 'Bundles', skippedFields);
  const executables = checkCodableStringArray(filter.Executables, 'Executables', skippedFields);
  if (bundles.mismatch || executables.mismatch) return fail('field_type', '字段类型不符，解码失败', null, null, skippedFields);

  let unloadAfter = null;
  if (plist.root.UnloadAfter !== undefined && plist.root.UnloadAfter !== null) {
    if (!isBoolean(plist.root.UnloadAfter)) {
      return fail('field_type', 'UnloadAfter 非布尔，解码失败', 'boolean', typeOf(plist.root.UnloadAfter), skippedFields);
    }
    unloadAfter = plist.root.UnloadAfter;
  }

  // Swift 侧取值统一 lowercased；离线记录规范化结果，原始值由 plist 信号保留
  return {
    parseStatus: 'valid',
    reason: null,
    filter: {
      bundles: bundles.value.map((s) => s.toLowerCase()),
      classes: [],
      executables: executables.value.map((s) => s.toLowerCase()),
      coreFoundationVersion: null,
      otherKeys: collectOtherKeys(plist.root, filter, RL_ROOT_KEYS, RL_FILTER_KEYS),
    },
    isTweakManager: null, // Rootless Codable 模型无此字段；IsTweakManager 入 otherKeys，不判失败
    skippedFields,
    otherKeys: collectOtherKeys(plist.root, filter, RL_ROOT_KEYS, RL_FILTER_KEYS),
    validation: { status: 'valid', warnings: [] },
  };
}

function checkCodableStringArray(value, key, skippedFields) {
  if (value === undefined || value === null) return { mismatch: false, value: [] };
  if (!Array.isArray(value) || !value.every(isString)) {
    skippedFields.push({ key, reason: 'codable_type', expectedType: 'string[]', observedType: typeOf(value) });
    return { mismatch: true, value: null };
  }
  return { mismatch: false, value: value.slice() };
}

function fail(reason, message, expectedType, observedType, skippedFieldsIn) {
  const skipped = skippedFieldsIn || [{ reason, expectedType: expectedType || 'object', observedType: observedType || 'unknown' }];
  return {
    parseStatus: 'parse_failed',
    reason,
    filter: null,
    isTweakManager: null,
    skippedFields: skipped,
    otherKeys: [],
    validation: { status: 'parse_failed', warnings: [reason] },
  };
}

function parsePlist(route, plist) {
  // 读取级：读不出内容，与解析失败区分
  if (plist.readStatus !== 'ok') {
    return {
      parseStatus: 'read_failed',
      reason: plist.readStatus,
      filter: null,
      isTweakManager: null,
      skippedFields: [],
      otherKeys: [],
      validation: { status: 'read_failed', warnings: [plist.readStatus] },
    };
  }
  // 解析级：字节无法构成属性列表
  if (plist.payloadInvalid) {
    return {
      parseStatus: 'parse_failed',
      reason: 'invalid_plist',
      filter: null,
      isTweakManager: null,
      skippedFields: [],
      otherKeys: [],
      validation: { status: 'parse_failed', warnings: ['invalid_plist'] },
    };
  }

  if (route === 'rootless') return parseRootless(plist);
  return parseRootHide(plist);
}

function parseInventory(env) {
  const upstream = env.upstream || {};
  const route = upstream.route || 'unknown';
  const sourceDirectory = upstream.sourceDirectory ?? null;
  const warnings = [];

  if (sourceDirectory === null) {
    return {
      route,
      sourceDirectory,
      status: 'unresolved',
      parsed: [],
      notParsed: [],
      counts: { valid: 0, parse_failed: 0, type_mismatch: 0, read_failed: 0, not_parsed: 0 },
      warnings: ['inventory_unresolved'],
    };
  }

  const pairing = env.pairing || {};
  const pairs = pairing.pairs || [];
  const plistById = new Map();
  for (const p of env.plists || []) plistById.set(p.plistPath, p);

  const parsed = [];
  for (const pair of pairs) {
    const plist = plistById.get(pair.plistPath) || { plistPath: pair.plistPath, format: 'unknown', readStatus: 'read_failed', root: null, payloadInvalid: false };
    const r = parsePlist(route, plist);
    parsed.push({
      base: pair.base,
      dylibPath: pair.dylibPath,
      plistPath: pair.plistPath,
      plistFormat: plist.format || 'unknown',
      readStatus: plist.readStatus,
      parseStatus: r.parseStatus,
      reason: r.reason,
      isTweakManager: r.isTweakManager,
      filter: r.filter,
      skippedFields: r.skippedFields,
      validation: r.validation,
    });
  }

  const notParsed = [
    ...(pairing.missingPlist || []).map((x) => ({ base: x.base, dylibPath: x.dylibPath, plistPath: null, pairing: 'missing_plist', reason: x.pairing || 'missing_plist' })),
    ...(pairing.orphanPlist || []).map((x) => ({ plistPath: x.plistPath, pairing: 'orphan_plist', reason: x.reason || 'missing_dylib' })),
    ...(pairing.ambiguous || []).map((x) => ({ base: x.base, pairing: 'ambiguous', reason: 'ambiguous' })),
    ...(pairing.uncertain || []).map((x) => ({ path: x.path, pairing: 'uncertain', reason: x.reason || 'uncertain' })),
  ];

  const counts = {
    valid: parsed.filter((p) => p.parseStatus === 'valid').length,
    parse_failed: parsed.filter((p) => p.parseStatus === 'parse_failed').length,
    type_mismatch: parsed.filter((p) => p.parseStatus === 'type_mismatch').length,
    read_failed: parsed.filter((p) => p.parseStatus === 'read_failed').length,
    not_parsed: notParsed.length,
  };

  const partial = counts.parse_failed + counts.type_mismatch + counts.read_failed > 0;
  const status = partial ? 'partial' : 'enumerated';
  if (partial) warnings.push('partial_parsing');
  for (const p of parsed) warnings.push(...(p.validation.warnings || []));

  return { route, sourceDirectory, status, parsed, notParsed, counts, warnings: [...new Set(warnings)] };
}

module.exports = { parseInventory, parsePlist, parseRootHide, parseRootless, typeOf };
