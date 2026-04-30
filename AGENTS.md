# AGENTS.md

This file provides guidance when working with code in this repository.

## Project

Moshi is a Julia package providing three core features:
- **`@data`** — algebraic data types (sum types / tagged unions) with generics
- **`@match`** — type-stable pattern matching
- **`@derive`** — Rust-inspired trait derivation (`Hash`, `Eq`, `Show`)

## Build & Test Commands

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'  # Install dependencies
julia --project -e 'using Pkg; Pkg.test()'          # All tests

# Run a single test file
julia --project -e 'include("test/data/mod.jl")'

# Run a specific testset (from REPL)
# julia --project
# include("test/data/emit/basic.jl")
```

## Pre-commit Checklist

```bash
julia --project -e 'using JuliaFormatter; format("src")' # 1. Format
julia --project -e 'using Pkg; Pkg.test()'                # 2. Test
```

## Architecture

`src/Moshi.jl` is a thin wrapper that includes three sub-modules: `Data`, `Derive`, and `Match`. The modules depend on each other — `Match` uses `Data` and `Derive`.

### Data (`src/data/`)

The `@data` macro pipeline has three stages:

1. **Parse** (`scan.jl`, `repr.jl`, `cons.jl`) — Transforms the macro AST into an IR:
   - `TypeDef` — top-level ADT definition (name, type params, supertype, variants)
   - `Variant` — a single variant, one of three kinds: `Singleton`, `Anonymous` (tuple-like), or `Named` (struct-like)
   - `Field` / `NamedField` — field definitions within a variant

2. **Lower** (`emit/storage.jl`) — Builds `EmitInfo` from `TypeDef`, computing `StorageInfo` per variant. Each variant gets a private storage struct named `##Storage#<VariantName>`. Self-referential types use `Any` for the storage field type. The ADT's wrapper struct (named `Type` inside the module) holds a `Union{...}` of all storage structs.

3. **Emit** (`emit/mod.jl` and its includes) — Multiple `@pass`-registered functions run in priority order (1–10) to generate Julia code:
   - Pass 1: `emit_variant_storage` — emits the private storage structs
   - Pass 2: `emit_type` — emits the public wrapper struct + `Type` alias
   - Later passes: constructors (`emit/cons.jl`), `getproperty`/`setproperty`, reflection functions (`emit/reflect.jl`), public exports (`emit/public.jl`)

   The `@pass` macro appends functions to `EMIT_PASS[priority]`; `emit(info)` iterates them in order.

### Match (`src/match/`)

`@match` compiles a `begin ... end` block of `pattern => result` arms into nested Julia `if` expressions.

- `repr.jl` defines the `Pattern` ADT (itself using `@data`) covering all pattern forms
- `scan.jl` parses raw `Expr` into `Pattern` values
- `emit/` translates `Pattern` trees to Julia `if/let` chains; `ctx.jl` tracks variables bound during matching
- `verify/` checks patterns for exhaustiveness and overlap

### Derive (`src/derive/`)

`@derive TypeName[Trait1, Trait2]` evaluates the type at macro-expansion time and generates trait method implementations. Supported traits: `Hash`, `Eq`, `Show`. Each trait lives in its own file (`hash.jl`, `eq.jl`, `show.jl`).

### Key Dependencies

- **ExproniconLite** — AST utilities (`JLStruct`, `JLFunction`, `JLIfElse`, `codegen_ast`, etc.)
- **Jieko** — `@pub` for public exports, `DEFLIST`/`DEF` for auto-generated docstrings, `@prelude_module`

## Key Conventions

- **Module-as-namespace for ADTs:** `@data Foo begin ... end` creates a module `Foo` containing `Type`, `Variant`, and per-variant constructor names. Access via `Foo.Type`, `Foo.Bar`, etc.
- **`Self` in variant fields:** Using `Self` or the ADT name as a field type in variants is supported; it's rewritten to `Any` in storage structs to avoid recursive type issues.
- **`@pass` registration:** New emit passes for `@data` are registered by defining a function decorated with `@pass [priority]` inside `src/data/emit/`. Lower priority numbers run first.
- **Testing layout:** Tests mirror `src/` — `test/data/`, `test/match/`, `test/derive/`. Each subdirectory has a `mod.jl` that includes the rest.

## Git Conventions

- **Conventional commits:** `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `refactor:`, `perf:`, `build:`, `chore:`
- **Breaking changes:** Use `feat!:` or `fix!:` (note the `!`) or add a `BREAKING CHANGE:` footer
