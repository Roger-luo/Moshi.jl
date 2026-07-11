---
title: Documentation Site
description: Building and deploying the Moshi docs with Astro.
---

The documentation site lives in the `docs/` directory. It uses [Astro](https://astro.build) with the [Starlight](https://starlight.astro.build) theme.

## Local development

```bash
cd docs
npm install
npm run dev
```

The `dev` script runs `gendoc.jl` first to extract Julia docstrings into `src/generated/`, then starts the Astro dev server at `http://localhost:4321`.

## Building

```bash
cd docs
npm run build        # Node only — uses committed API JSON
npm run build:full   # regenerate Julia API docs, then build
npm run preview
```

## API docstring generation

Julia docstrings are extracted at build time by `docs/script/gendoc.jl`. It uses [Jieko](https://github.com/Roger-luo/Jieko.jl) to discover public APIs and serializes them to JSON in `docs/src/generated/`.

The `ApiDoc` Astro component reads these JSON files and renders each entry with markdown formatting.

To regenerate docs manually:

```bash
julia --project=docs/script docs/script/gendoc.jl
```

## Deploying to Vercel

Vercel preview deployments run automatically on pull requests when files under `docs/` change.

1. Import the repository on [Vercel](https://vercel.com).
2. Set the **Root Directory** to `docs`.
3. Vercel auto-detects Astro. The `vercel.json` in `docs/` configures the build.

No environment variables are required for a default deployment. Optionally set:

| Variable | Purpose |
|----------|---------|
| `SITE_URL` | Canonical site URL (e.g. `https://moshi.example.com`) |
| `BASE_PATH` | URL prefix if not deploying at root (e.g. `/Moshi.jl` for GitHub Pages) |

Vercel runs `npm run build`, which invokes Julia for doc generation. Ensure Julia is available in the build environment — Vercel's default Node image does not include Julia. Use a [custom build command](https://vercel.com/docs/build-step) or a GitHub Action that builds and deploys.

### Recommended: GitHub Action → Vercel

For Julia doc generation, use the existing GitHub Actions workflow or connect Vercel with a prebuild step that installs Julia. The simplest path is deploying via the GitHub integration with a `vercel.json` and adding Julia to the install step in Vercel project settings, or using `nixpacks`/`apt` in `vercel.json`.

Alternatively, commit generated JSON files (remove `src/generated/` from `.gitignore`) so Vercel only needs Node.

## GitHub Pages (legacy)

The `Astro.yml` workflow deploys to GitHub Pages. Set `BASE_PATH=Moshi.jl` and `SITE_URL=https://rogerluo.dev` when building for that target.
