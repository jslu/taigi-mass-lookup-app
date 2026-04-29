# Taigi Mass Lookup

Paste a 台語文 passage, get sentence-by-sentence 漢字 ↔ Tâi-lô conversion with four display layouts (Ruby / Stacked / Side-by-side / Table) and a tone-mode toggle (diacritic ↔ numeric).

Conversions come from the [意傳科技 ithuan](https://suisiann.ithuan.tw/) `tau` endpoint, which is statistical / corpus-based — verify against a dictionary for important uses.

## Run

```sh
python3 serve.py
# → http://localhost:8000
```

`serve.py` is a stdlib-only dev server that serves the static files in this
directory and proxies `POST /api/tau` to `https://hokbu.ithuan.tw/tau`. The
proxy is necessary because the upstream API's CORS policy only allows
requests from `suisiann.ithuan.tw`.

## Files

- `index.html` — entry point; loads React 18 + Babel from CDN
- `app.jsx` — root component, input/results layout, layout/tone controls
- `sentence-row.jsx` — one converted sentence row (popover, copy)
- `sentence-layouts.jsx` — Ruby / Stacked / Side / Table layouts
- `convert.js` — sentence splitting + ithuan API call (via `/api/tau`)
- `tailo.js` — Tâi-lô tone-mark ↔ numeric conversion helpers
- `styles.css` — app-specific styles
- `lib/unifi-tokens.css` — design tokens (colors, type, spacing)
- `lib/fonts/Inter-*.ttf` — Inter variable fonts
- `serve.py` — dev server with `/api/tau` proxy

## Notes

- Per-word popover currently shows han + Tâi-lô only. A detailed
  dictionary lookup is stubbed (`No detailed lookup yet.`).
- Layout / tone preferences persist in `localStorage`.
