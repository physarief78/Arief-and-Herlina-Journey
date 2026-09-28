# Arief & Herlina Journey

A small place for the story of Arief and Herlina — two people who met at Unpad and chose to commit to each other.

**[Open the site →](https://physarief78.github.io/Arief-and-Herlina-Journey/)**

## What's inside

The site moves through three screens, with sakura petals and blossoms drifting through all of them.

1. **Cover** — *Arief & Herlina Journey* and a **Let's Get Started** button.
2. **Our story** — a photograph from Benteng Vredeburg, Yogyakarta, a short introduction, and a menu of chapters.
3. **A Commitment Letter** — the first chapter: a letter from Arief to Herlina, beside a 3D rose that blooms as it opens. Drag to turn her.

Some small touches:

- Click or tap anywhere, on any screen, for a burst of petals. They fly out in front of the page and then drift in behind it.
- There are no on-screen back buttons. The browser's or phone's own Back and Forward move between the three screens, each with its own transition.
- The layout adapts to phones: the photo stacks above the words, and the letter sits below the rose.
- The page asks search engines not to index it (`robots.txt` and a robots meta tag).

## Run locally

Open `index.html` in a browser, or serve the folder:

```sh
python devserver.py
```

## Editing

`index.html` is generated — edit `template_present.html` (page text, styling, and interaction) or `rose_geometry.js` (the rose), then rebuild. The generator has no Julia package dependencies; it inlines the template, the rose geometry, and the vendored Three.js runtime into one `index.html`:

```sh
julia rose_present.jl
node verify_geometry.js
```

- **Change the photo:** replace `assets/journey.jpg`, and update its caption in the template's `.photo` figure.
- **Add a chapter:** add another `.chapter` button inside the `.menu` in the template.

`build/golden.json` and `build/rose_params.json` are committed fixtures, so the geometry cross-check runs in CI with Node.js alone.

## Files

| File | Purpose |
|---|---|
| `index.html` | The generated site served by GitHub Pages |
| `template_present.html` | Page structure, text, styling, and interaction |
| `assets/journey.jpg` | The photograph on the story page |
| `rose_geometry.js` | Browser-side rose geometry |
| `rose_present.jl` | Generator and reference Julia geometry |
| `verify_geometry.js` | Julia/JavaScript geometry consistency check |
| `vendor/three.min.js` | Three.js runtime, inlined by the generator |
| `devserver.py` | Local preview server |
