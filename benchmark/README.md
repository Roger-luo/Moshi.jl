# Benchmarks

## `benchmarks.jl` — CI regression suite

`benchmarks.jl` defines `const SUITE = BenchmarkGroup()` following the
[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) /
[AirspeedVelocity.jl](https://github.com/MilesCranmer/AirspeedVelocity.jl)
convention. It is run automatically on every pull request by
`.github/workflows/Benchmarks.yml`, which compares the PR against `main` and
posts a time + memory comparison table as a PR comment.

The environment (`Project.toml`) is intentionally minimal (BenchmarkTools +
Moshi + Random) so the CI job stays fast.

Run it locally with [AirspeedVelocity](https://github.com/MilesCranmer/AirspeedVelocity.jl):

```bash
# compare your working tree against main
benchpkg Moshi --rev=main,dirty --bench-on=main
```

or directly with BenchmarkTools:

```bash
julia --project=benchmark -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=benchmark -e 'include("benchmark/benchmarks.jl"); using BenchmarkTools; show(run(SUITE))'
```

> Deterministic, non-noisy guards (type stability + allocation scaling) live in
> the normal test suite at `test/perf.jl`, so they hard-fail CI on regression.
> `benchmarks.jl` is for tracking wall-clock/memory trends that are too noisy to
> assert on directly.

## `comparison/` — cross-package comparison plot

`comparison/` holds the manual harness that benchmarks Moshi against other
tagged-union packages (SumTypes, Unityper, LightSumTypes, Expronicon, …) and
renders `docs/public/benchmark.svg` (the chart shown in the top-level README).
It has its own heavier environment (CairoMakie, etc.).

```bash
julia --project=benchmark/comparison benchmark/comparison/main.jl
# writes benchmark.svg / benchmark.png in the current directory
```
