# Arief & Herlina Journey

A small site for the story of Arief and Herlina. It opens on a title screen, moves to a landing page with a photograph, an introduction and a menu of chapters, and the first chapter is a commitment letter from Arief to Herlina, presented beside an interactive rose rendered in the browser with Three.js.

[Open the site](https://physarief78.github.io/Arief-and-Herlina-Journey/)

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

- `index.html` — generated site served by GitHub Pages (Three.js is inlined; the landing photo is loaded from `assets/`)
- `assets/journey.jpg` — the landing-page photograph
- `template_present.html` — page structure, styling, and interaction source
- `rose_present.jl` — generator and reference Julia geometry
- `rose_geometry.js` — browser-side geometry implementation
- `verify_geometry.js` — Julia/JavaScript geometry consistency check
- `vendor/three.min.js` — vendored rendering runtime embedded by the generator

The site asks search engines not to index it through both `robots.txt` and an HTML robots meta tag.
