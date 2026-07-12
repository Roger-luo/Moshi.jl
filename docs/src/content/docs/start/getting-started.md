---
title: Quick Start
description: Install Moshi and write your first ADT with pattern matching.
---

Moshi (模式) is a Julia package for **algebraic data types**, **pattern matching**, and **trait derivation**. This guide gets you from zero to a working example in a few minutes.

## Install

From the Julia REPL, press `]` to enter Pkg mode:

```julia
pkg> add Moshi
```

## Your first ADT

Import `@data` and define a sum type with several variants:

```julia
using Moshi.Data: @data

@data Message begin
    Quit
    struct Move
        x::Int
        y::Int
    end
    Write(String)
    ChangeColor(Int, Int, Int)
end

msg = Message.Move(3, 4)
```

Variants can be singletons (`Quit`), named structs (`Move`), or tuple-like constructors (`Write`, `ChangeColor`).

> **Note:** even a singleton variant is constructed with `()` — `Message.Quit` is the variant *type*, while `Message.Quit()` is the value. See [Singleton Variant](/data/syntax/#singleton-variant).

## Pattern match on it

`@match` destructures values and returns the right-hand side of the first matching arm:

```julia
using Moshi.Match: @match

describe(msg) = @match msg begin
    Message.Quit() => "quit"
    Message.Move(; x, y) => "move to ($x, $y)"
    Message.Write(text) => text
    Message.ChangeColor(r, g, b) => (r, g, b)
end

describe(msg)  # "move to (3, 4)"
```

If you have used [MLStyle](https://github.com/thautwarm/MLStyle.jl), the syntax will feel familiar. Moshi also supports matching on arrays, tuples, and more — see [Builtin Patterns](/match/syntax/#builtin-patterns).

## Derive traits

Use `@derive` to implement `Show`, `Hash`, and `Eq` from your type definition:

```julia
using Moshi.Derive: @derive

@derive Message[Show, Hash, Eq]
```

Works on both `@data` types and ordinary Julia `struct`s.

## Next steps

| Topic | Guide |
|-------|-------|
| ADT concepts | [Algebraic Data Types](/start/algebra-data-type/) |
| `@data` syntax | [ADT Syntax](/data/syntax/) |
| `@match` patterns | [Pattern Matching Intro](/start/match/) |
| `@derive` traits | [Derive Intro](/start/derive/) |
| API docs | [Moshi.Data](/api/data/), [Moshi.Match](/api/match/), [Moshi.Derive](/api/derive/) |

## Acknowledgements

Moshi is named after the Chinese word 模式 (*móshì*, "pattern"). Pattern matching design draws from [MLStyle](https://github.com/thautwarm/MLStyle.jl). The ADT encoding is inspired by [SumTypes](https://github.com/MasonProtter/SumTypes.jl), [Expronicon](https://github.com/Roger-luo/Expronicon.jl), and [this Julia discussion](https://github.com/JuliaLang/julia/discussions/48883) on generated structs.
