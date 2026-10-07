# Arief & Herlina Journey

A record of the story of Arief and Herlina, who met at Universitas Padjadjaran (Unpad) and resolved to commit to one another.

**[Open the site →](https://physarief78.github.io/Arief-and-Herlina-Journey/)**

## What's inside

The site opens on a cover and an introduction, with two chapters from the contents. Sakura petals and blossoms drift through all of the screens.

1. **Cover** — *Arief & Herlina Journey* and a **Let's Get Started** button.
2. **Introduction** — a photograph from Benteng Vredeburg, Yogyakarta, a short introduction, and a list of contents.
3. **Chapter 1: A Commitment Letter** — a letter from Arief to Herlina, beside a 3D rose that blooms as it opens. Drag to turn it.
4. **Chapter 2: A Butterfly and a Rose** — an animated painting: the camera follows a swallowtail across the paper, pulls back as it lands on a red rose, and *For Beautiful Erlin — by Arief* writes itself beside it.

Some small touches:

- Click or tap anywhere, on any screen, for a burst of petals. They fly out in front of the page and then drift in behind it.
- There are no on-screen back buttons. The browser's or phone's own Back and Forward move between the screens, each with its own transition.
- The layout adapts to phones: the photo stacks above the words, and the letter sits below the rose.
- The page asks search engines not to index it (`robots.txt` and a robots meta tag).

## Run locally

Open `index.html` in a browser, or serve the folder:

```sh
python -m http.server
```

## Editing

`index.html` is generated. Edit `tools/template_present.html` (page text, styling, and interaction) or `tools/rose_geometry.js` (the rose), then rebuild from the repository root. The generator needs no Julia packages; it inlines the template, the rose geometry, and the vendored Three.js runtime into one `index.html`:

```sh
julia tools/rose_present.jl
node tools/verify_geometry.js
```

- **Change the photo:** replace `assets/journey.jpg`, and update its caption in the template's `.photo` figure.
- **Add an entry to the contents:** add another `.chapter` button inside the `.menu` in the template.
- **Chapter 2** is a standalone page, `chapters/butterfly-and-rose.html`, not generated. The landing page shows it full screen in a frame. Its message is set by `MESSAGE_LINE_1` and `MESSAGE_LINE_2` at the top of its script, and its handwriting font, Great Vibes, loads from Google Fonts (a system script font is used offline).

`tools/build/golden.json` and `tools/build/rose_params.json` are committed fixtures, so the geometry check runs on GitHub with Node.js alone.

## Files

| File | Purpose |
|---|---|
| `index.html` | The generated site served by GitHub Pages |
| `assets/journey.jpg` | The photograph on the introduction page |
| `chapters/butterfly-and-rose.html` | Chapter 2, the butterfly-and-rose animation |
| `robots.txt` | Asks search engines not to index the site |
| `tools/template_present.html` | Page structure, text, styling, and interaction |
| `tools/rose_geometry.js` | Browser-side rose geometry |
| `tools/rose_present.jl` | Generator and reference Julia geometry |
| `tools/verify_geometry.js` | Julia/JavaScript geometry consistency check |
| `tools/build/` | Fixtures for the geometry check |
| `tools/vendor/three.min.js` | Three.js runtime, inlined by the generator |
