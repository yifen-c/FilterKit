/**
 * S1-06 Plist & Filter 解析 — 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十六组夹具 → 校验输入/预期分离 → 跑 PARSE-001~017 →
 * 核对双路线 Adapter、五类归类互斥、可选/必需字段区分、未配对条目保留与确定性 → 生成报告。
 * 全部为离线 fixture 合成样本，plist 内容以信号注入模拟，不访问真实设备文件系统。
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { parseInventory } = require('./parser');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-06');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_PARSE_MAP = {
  'parse-xml-valid': ['PARSE-001', 'PARSE-002'],
  'parse-binary': ['PARSE-003'],
  'parse-missing-filter': ['PARSE-005'],
  'parse-bundles-wrong': ['PARSE-006'],
  'parse-classes-wrong': ['PARSE-007'],
  'parse-executables-wrong': ['PARSE-008'],
  'parse-versions': ['PARSE-009'],
  'parse-versions-wrong': ['PARSE-009'],
  'parse-multi-rule': ['PARSE-012'],
  'parse-invalid-plist': ['PARSE-013'],
  'parse-partial-corrupt': ['PARSE-014'],
  'parse-rootless-model': ['PARSE-015'],
  'parse-empty-filter': ['PARSE-011'],
  'parse-missing-fields': ['PARSE-011'],
  'route-guard': ['PARSE-012'],
  'parse-determinism': ['PARSE-016'],
};

function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function normalize(v) { return v === undefined ? null : v; }

function deepEqual(a, b) {
  if (normalize(a) === normalize(b)) return true;
  if (typeof a !== typeof b) return false;
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    return a.every((x, i) => deepEqual(x, b[i]));
  }
  if (a && b && typeof a === 'object') {
    const ka = Object.keys(a), kb = Object.keys(b);
    if (ka.length !== kb.length) return false;
    return ka.every((k) => deepEqual(a[k], b[k]));
  }
  return false;
}

function sameSet(a, b) {
  return deepEqual([...(a || [])].sort(), [...(b || [])].sort());
}

function derive(result) {
  const statusByBase = {};
  const filterByBase = {};
  const otherKeysByBase = {};
  const skippedFieldsByBase = {};
  for (const p of result.parsed) {
    statusByBase[p.base] = p.parseStatus;
    if (p.parseStatus === 'valid' && p.filter) {
      filterByBase[p.base] = { bundles: p.filter.bundles, classes: p.filter.classes, executables: p.filter.executables };
      if (p.filter.otherKeys.length) otherKeysByBase[p.base] = p.filter.otherKeys;
    }
    const skipped = (p.skippedFields || []).map((s) => s.key).filter(Boolean);
    if (skipped.length) skippedFieldsByBase[p.base] = skipped;
  }
  return { statusByBase, filterByBase, otherKeysByBase, skippedFieldsByBase };
}

// partial_parsing 为由计数派生的状态级告警，原因级告警才纳入预期比对
function reasonWarnings(w) { return (w || []).filter((x) => x !== 'partial_parsing'); }

function compareResult(result, meta) {
  const expected = meta.expected || {};
  const expectedWarnings = meta.expectedWarnings || [];
  const failures = [];
  const d = derive(result);
  const checks = [
    ['route', result.route, expected.route],
    ['sourceDirectory', result.sourceDirectory, expected.sourceDirectory],
    ['status', result.status, expected.status],
    ['counts', result.counts, expected.counts],
    ['statusByBase', d.statusByBase, expected.statusByBase],
    ['filterByBase', d.filterByBase, expected.filterByBase],
    ['otherKeysByBase', d.otherKeysByBase, expected.otherKeysByBase || {}],
    ['skippedFieldsByBase', d.skippedFieldsByBase, expected.skippedFieldsByBase || {}],
  ];
  for (const [field, actual, want] of checks) {
    if (!deepEqual(actual, want)) failures.push(`${field}: 实际=${JSON.stringify(actual)} 期望=${JSON.stringify(want)}`);
  }
  if (!sameSet(reasonWarnings(result.warnings), expectedWarnings)) {
    failures.push(`warnings: 实际=[${reasonWarnings(result.warnings).join(',')}] 期望=[${expectedWarnings.join(',')}]`);
  }
  if (result.status !== meta.expectedStatus) {
    failures.push(`expectedStatus: 实际=${result.status} 期望=${meta.expectedStatus}`);
  }
  return failures;
}

function loadFixtures() {
  const kinds = fs.readdirSync(FIXTURE_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory()).map((d) => d.name);
  return kinds.map((kind) => ({
    kind,
    env: readJson(path.join(FIXTURE_DIR, kind, 'environment.json')),
    meta: readJson(path.join(FIXTURE_DIR, kind, 'metadata.json')),
  }));
}

function runFixtureCase(parseId, fixture) {
  const result = parseInventory(fixture.env);
  const failures = compareResult(result, fixture.meta);
  return {
    parseId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function makeEnv(route, dir, root, extra) {
  const base = extra && extra.base || 'Synthetic';
  return {
    upstream: { route, sourceDirectory: dir, inventoryStatus: 'enumerated' },
    pairing: {
      pairs: [{ base, dylibPath: dir + base + '.dylib', plistPath: dir + base + '.plist', pairing: 'paired', dylibIsSymlink: false, plistIsSymlink: false, status: 'ok' }],
      missingPlist: [], orphanPlist: [], ambiguous: [], uncertain: [],
    },
    plists: [{ plistPath: dir + base + '.plist', format: 'xml', readStatus: 'ok', payloadInvalid: false, root }],
  };
}

function buildSyntheticCases(fixtures) {
  const cases = [];
  const RH = '/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/';

  // PARSE-004：根节点非字典 → type_mismatch (root_type)
  cases.push((() => {
    const env = makeEnv('roothide', RH, 'not-a-dict', { base: 'RootType' });
    const r = parseInventory(env);
    const passed = r.counts.type_mismatch === 1 && r.parsed[0].reason === 'root_type';
    return { parseId: 'PARSE-004', source: 'synthetic:root-type', evidenceType: 'fixture', passed, result: r,
      failures: passed ? [] : ['根类型未判为 type_mismatch/root_type'] };
  })());

  // PARSE-005：Filter 非字典 → type_mismatch (filter_type)
  cases.push((() => {
    const env = makeEnv('roothide', RH, { Filter: [1, 2] }, { base: 'FilterType' });
    const r = parseInventory(env);
    const passed = r.counts.type_mismatch === 1 && r.parsed[0].reason === 'filter_type';
    return { parseId: 'PARSE-005', source: 'synthetic:filter-type', evidenceType: 'fixture', passed, result: r,
      failures: passed ? [] : ['Filter 类型未判为 type_mismatch/filter_type'] };
  })());

  // PARSE-010：混合类型异常 → type_mismatch，跳过字段保留证据
  cases.push((() => {
    const env = makeEnv('roothide', RH, { Filter: { Bundles: 'not-array', Classes: [123] } }, { base: 'Mixed' });
    const r = parseInventory(env);
    const keys = (r.parsed[0].skippedFields || []).map((s) => s.key);
    const passed = r.counts.type_mismatch === 1 && keys.includes('Bundles') && keys.includes('Classes');
    return { parseId: 'PARSE-010', source: 'synthetic:mixed-type', evidenceType: 'fixture', passed, result: r,
      failures: passed ? [] : [`混合类型异常未保留字段证据：${JSON.stringify(keys)}`] };
  })());

  // PARSE-016：相同 plist 重复解析，归类/规则/计数一致
  cases.push((() => {
    const det = fixtures.find((f) => f.kind === 'parse-determinism');
    const r1 = parseInventory(det.env);
    const r2 = parseInventory(det.env);
    const passed = deepEqual(r1, r2);
    return { parseId: 'PARSE-016', source: 'synthetic:determinism', evidenceType: 'fixture', passed, result: r1,
      failures: passed ? [] : ['重复解析结果不一致'] };
  })());

  // PARSE-012 补充：上游未定位时空模型，不回退 /var/jb
  cases.push((() => {
    const guard = fixtures.find((f) => f.kind === 'route-guard');
    const r = parseInventory(guard.env);
    const leak = r.parsed.some((p) => /^\/var\/jb/.test(p.plistPath || ''));
    const passed = r.sourceDirectory === null && r.parsed.length === 0 && !leak;
    return { parseId: 'PARSE-012', source: 'synthetic:route-isolation', evidenceType: 'fixture', passed,
      result: { sourceDirectory: r.sourceDirectory, counts: r.counts },
      failures: passed ? [] : ['回退扫描了 /var/jb 路径'] };
  })());

  return cases;
}

function runPriorRegression() {
  const stages = ['S1-01', 'S1-02', 'S1-03', 'S1-04', 'S1-05'];
  const regression = {};
  for (const stage of stages) {
    const script = path.join(ROOT, 'Tests', stage, 'run.js');
    try {
      execFileSync(process.execPath, [script], { stdio: 'pipe' });
      regression[stage] = 'passed';
    } catch (e) {
      regression[stage] = `failed (exit ${e.status})`;
    }
  }
  return regression;
}

function main() {
  const fixtures = loadFixtures();
  const cases = [];
  for (const fixture of fixtures) {
    for (const parseId of FIXTURE_PARSE_MAP[fixture.kind] || []) {
      cases.push(runFixtureCase(parseId, fixture));
    }
  }
  cases.push(...buildSyntheticCases(fixtures));

  const routes = new Set(fixtures.map((f) => f.env.upstream.route));
  const requiredRoutes = ['roothide', 'rootless'];
  const missingRoutes = requiredRoutes.filter((r) => !routes.has(r));

  // 五类互斥核对：计数与清单条目一致
  const mutualLeak = cases.filter((c) => {
    const r = c.result;
    if (!r || !r.counts || !Array.isArray(r.parsed)) return false;
    const total = r.counts.valid + r.counts.parse_failed + r.counts.type_mismatch + r.counts.read_failed;
    return total !== r.parsed.length;
  });

  const regression = runPriorRegression();
  const regressionFailed = Object.values(regression).some((v) => v !== 'passed');

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-06',
    evidenceNote: '全部为离线 fixture 合成样本；不构成 RootHide 真机验证，Rootless 结果不代表真机兼容。',
    summary: {
      total: cases.length,
      passed,
      failed,
      routesCovered: [...routes].sort(),
      missingRoutes,
      mutualLeakCount: mutualLeak.length,
      regression,
    },
    cases: cases.map((c) => ({
      parseId: c.parseId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-06-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-06 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`路线覆盖：[${[...routes].sort().join(', ')}]`);
  console.log(`前序回归：${JSON.stringify(regression)}`);
  if (missingRoutes.length) console.log(`缺失路线：${missingRoutes.join(', ')}`);
  if (mutualLeak.length) console.log(`互斥违例：${mutualLeak.length} 例`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.parseId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingRoutes.length === 0 && mutualLeak.length === 0 && !regressionFailed ? 0 : 1;
}

main();
