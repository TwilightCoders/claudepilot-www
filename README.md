# claudepilot.net

Marketing site for [Claude Pilot](https://github.com/TwilightCoders/claudepilot) — an iOS SSH terminal companion for Claude Code.

## Stack

Vanilla HTML + CSS + minimal JS. No build step, no dependencies.

## Development

```
open index.html
```

Or use any local server:

```
python3 -m http.server 8000
```

## Deployment

Pushes to `main` auto-deploy to GitHub Pages via the workflow in `.github/workflows/pages.yml`.

**Setup:** Repo Settings → Pages → Source → GitHub Actions

**Custom domain:** `claudepilot.net` via `CNAME` file + DNS configuration.

## License

&copy; 2026 Twilight Coders, LLC. All rights reserved.
