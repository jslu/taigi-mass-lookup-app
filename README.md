# Taigi Mass Lookup

Paste a 台語文 passage, get sentence-by-sentence 漢字 ↔ Tâi-lô conversion with four display layouts (Ruby / Stacked / Side-by-side / Table) and a tone-mode toggle (diacritic ↔ numeric).

Conversions come from the [意傳科技 ithuan](https://suisiann.ithuan.tw/) `tau` endpoint, which is statistical / corpus-based — verify against a dictionary for important uses.

## Run

```sh
asdf install   # installs Elm 0.19.3 per .tool-versions
npm install
npm run build   # compiles src/Main.elm -> main.js
python3 serve.py
# → http://localhost:8000
```

`serve.py` is a stdlib-only dev server that serves the static files in this
directory and proxies `POST /api/tau` to `https://hokbu.ithuan.tw/tau`. The
proxy is necessary because the upstream API's CORS policy only allows
requests from `suisiann.ithuan.tw`.

Re-run `npm run build` (or `elm make src/Main.elm --output=main.js --optimize`)
after editing any `src/*.elm` file — there's no watch mode wired up yet.

## Tests

```sh
npm test   # elm-test over tests/*.elm
```

## Files

- `index.html` — entry point; loads the compiled `main.js` and wires up two
  JS ports: `saveTweaks` (persists layout/tone preference to
  `localStorage`) and `copyToClipboard` (`navigator.clipboard.writeText`).
  The initial preference is read synchronously and passed in as Elm flags.
- `src/Main.elm` — root `Browser.element` program: model, update, view for
  the input textarea, sentence results list (4 layouts), layout/tone
  controls, and word popover.
- `src/Convert.elm` — pure sentence splitting + ithuan `分詞` token parsing
  (`splitSentences`, `parseFenchi`, `isPunct`).
- `src/Tailo.elm` — pure Tâi-lô tone-mark ↔ numeric conversion helpers.
- `src/Tokens.elm` — `Layout`/`ToneMode` <-> `String` codecs shared between
  the model's `localStorage` flags and the UI.
- `src/Ports.elm` — the two outbound ports (`saveTweaks`, `copyToClipboard`).
- `tests/TailoTest.elm`, `tests/ConvertTest.elm` — `elm-test` unit tests for
  the pure modules, including round-trip and known-quirk regression cases.
- `main.js` — compiled output of `src/Main.elm` (checked in for convenience;
  regenerate with `npm run build`).
- `styles.css` — app-specific styles (unchanged from the original React app
  — the Elm view reuses the same class names).
- `lib/unifi-tokens.css` — design tokens (colors, type, spacing).
- `lib/fonts/Inter-*.ttf` — Inter variable fonts.
- `serve.py` — dev server with `/api/tau` proxy (framework-agnostic, no
  changes needed for the Elm rewrite).
- `functions/api/tau.js` — Cloudflare Pages Function, same `/api/tau` proxy
  for production deploys. Not part of the UI rewrite.

## History

This app was originally a React 18 + in-browser Babel app (`app.jsx`,
`sentence-row.jsx`, `sentence-layouts.jsx`, `convert.js`, `tailo.js`,
loaded via CDN `<script>` tags, no build step). It was rewritten to Elm on
the `refactor/migrate-to-elm` branch; the original JS files were removed
once the Elm app reached feature parity (verified with a headless-browser
smoke test exercising all 4 layouts, both tone modes, word popover, and
copy-all/copy-line).

## Notes

- Per-word popover currently shows han + Tâi-lô only. A detailed
  dictionary lookup is stubbed (`No detailed lookup yet.`).
- Layout / tone preferences persist in `localStorage`.
- `Tailo.elm`'s diacritic→numeric conversion faithfully reproduces a quirk
  present in the original `tailo.js`: an *unmarked* vowel (tone 1, no
  diacritic) resolves to numeric tone `0` rather than `1` on reverse
  lookup, because the original's reverse-lookup table is built by
  iterating object keys in ascending order and tone `0`'s unmarked glyph
  wins the "first insert" race against tone `1`'s identical glyph. This is
  harmless in practice (`0` is treated as `1` by the tone-mark placer on
  the way back to diacritic form) but is documented and covered by tests
  in `tests/TailoTest.elm` rather than "corrected" during the port.
