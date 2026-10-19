# CATALYST 2026

The flagship Leadership Development Seminar by AIESEC in SLIIT.

A responsive, crimson-and-cream site inspired by the supplied Japanese warrior reference. Features locally hosted fonts, an original SVG samurai, a scroll-controlled armor transformation, accessible motion controls, and an introduction to the Catalyst experience.

## Develop

Requires Node.js 22.12 or newer. Install dependencies with `npm install`.

```sh
npm install
npm run dev
```

Open http://localhost:5173. The home page is `index.html`; the marketplace is `marketplace.html`.

## Build

```sh
npm run build
```

Upload the contents of `dist/` to a static host. Both pages use relative asset paths.

## Content

Jōkamachi intentionally contains only its title and shared navigation. No products, prices, ordering, or payment integration have been added. The homepage does not announce an unconfirmed 2026 date or venue.

Edit content in the HTML files, presentation in `styles.css`, and the GSAP scroll sequence in `src/hero.jsx`. Illustration assets and fonts are served locally from `assets/`. Fonts: Anton and Barlow Condensed, distributed under the SIL Open Font License; see the license files in `assets/`.

## Scroll transformation

The React hero uses one GSAP timeline, pinned and scrubbed by ScrollTrigger. `src/Character.jsx` defines aligned vector layers and MorphSVG path targets. Hair, helmet base, facial features, and clothing morph through overlapping stages; local clips grow the horns, teeth, and neck guard. The pupils stay anchored, and the background typography moves upward with the scroll timeline. The final illustration scales by 4% around the nose. Scrolling backward reverses the same timeline.

Timing uses a normalized 0–1 timeline in `src/hero.jsx`; individual shape timings live beside their paths in `src/Character.jsx`. Reduced-motion preferences and the static-view control show the finished illustration without pinning or extra scroll distance. React effect cleanup removes the timeline and pin on preference changes or unmount. Vite builds both HTML pages.

Ambient eye blinks and drifting leaves run independently of scroll progress. Links, buttons, and accordion controls split diagonally as a katana sweeps across them, with a steel glint and expanding impact flash. Internal navigation follows after the 460ms sword strike; modified clicks retain native behavior. Reduced-motion preferences disable blinking, drifting leaves, and slicing.
