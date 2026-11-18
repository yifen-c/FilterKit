/**
 * S1-08 统一模型 / JSON 导出 — 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十组夹具 → 校验输入/预期分离 → 跑 EXPORT-001~013 →
 * 核对模型结构、三层状态分离、来源/权限分离、证据保留、确定性排序与重复导出 → 生成报告。
 * 全部为离线 fixture 合成快照；不访问真实设备文件系统，不回写设备。
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { exportReport } = require('./exporter');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-08');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_CASE_MAP = {
  'export-full-roothide': ['EXPORT-001'],
  'export-rootless': ['EXPORT-002'],
  'export-partial-failures': ['EXPORT-003'],
  'export-conflict-mixed': ['EXPORT-004'],
  'export-dpkg-unavailable': ['EXPORT-005'],
  'export-unknown-profile': ['EXPORT-006'],
  'export-missing-upstream': ['EXPORT-007'],
  'export-evidence-preservation': ['EXPORT-008'],
  'export-determinism': ['EXPORT-009'],
  'export-state-separation': ['EXPORT-010'],
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

function sameSet(a, b) { return deepEqual([...(a || [])].sort(), [...(b || [])].sort()); }

function pluginByBase(report, base) {
  return report.plugins.find((p) => p.pluginID === base || p.pluginID.endsWith(`:${base}`) || p.name === base);
}

function comparePlugin(actual, expected, base) {
  const failures = [];
  const fields = ['pluginID', 'source', 'installed', 'configured', 'loaded'];
  for (const f of fields) {
    if (expected[f] !== undefined && !deepEqual(actual[f], expected[f])) {
      failures.push(`${base}.${f}: 实际=${JSON.stringify(actual[f])} 期望=${JSON.stringify(expected[f])}`);
    }
  }
  if (expected.permissionDecision !== undefined && actual.permission.decision !== expected.permissionDecision) {
    failures.push(`${base}.permission.decision: 实际=${actual.permission.decision} 期望=${expected.permissionDecision}`);
  }
  if (expected.validationStatus !== undefined && actual.validation.status !== expected.validationStatus) {
    failures.push(`${base}.validation.status: 实际=${actual.validation.status} 期望=${expected.validationStatus}`);
  }
  if (expected.filterBundles !== undefined && !deepEqual(actual.filter?.bundles, expected.filterBundles)) {
    failures.push(`${base}.filter.bundles: 实际=${JSON.stringify(actual.filter?.bundles)} 期望=${JSON.stringify(expected.filterBundles)}`);
  }
  if (expected.otherKeys !== undefined && !deepEqual(actual.filter?.otherKeys, expected.otherKeys)) {
    failures.push(`${base}.filter.otherKeys: 实际=${JSON.stringify(actual.filter?.otherKeys)} 期望=${JSON.stringify(expected.otherKeys)}`);
  }
  if (expected.skippedFieldCount !== undefined && actual.validation.skippedFields.length !== expected.skippedFieldCount) {
    failures.push(`${base}.skippedFields: 实际=${actual.validation.skippedFields.length} 期望=${expected.skippedFieldCount}`);
  }
  if (expected.ownership) {
    for (const [k, v] of Object.entries(expected.ownership)) {
      if (!deepEqual(actual.ownership[k], v)) failures.push(`${base}.ownership.${k}: 实际=${JSON.stringify(actual.ownership[k])} 期望=${JSON.stringify(v)}`);
    }
  }
  if (expected.ownershipDetailsConflictCount !== undefined) {
    const n = (actual.ownershipDetails?.conflicts || []).length;
    if (n !== expected.ownershipDetailsConflictCount) failures.push(`${base}.conflicts: 实际=${n} 期望=${expected.ownershipDetailsConflictCount}`);
  }
  if (expected.ownershipDetailsNote !== undefined) {
    const note = (actual.ownershipDetails?.notes || [])[0];
    if (note !== expected.ownershipDetailsNote) failures.push(`${base}.notes[0]: 实际=${note} 期望=${expected.ownershipDetailsNote}`);
  }
  return failures;
}

function compareResult(report, meta) {
  const expected = meta.expected || {};
  const failures = [];

  if (expected.profile && !deepEqual({ id: report.profile.id, route: report.profile.route }, expected.profile)) {
    failures.push(`profile: 实际=${JSON.stringify(report.profile)} 期望=${JSON.stringify(expected.profile)}`);
  }
  if (expected.environment) {
    for (const [k, v] of Object.entries(expected.environment)) {
      if (!deepEqual(report.environment[k], v)) failures.push(`environment.${k}: 实际=${JSON.stringify(report.environment[k])} 期望=${JSON.stringify(v)}`);
    }
  }
  if (expected.pluginCount !== undefined && report.plugins.length !== expected.pluginCount) {
    failures.push(`pluginCount: 实际=${report.plugins.length} 期望=${expected.pluginCount}`);
  }

  for (const [base, want] of Object.entries(expected.byBase || {})) {
    const actual = pluginByBase(report, base);
    if (!actual) { failures.push(`缺少插件条目 ${base}`); continue; }
    failures.push(...comparePlugin(actual, want, base));
  }

  if (expected.unknownReasons && !sameSet(report.unknownItems.map((x) => x.reason), expected.unknownReasons)) {
    failures.push(`unknownReasons: 实际=[${report.unknownItems.map((x) => x.reason).join(',')}] 期望=[${expected.unknownReasons.join(',')}]`);
  }
  if (expected.warningCodes && !sameSet(report.warnings.map((w) => w.code), expected.warningCodes)) {
    failures.push(`warningCodes: 实际=[${report.warnings.map((w) => w.code).join(',')}] 期望=[${expected.warningCodes.join(',')}]`);
  }
  return failures;
}

/** 全局安全核对：loaded 恒 unknown；permission 恒 undetermined；source 与 ownership.sourceType 一致。 */
function globalChecks(report) {
  const failures = [];
  for (const p of report.plugins) {
    if (p.loaded !== 'unknown') failures.push(`${p.pluginID}: loaded=${p.loaded}，应为 unknown`);
    if (p.permission.decision !== 'undetermined') failures.push(`${p.pluginID}: permission=${p.permission.decision}，应为 undetermined`);
    if (p.source !== p.ownership.sourceType) failures.push(`${p.pluginID}: source=${p.source} 与 ownership.sourceType=${p.ownership.sourceType} 不一致`);
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

function runFixtureCase(caseId, fixture) {
  const result = exportReport(fixture.env);
  const failures = [...compareResult(result, fixture.meta), ...globalChecks(result)];
  return { caseId, source: `fixture:${fixture.kind}`, evidenceType: 'fixture', passed: failures.length === 0, result, failures };
}

function buildSyntheticCases(fixtures) {
  const cases = [];

  // EXPORT-009 补充：相同快照两次导出，除 generatedAt 外深比较一致
  const det = fixtures.find((f) => f.kind === 'export-determinism');
  const r1 = exportReport({ ...det.env, generatedAt: '2026-11-15T01:00:00+08:00' });
  const r2 = exportReport({ ...det.env, generatedAt: '2026-11-15T02:00:00+08:00' });
  const strip = (r) => { const c = { ...r }; delete c.generatedAt; return c; };
  const detPassed = deepEqual(strip(r1), strip(r2));
  cases.push({
    caseId: 'EXPORT-009', source: 'synthetic:determinism', evidenceType: 'fixture',
    passed: detPassed, result: r1, failures: detPassed ? [] : ['两次导出除 generatedAt 外不一致'],
  });

  // EXPORT-011 补充：全量快照三层状态/归属-权限互斥复核
  const full = fixtures.find((f) => f.kind === 'export-full-roothide');
  const fr = exportReport(full.env);
  const mutexFailures = globalChecks(fr);
  cases.push({
    caseId: 'EXPORT-011', source: 'synthetic:state-mutex', evidenceType: 'fixture',
    passed: mutexFailures.length === 0, result: { pluginCount: fr.plugins.length }, failures: mutexFailures,
  });

  // EXPORT-012 补充：未取到项显式 null/unknown；证据标签为 fixture
  const ev = fixtures.find((f) => f.kind === 'export-evidence-preservation');
  const er = exportReport(ev.env);
  const evFailures = [];
  for (const p of er.plugins) {
    if (p.evidence.evidenceType !== 'fixture') evFailures.push(`${p.pluginID}: evidenceType 非 fixture`);
  }
  const missing = fixtures.find((f) => f.kind === 'export-missing-upstream');
  const mr = exportReport(missing.env);
  if (mr.environment.jailbreakType !== 'unknown') evFailures.push('缺失环境未置 unknown');
  cases.push({
    caseId: 'EXPORT-012', source: 'synthetic:evidence-null', evidenceType: 'fixture',
    passed: evFailures.length === 0, result: { plugins: er.plugins.length, missingPlugins: mr.plugins.length }, failures: evFailures,
  });

  return cases;
}

function runPriorRegression() {
  const stages = ['S1-01', 'S1-02', 'S1-03', 'S1-04', 'S1-05', 'S1-06', 'S1-07'];
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
    for (const caseId of FIXTURE_CASE_MAP[fixture.kind] || []) {
      cases.push(runFixtureCase(caseId, fixture));
    }
  }
  cases.push(...buildSyntheticCases(fixtures));

  const routes = new Set(fixtures.map((f) => f.env.upstream?.s103?.route || f.env.upstream?.s104?.route));
  const requiredRoutes = ['roothide', 'rootless'];
  const missingRoutes = requiredRoutes.filter((r) => !routes.has(r));

  const regression = runPriorRegression();
  const regressionFailed = Object.values(regression).some((v) => v !== 'passed');

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-08',
    evidenceNote: '全部为离线 fixture 合成快照；不构成真机验证。loaded 恒 unknown，permission 恒 undetermined，来源识别不产生管理授权。',
    summary: {
      total: cases.length,
      passed,
      failed,
      routesCovered: [...routes].sort(),
      missingRoutes,
      regression,
    },
    cases: cases.map((c) => ({
      caseId: c.caseId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-08-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-08 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`路线覆盖：[${[...routes].sort().join(', ')}]`);
  console.log(`前序回归：${JSON.stringify(regression)}`);
  if (missingRoutes.length) console.log(`缺失路线：${missingRoutes.join(', ')}`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.caseId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingRoutes.length === 0 && !regressionFailed ? 0 : 1;
}

main();
