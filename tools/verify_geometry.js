/*
 * verify_geometry.js -- does the JS port still agree with the Julia math?
 *
 * The page no longer ships Julia's computed vertices; it ships a JS
 * re-implementation of the formula and rebuilds the mesh in the browser.
 * That saves ~5 MB but introduces one real risk: two copies of the same
 * math that can silently drift apart. This is the check for that.
 *
 * rose_present.jl evaluates its original vectorised expressions and writes
 * a set of golden vertices to build/golden.json. This recomputes the same
 * grid positions through rose_geometry.js and compares them.
 *
 *   julia tools/rose_present.jl   &&   node tools/verify_geometry.js
 *
 * Exits non-zero on disagreement, so it can gate a rebuild.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const Rose = require('./rose_geometry.js');

// Julia builds its theta/openness axes with TwicePrecision range arithmetic;
// the JS port uses a plain lerp. The two agree to well under this, but they
// are not required to be bit-identical.
const TOL = 1e-9;

const here = __dirname;
const read = (p, what) => {
  const f = path.join(here, p);
  if (!fs.existsSync(f)) {
    console.error(`missing ${what}: ${p}\n  run:  julia tools/rose_present.jl`);
    process.exit(2);
  }
  return JSON.parse(fs.readFileSync(f, 'utf8'));
};

const params = read('build/rose_params.json', 'parameters');
const golden = read('build/golden.json', 'golden vertices');

const p = Rose.params(params);

console.log('verify_geometry -- Julia vs JavaScript');
console.log(`  grid ${p.nr} x ${p.nT} = ${(p.nr * p.nT).toLocaleString()} vertices`);
console.log(`  tolerance ${TOL}\n`);
console.log('  stage        ol                  samples   max abs err   worst vertex');

let worstOverall = 0;
let failures = 0;

for (const stage of golden.stages) {
  let worst = 0, worstAt = null;

  for (const s of stage.samples) {
    const v = Rose.vertexAt(p, stage.ol, s.i, s.j);
    // Compare all four quantities; c is derived, but a mismatch there would
    // catch a sign error that happens to cancel in x/y/z.
    const errs = [
      Math.abs(v.x - s.x), Math.abs(v.y - s.y),
      Math.abs(v.z - s.z), Math.abs(v.c - s.c)
    ];
    const e = Math.max(...errs);
    if (e > worst) { worst = e; worstAt = s; }
  }

  const ok = worst <= TOL;
  if (!ok) failures++;
  if (worst > worstOverall) worstOverall = worst;

  const olStr = `[${stage.ol[0].toFixed(3)}, ${stage.ol[1].toFixed(3)}]`;
  console.log(
    `  ${ok ? 'ok  ' : 'FAIL'} ${stage.name.padEnd(9)} ${olStr.padEnd(16)} ` +
    `${String(stage.samples.length).padStart(6)}   ${worst.toExponential(2).padStart(11)}` +
    (worstAt ? `   i=${worstAt.i} j=${worstAt.j}` : '')
  );
}

// The mesh the renderer actually uploads comes from build(), not vertexAt().
// They share vertexFromBasis, but confirm the buffer packing too -- an
// off-by-one in the k = j*nr + i indexing would not show up above.
const mesh = Rose.build(p, golden.stages[0].ol);
let packErr = 0;
for (const s of golden.stages[0].samples) {
  const k3 = (s.j * p.nr + s.i) * 3;
  packErr = Math.max(packErr,
    Math.abs(mesh.pos[k3] - s.x),      // Float32 storage, so ~1e-7 is expected
    Math.abs(mesh.pos[k3 + 1] - s.y),
    Math.abs(mesh.pos[k3 + 2] - s.z));
}

const idx = Rose.indices(p);
const expectIdx = (p.nr - 1) * (p.nT - 1) * 6;
const idxOk = idx.length === expectIdx && idx.every(v => v < p.nr * p.nT);

console.log(`\n  buffer packing   max err ${packErr.toExponential(2)}  (Float32, ~1e-7 expected)`);
console.log(`  index buffer     ${idx.length.toLocaleString()} indices, ` +
            `${(expectIdx / 6).toLocaleString()} quads  ${idxOk ? 'ok' : 'FAIL'}`);

// ---------------------------------------------------------------------
// Grid normals vs three.js. RoseGeometry.normals() replaces
// computeVertexNormals() for speed; confirm it still points the same way.
// The two are not expected to be identical -- three.js area-weights face
// normals, this differentiates the surface directly -- so compare direction.
// ---------------------------------------------------------------------
let normalReport = 'skipped (vendor/three.min.js not found)';
const threePath = path.join(here, 'vendor', 'three.min.js');
if (fs.existsSync(threePath)) {
  const vm = require('vm');
  const ctx = { console: { warn() {}, log() {}, error() {} } };
  ctx.window = ctx; ctx.self = ctx;
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(threePath, 'utf8'), ctx);
  const THREE = ctx.THREE;

  const ol = golden.stages[golden.stages.length - 1].ol;
  const m = Rose.build(p, ol);

  const g = new THREE.BufferGeometry();
  g.setIndex(new THREE.BufferAttribute(Rose.indices(p), 1));
  g.setAttribute('position', new THREE.BufferAttribute(m.pos.slice(), 3));
  g.computeVertexNormals();
  const ref = g.attributes.normal.array;

  const mine = Rose.normals(p, m);
  let flipped = 0, agree = 0, counted = 0, degenerate = 0;
  for (let k = 0; k < m.n; k++) {
    const k3 = k * 3;
    // Row i = 0 is the flower's centre, where R = 0 collapses every column
    // onto the origin. Those vertices are coincident and their triangles have
    // zero area, so neither implementation has a normal to get right. Skip
    // them rather than let them dominate the score.
    if (k % p.nr === 0) { degenerate++; continue; }
    const rl = Math.hypot(ref[k3], ref[k3 + 1], ref[k3 + 2]);
    if (rl < 1e-6) { degenerate++; continue; }
    const dot = (mine[k3] * ref[k3] + mine[k3 + 1] * ref[k3 + 1] + mine[k3 + 2] * ref[k3 + 2]) / rl;
    counted++;
    if (dot < 0) flipped++;
    if (Math.abs(dot) > 0.98) agree++;
  }
  const pctAgree = 100 * agree / counted;
  const pctFlip = 100 * flipped / counted;
  normalReport = `${pctAgree.toFixed(1)}% within 11 deg, ${pctFlip.toFixed(2)}% inverted ` +
                 `(${degenerate.toLocaleString()} degenerate centre verts excluded)`;
  if (pctFlip > 50) {
    console.error(`\n  normals   ${normalReport}  <- WINDING INVERTED`);
    process.exit(1);
  }
}
console.log(`  grid normals     ${normalReport}`);

if (failures || !idxOk || packErr > 1e-5) {
  console.error(`\nFAILED -- the JS port has drifted from rose_present.jl`);
  process.exit(1);
}
console.log(`\nPASS -- max disagreement ${worstOverall.toExponential(2)} across ` +
            `${golden.stages.reduce((n, s) => n + s.samples.length, 0)} golden vertices`);
