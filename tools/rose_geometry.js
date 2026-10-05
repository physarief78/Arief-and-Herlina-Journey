/*
 * rose_geometry.js - the rose surface, ported from the original Julia model
 *
 * This is the SINGLE source of the JavaScript geometry. It is loaded by
 * verify_geometry.js (Node) and inlined into the generated page by
 * rose_present.jl. Do not copy this math anywhere else -- if it exists in two
 * places it will drift, and `npm`-free as this project is, nothing would catch it.
 *
 * rose_present.jl keeps the original vectorised expressions untouched, so
 * the cross-check compares this port against the real thing rather than against
 * a restatement of itself.
 *
 * Bloom is driven entirely by `ol` = [inner, outer] openness:
 *   [0.05, 0.25] tight bud     [0.20, 1.02] open rose     [0.25, 1.40] reflexed
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.RoseGeometry = factory();
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  // Matches the original Julia model exactly.
  var DEFAULTS = { ppr: 3.6, nr: 30, pr: 30, pn: 40, pf: 2.0, ps: 1.25 };

  // Bloom keyframes, from the openness ranges of the original Julia render.
  var STAGES = {
    bud:      [0.05, 0.25],
    cracking: [0.10, 0.50],
    opening:  [0.15, 0.75],
    open:     [0.20, 1.02],   // a fully open rose
    bloom:    [0.22, 1.10],
    reflexed: [0.25, 1.40]
  };

  function params(over) {
    var p = {}, k;
    for (k in DEFAULTS) p[k] = DEFAULTS[k];
    if (over) for (k in over) if (over[k] !== undefined) p[k] = over[k];
    p.nT = p.pn * p.pr + 1;          // columns along theta
    p.tMax = p.pn * ((1 / p.ppr) * Math.PI * 2);
    return p;
  }

  // Julia's mod() is always non-negative; JS % is not. ppr*theta is >= 0 here,
  // but be explicit so a negative ppr can't silently produce a mirrored petal.
  function pmod(a, m) { return ((a % m) + m) % m; }

  function lerp(a, b, n, i) { return n === 1 ? a : a + (b - a) * (i / (n - 1)); }

  /* Everything that depends only on the column index j.
   * Hoisting this out of the row loop is what keeps a full rebuild at ~0.4 ms. */
  function columnBasis(p, ol, j) {
    var th  = lerp(0, p.tMax, p.nT, j);
    var u   = lerp(ol[0], ol[1], p.nT, j);
    var phi = (Math.PI / 2) * u * u;
    var inner = 1 - pmod(p.ppr * th, 2 * Math.PI) / Math.PI;
    var t1 = p.ps * inner * inner - 0.25;
    return { sp: Math.sin(phi), cp: Math.cos(phi),
             st: Math.sin(th),  ct: Math.cos(th),
             m: 1 - (t1 * t1) / 2 };
  }

  /* One vertex, given a column basis and row index i. Returns doubles.
   * build() and vertexAt() both route through here so they cannot disagree. */
  function vertexFromBasis(p, b, i) {
    var R  = lerp(0, 1, p.nr, i);
    var w  = 1.28 * R - 1;
    var y  = p.pf * R * R * w * w * b.sp;
    var R2 = b.m * (R * b.sp) + y * b.cp;
    var x  = R2 * b.st, z2 = R2 * b.ct, z = b.m * (R * b.cp - y * b.sp);
    // The Julia model names these X, Y, Z with Y = R2*cos(theta). Kept identical here;
    // the renderer does the Z-up -> Y-up swap at upload time, not in the math.
    return { x: x, y: z2, z: z, c: Math.sqrt(x * x + z2 * z2 + z * z) };
  }

  /* Single vertex by grid index -- used by the cross-check. */
  function vertexAt(p, ol, i, j) {
    return vertexFromBasis(p, columnBasis(p, ol, j), i);
  }

  /* Full mesh. Writes into `out` when supplied so the render loop can rebuild
   * in place every frame without allocating. Vertex k = j*nr + i. */
  function build(p, ol, out) {
    var n = p.nr * p.nT;
    if (!out || out.n !== n) {
      out = { n: n, nr: p.nr, nT: p.nT,
              pos: new Float32Array(n * 3), c: new Float32Array(n),
              cMin: 0, cMax: 0, zMin: 0, zMax: 0, rMax: 0 };
    }
    var pos = out.pos, cc = out.c;
    var cMin = Infinity, cMax = -Infinity;
    var zMin = Infinity, zMax = -Infinity, r2Max = 0;
    for (var j = 0; j < p.nT; j++) {
      var b = columnBasis(p, ol, j), base = j * p.nr;
      for (var i = 0; i < p.nr; i++) {
        var v = vertexFromBasis(p, b, i), k = base + i, k3 = k * 3;
        pos[k3] = v.x; pos[k3 + 1] = v.y; pos[k3 + 2] = v.z;
        cc[k] = v.c;
        if (v.c < cMin) cMin = v.c;
        if (v.c > cMax) cMax = v.c;
        // The flower grows upward from z = 0 and only reflexes below it once
        // it is well open, so its centre moves during the bloom. The renderer
        // needs these to keep it framed instead of drifting out of shot.
        if (v.z < zMin) zMin = v.z;
        if (v.z > zMax) zMax = v.z;
        var r2 = v.x * v.x + v.y * v.y;
        if (r2 > r2Max) r2Max = r2;
      }
    }
    out.cMin = cMin; out.cMax = cMax;
    out.zMin = zMin; out.zMax = zMax; out.rMax = Math.sqrt(r2Max);
    return out;
  }

  /* Vertex normals, computed from the grid rather than from the triangles.
   *
   * three.js's computeVertexNormals() walks the 208,800-entry index buffer
   * accumulating face normals, which measured 6-12 ms here -- most of a 60 fps
   * frame, and the bloom rebuilds every frame. This is the same surface
   * differentiated directly: cross the two parameter tangents at each grid
   * point, central differences inside, one-sided at the edges. O(n) with no
   * index traversal, and it lands under a millisecond.
   *
   * Sign is chosen to match the triangle winding in indices() below. */
  function normals(p, mesh, out) {
    var nr = p.nr, nT = p.nT, n = nr * nT, pos = mesh.pos;
    if (!out || out.length !== n * 3) out = new Float32Array(n * 3);

    // Note: mod(ppr*theta, 2pi) is a sawtooth, but the surface is NOT
    // discontinuous at the petal edges -- m depends on inner^2, and the
    // sawtooth jumps between -1 and +1, which square to the same value. So a
    // plain central difference is safe across a seam; special-casing it only
    // makes the tangent less accurate.
    for (var j = 0; j < nT; j++) {
      var jm = j > 0 ? j - 1 : j, jp = j < nT - 1 ? j + 1 : j;
      for (var i = 0; i < nr; i++) {
        var im = i > 0 ? i - 1 : i, ip = i < nr - 1 ? i + 1 : i;

        var a = (j * nr + ip) * 3, b = (j * nr + im) * 3;    // tangent along r
        var ux = pos[a] - pos[b], uy = pos[a + 1] - pos[b + 1], uz = pos[a + 2] - pos[b + 2];

        var c = (jp * nr + i) * 3, d = (jm * nr + i) * 3;    // tangent along theta
        var vx = pos[c] - pos[d], vy = pos[c + 1] - pos[d + 1], vz = pos[c + 2] - pos[d + 2];

        var nx = uy * vz - uz * vy,
            ny = uz * vx - ux * vz,
            nz = ux * vy - uy * vx;

        var len = Math.sqrt(nx * nx + ny * ny + nz * nz);
        var k3 = (j * nr + i) * 3;
        if (len > 1e-12) {
          out[k3] = nx / len; out[k3 + 1] = ny / len; out[k3 + 2] = nz / len;
        } else {
          // Degenerate at the very centre of the flower, where the surface
          // pinches to a point and both tangents vanish. Point it up.
          out[k3] = 0; out[k3 + 1] = 0; out[k3 + 2] = 1;
        }
      }
    }
    return out;
  }

  /* Triangle indices for the nr x nT grid. Topology never changes during the
   * bloom, so this is built once. 36,030 verts needs 32-bit indices. */
  function indices(p) {
    var quads = (p.nr - 1) * (p.nT - 1);
    var idx = new Uint32Array(quads * 6), o = 0;
    for (var j = 0; j < p.nT - 1; j++) {
      for (var i = 0; i < p.nr - 1; i++) {
        var a = j * p.nr + i, b = a + 1, c = a + p.nr, d = c + 1;
        idx[o++] = a; idx[o++] = b; idx[o++] = d;
        idx[o++] = a; idx[o++] = d; idx[o++] = c;
      }
    }
    return idx;
  }

  return { DEFAULTS: DEFAULTS, STAGES: STAGES, params: params,
           build: build, indices: indices, normals: normals, vertexAt: vertexAt };
}));
