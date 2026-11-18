/**
 * S1-07 插件来源识别 — 离线验证执行器（测试 harness，非 App 运行时）。
 *
 * 流程：读取十二组夹具 → 校验输入/预期分离 → 跑 OWN-001~013 →
 * 核对归属互斥、分文件归属、冲突不选边、标记不覆盖包归属、unknown 安全降级、确定性 → 生成报告。
 * 全部为离线 fixture 合成信号；不访问真实设备文件系统，不读/写 dpkg 数据库。
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { identifySources } = require('./resolver');

const ROOT = path.join(__dirname, '..', '..');
const FIXTURE_DIR = path.join(ROOT, 'Tests', 'Fixtures', 'S1-07');
const REPORT_DIR = path.join(__dirname, 'report');

const FIXTURE_CASE_MAP = {
  'src-dpkg-owned': ['OWN-001'],
  'src-dpkg-multi-file': ['OWN-002'],
  'src-filterkit-managed': ['OWN-003'],
  'src-manual-import': ['OWN-004'],
  'src-unknown': ['OWN-005'],
  'src-dpkg-conflict': ['OWN-006'],
  'src-mixed-ownership': ['OWN-007'],
  'src-dpkg-unavailable': ['OWN-008'],
  'src-marker-corrupt': ['OWN-009'],
  'src-marker-absent': ['OWN-010'],
  'src-route-guard': ['OWN-011'],
  'determinism': ['OWN-012'],
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

/** 按预期子集比对实际条目；notesIncludes 为必含备注子串。 */
function compareEntry(actual, expected, base) {
  const failures = [];
  const fields = ['sourceType', 'ownership', 'packageID', 'packageVersion', 'architecture', 'listPath', 'confidence', 'writablePolicy', 'fileOwnership', 'markers'];
  for (const f of fields) {
    if (expected[f] !== undefined && !deepEqual(actual[f], expected[f])) {
      failures.push(`${base}.${f}: 实际=${JSON.stringify(actual[f])} 期望=${JSON.stringify(expected[f])}`);
    }
  }
  if (expected.notesIncludes) {
    for (const note of expected.notesIncludes) {
      if (!(actual.notes || []).includes(note)) failures.push(`${base}.notes 缺少 ${note}，实际=${JSON.stringify(actual.notes)}`);
    }
  }
  return failures;
}

function compareResult(result, meta) {
  const expected = meta.expected || {};
  const expectedWarnings = meta.expectedWarnings || [];
  const failures = [];

  for (const [field, actual, want] of [
    ['route', result.route, expected.route],
    ['sourceDirectory', result.sourceDirectory, expected.sourceDirectory],
    ['status', result.status, expected.status],
    ['counts', result.counts, expected.counts],
  ]) {
    if (!deepEqual(actual, want)) failures.push(`${field}: 实际=${JSON.stringify(actual)} 期望=${JSON.stringify(want)}`);
  }

  const byBase = {};
  for (const s of result.sources) byBase[s.base] = s;
  for (const [base, want] of Object.entries(expected.byBase || {})) {
    const actual = byBase[base];
    if (!actual) { failures.push(`缺少条目 ${base}`); continue; }
    failures.push(...compareEntry(actual, want, base));
  }

  if (!sameSet(result.warnings, expectedWarnings)) {
    failures.push(`warnings: 实际=[${result.warnings.join(',')}] 期望=[${expectedWarnings.join(',')}]`);
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

function runFixtureCase(caseId, fixture) {
  const result = identifySources(fixture.env);
  const failures = compareResult(result, fixture.meta);
  return {
    caseId,
    source: `fixture:${fixture.kind}`,
    evidenceType: 'fixture',
    passed: failures.length === 0,
    result,
    failures,
  };
}

function buildSyntheticCases(fixtures) {
  const cases = [];

  // OWN-012 补充：相同输入重复识别，归属/owners/策略/计数深比较一致
  const det = fixtures.find((f) => f.kind === 'determinism');
  const r1 = identifySources(det.env);
  const r2 = identifySources(det.env);
  const detPassed = deepEqual(r1, r2);
  cases.push({
    caseId: 'OWN-012',
    source: 'synthetic:determinism',
    evidenceType: 'fixture',
    passed: detPassed,
    result: r1,
    failures: detPassed ? [] : ['重复识别结果不一致'],
  });

  // 路线隔离：上游未定位时不得回退 /var/jb 或 / 清单路径
  const guard = fixtures.find((f) => f.kind === 'src-route-guard');
  const gr = identifySources(guard.env);
  const leak = gr.sources.some((s) => /^\/var\/jb|^\/usr\//.test(s.dylibPath || ''));
  const guardPassed = gr.sourceDirectory === null && gr.sources.length === 0 && !leak;
  cases.push({
    caseId: 'OWN-011',
    source: 'synthetic:route-isolation',
    evidenceType: 'fixture',
    passed: guardPassed,
    result: { sourceDirectory: gr.sourceDirectory, counts: gr.counts },
    failures: guardPassed ? [] : ['未定位时回退了其他路线路径'],
  });

  return cases;
}

function runPriorRegression() {
  const stages = ['S1-01', 'S1-02', 'S1-03', 'S1-04', 'S1-05', 'S1-06'];
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

  const routes = new Set(fixtures.map((f) => f.env.upstream.route));
  const requiredRoutes = ['roothide', 'rootless', 'rootful'];
  const missingRoutes = requiredRoutes.filter((r) => !routes.has(r));

  // 归属类别互斥核对：计数与清单条目一致
  const mutualLeak = cases.filter((c) => {
    const r = c.result;
    if (!r || !r.counts || !Array.isArray(r.sources)) return false;
    const total = r.counts.owned_package + r.counts.filterkit_managed + r.counts.manual_import +
      r.counts.unknown + r.counts.conflict + r.counts.dpkg_unavailable;
    return total !== r.sources.length;
  });

  const regression = runPriorRegression();
  const regressionFailed = Object.values(regression).some((v) => v !== 'passed');

  const passed = cases.filter((c) => c.passed).length;
  const failed = cases.length - passed;

  const report = {
    schemaVersion: '0.1.0',
    generatedAt: new Date().toISOString(),
    stage: 'Stage 1 / S1-07',
    evidenceNote: '全部为离线 fixture 合成信号；不构成 RootHide 真机验证，Rootless/Rootful 结果不代表真机兼容。来源识别不产生管理授权结论。',
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
      caseId: c.caseId,
      source: c.source,
      evidenceType: c.evidenceType,
      passed: c.passed,
      failures: c.failures,
      result: c.result,
    })),
  };

  fs.mkdirSync(REPORT_DIR, { recursive: true });
  const reportPath = path.join(REPORT_DIR, 'S1-07-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`S1-07 离线验证：${passed}/${cases.length} 通过，${failed} 失败`);
  console.log(`路线覆盖：[${[...routes].sort().join(', ')}]`);
  console.log(`前序回归：${JSON.stringify(regression)}`);
  if (missingRoutes.length) console.log(`缺失路线：${missingRoutes.join(', ')}`);
  if (mutualLeak.length) console.log(`互斥违例：${mutualLeak.length} 例`);
  for (const c of cases) if (!c.passed) console.log(`  ✗ ${c.caseId}: ${c.failures.join('; ')}`);
  console.log(`报告：${path.relative(ROOT, reportPath)}`);

  process.exitCode = failed === 0 && missingRoutes.length === 0 && mutualLeak.length === 0 && !regressionFailed ? 0 : 1;
}

main();
