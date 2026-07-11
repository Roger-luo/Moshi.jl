# Moshi.jl Documentation

Documentation site for [Moshi.jl](https://github.com/Roger-luo/Moshi.jl), built with [Astro](https://astro.build) and [Starlight](https://starlight.astro.build).

## Development

```bash
npm install
npm run dev       # generate API docs + start dev server
```

Requires Julia 1.x with the `docs/script` project instantiated:

```bash
julia --project=script -e 'using Pkg; Pkg.instantiate()'
```

## Build

```bash
npm run build
npm run preview
```

## Deploy

### Vercel (recommended)

1. Import the repo on Vercel with **Root Directory** set to `docs`.
2. Add Julia to the build environment, or commit generated files in `src/generated/`.
3. Deploy — no `BASE_PATH` needed.

### GitHub Pages

The `Astro.yml` workflow builds with `BASE_PATH=Moshi.jl` for `https://rogerluo.dev/Moshi.jl/`.

## Structure

```
docs/
├── src/
│   ├── components/     # Astro components (ApiDoc, LandingHero, …)
│   ├── content/docs/   # Markdown/MDX documentation pages
│   ├── generated/      # Build-time Julia API docs (JSON)
│   └── styles/         # Custom Starlight theme
├── script/
│   └── gendoc.jl       # Extracts docstrings via Jieko
└── astro.config.mjs
```
