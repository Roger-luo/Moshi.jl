---
title: Getting Started
description: Getting started with Moshi.jl
---

Moshi (模式) is a Julia package for defining and working with **algebraic data types (ADTs)** and **pattern matching**. It also provides a **derive macro** similar to [Rust's derive macro](https://doc.rust-lang.org/reference/procedural-macros.html#derive-macros) for deriving traits (_a set of interface functions_) for ADTs or Julia structs.

## The Name and Acknowledgement

The name "Moshi" is derived from the Chinese word "模式" (móshì) which means "pattern". The design of pattern matching is inspired by its predecessor [MLStyle](https://github.com/thautwarm/MLStyle.jl), which tries to bring pattern matching and algebraic data types from ML family languages to Julia.

The generic algebraic data type is highly inspired by previous work done in Julia ecosystem:

- [SumTypes](https://github.com/MasonProtter/SumTypes.jl) by [@MasonProtter](https://github.com/MasonProtter).
- [Expronicon](https://github.com/Roger-luo/Expronicon.jl) by [myself](https://github.com/Roger-luo/).
- [this discussion](https://github.com/JuliaLang/julia/discussions/48883) about "generated struct" and how Julia implements `Union` types by [@vjnash](https://github.com/vtjnash).

## Installation

You can install `Moshi` using the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```julia
pkg> add Moshi
```

## Quick Example

Here is a quick example of defining a simple algebraic data type:

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
```

For pattern matching, if you already used `MLStyle`, the syntax is very similar:

```julia
using Moshi.Match: @match

@match [1.0, 2, 3] begin
    [1, xs::Float64...] => xs
end

@match (1, 2.0, "a") begin
    (1, x::Int, y::String) => x
    (1, x::Real, y::String) => y
end
```

## Further Reading

- Examples and detailed syntax for `@data`: [ADT Syntax](/Moshi.jl/data/syntax)
- Builtin patterns for `@match`: [Builtin Patterns](/Moshi.jl/match/syntax/#builtin-patterns)
- The `@derive` macro: [Syntax and Examples](/Moshi.jl/start/derive/)

To understand how Moshi works, you can check the following sections:

- [Understanding What Happens | Algebraic Data Type](/Moshi.jl/data/understand)
- [Behind the Scene | Pattern Matching](/Moshi.jl/match/behind)
