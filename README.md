# HBD Erlin

An interactive birthday rose for Erlin, rendered in the browser with Three.js. The page is self-contained, works offline, and includes light and dark themes with a remembered theme preference.

[Open the birthday page](https://physarief78.github.io/HBD-Erlin/)

## Run locally

Open `index.html` directly, or start the small local server:

```sh
python devserver.py
```

## Rebuild

The generator has no Julia package dependencies. It combines the page template, rose geometry, and vendored Three.js runtime into one `index.html`:

```sh
julia rose_present.jl
node verify_geometry.js
```

`build/golden.json` and `build/rose_params.json` are committed fixtures so the geometry cross-check can run in CI using Node.js alone.

## Main files

- `index.html` — generated, self-contained site served by GitHub Pages
- `template_present.html` — page structure, styling, and interaction source
- `rose_present.jl` — generator and reference Julia geometry
- `rose_geometry.js` — browser-side geometry implementation
- `verify_geometry.js` — Julia/JavaScript geometry consistency check
- `vendor/three.min.js` — vendored rendering runtime embedded by the generator

The site asks search engines not to index it through both `robots.txt` and an HTML robots meta tag.
