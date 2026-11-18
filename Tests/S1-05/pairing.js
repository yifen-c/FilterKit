/**
 * S1-05 插件配对 — 离线校验配对模块（测试 harness）。
 *
 * 规则对齐 Spec/Stage-1/S1-05-Plugin-Pairing.md。
 * 本模块为 Stage 1 离线验证用最小实现，非 App 运行时；后续迁移 Core/Adapters。
 * 配对输入为 S1-04 清单快照，虚拟信号注入，不访问真实设备文件系统。
 *
 * 口径：dylib 驱动；剥离 .dylib 派生 .plist；同目录精确文件名、大小写敏感；
 * paired/missing_plist/orphan_plist/ambiguous/uncertain 互斥；不读 plist 内容。
 */

function baseOfDylib(name) {
  return name.endsWith('.dylib') ? name.slice(0, name.length - 6) : null;
}

function joinPath(dir, name) {
  if (!dir) return null;
  return dir.endsWith('/') ? dir + name : dir + '/' + name;
}

function itemPath(sourceDirectory, item) {
  return item.path || joinPath(sourceDirectory, item.name);
}

function pairInventory(env) {
  const upstream = (env && env.upstream) || {};
  const inventory = (env && env.inventory) || {};
  const route = upstream.route || 'unknown';
  const sourceDirectory = upstream.sourceDirectory ?? null;
  const warnings = [];

  let status;
  const pairs = [];
  const missingPlist = [];
  const orphanPlist = [];
  const ambiguous = [];
  const uncertain = [];

  if (sourceDirectory === null) {
    status = 'unresolved';
    warnings.push('inventory_unresolved');
  } else if (inventory.enumerable === false) {
    status = 'enumeration_failed';
    warnings.push('inventory_unresolved');
  } else {
    const all = Array.isArray(inventory.items) ? inventory.items : [];
    // 只消费本路线目录清单；跨路线/外目录陷阱条目不参与配对
    const items = all.filter((i) => i.foreign !== true);
    const dylibs = items.filter((i) => i.kind === 'dylib');
    const plists = items.filter((i) => i.kind === 'plist');
    const consumed = new Set();

    for (const dylib of dylibs) {
      const base = baseOfDylib(dylib.name);
      const dylibPath = itemPath(sourceDirectory, dylib);

      if (dylib.entryStatus && dylib.entryStatus !== 'ok') {
        // 受限 dylib：留置同名 plist，不判孤儿，配对关系记不确定
        const held = plists.filter((p) => p.name === base + '.plist');
        held.forEach((p) => consumed.add(itemPath(sourceDirectory, p)));
        uncertain.push({ path: dylibPath, reason: dylib.entryStatus });
        continue;
      }

      const expectedName = base + '.plist';
      const matches = plists.filter((p) => p.name === expectedName); // 大小写敏感精确匹配

      if (matches.length === 0) {
        missingPlist.push({
          base,
          dylibPath,
          pairing: 'missing_plist',
          dylibIsSymlink: Boolean(dylib.isSymlink),
        });
      } else if (matches.length === 1) {
        const plist = matches[0];
        const plistPath = itemPath(sourceDirectory, plist);
        consumed.add(plistPath);
        if (plist.entryStatus && plist.entryStatus !== 'ok') {
          uncertain.push({ path: plistPath, reason: plist.entryStatus });
          continue;
        }
        pairs.push({
          base,
          dylibPath,
          plistPath,
          pairing: 'paired',
          dylibIsSymlink: Boolean(dylib.isSymlink),
          plistIsSymlink: Boolean(plist.isSymlink),
          status: 'ok',
        });
      } else {
        matches.forEach((p) => consumed.add(itemPath(sourceDirectory, p)));
        ambiguous.push({
          base,
          candidates: matches.map((p) => itemPath(sourceDirectory, p)),
        });
      }
    }

    for (const plist of plists) {
      const plistPath = itemPath(sourceDirectory, plist);
      if (consumed.has(plistPath)) continue;
      if (plist.entryStatus && plist.entryStatus !== 'ok') {
        uncertain.push({ path: plistPath, reason: plist.entryStatus });
        continue;
      }
      orphanPlist.push({
        plistPath,
        pairing: 'orphan_plist',
        reason: 'missing_dylib',
      });
    }

    const partial = uncertain.length > 0;
    status = partial ? 'partial' : 'enumerated';
    if (partial) warnings.push('partial_pairing');
  }

  pairs.sort((a, b) => (a.base < b.base ? -1 : a.base > b.base ? 1 : 0));
  missingPlist.sort((a, b) => (a.base < b.base ? -1 : a.base > b.base ? 1 : 0));
  orphanPlist.sort((a, b) => (a.plistPath < b.plistPath ? -1 : a.plistPath > b.plistPath ? 1 : 0));
  ambiguous.sort((a, b) => (a.base < b.base ? -1 : a.base > b.base ? 1 : 0));

  const counts = {
    paired: pairs.length,
    missing_plist: missingPlist.length,
    orphan_plist: orphanPlist.length,
    ambiguous: ambiguous.length,
    uncertain: uncertain.length,
  };

  return {
    route,
    sourceDirectory,
    pairs,
    missingPlist,
    orphanPlist,
    ambiguous,
    uncertain,
    counts,
    warnings,
    status,
  };
}

module.exports = { pairInventory, baseOfDylib, joinPath, itemPath };
