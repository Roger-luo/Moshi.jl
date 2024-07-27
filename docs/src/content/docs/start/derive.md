---
title: Understanding the Derive Macro
description: A basic introduction of the derive macro from rust
---

The `@derive` macro comes from Rust's derive macro, which is a way to automatically implement traits for data types. In Rust, a trait is a set of interface functions that a type must implement. The derive macro allows you to automatically implement these functions for your data types.

In Julia, the trait is loosely defined as **a set of functions that a type implements**. The `@derive` macro in Moshi.jl is similar to Rust's derive macro, but it is more flexible and dynamic. It gives you a unified way to derive trait functions for your data types, whether they are algebraic data types (ADTs) or Julia structs.

One example of previous packages is the [AutoHashEquals](https://juliahub.com/ui/Packages/General/AutoHashEquals) package. The `@auto_hash_equals` macro automatically derives the `hash`, `==` and `isequal` functions for your Julia structs. In `@derive` macro, this is equivalent to:

```julia
@derive MyType[Hash, Eq]
```

Unlike [AutoHashEquals](https://juliahub.com/ui/Packages/General/AutoHashEquals), the `@derive` macro is naturally extensible to other traits. Similar to Rust's derive macro, you can define how other traits are derived for your data types.

## How to Use

The `@derive` macro is used to derive traits for your data types. You can use it to automatically implement functions for your data types.

```julia
using Moshi.Derive: @derive

struct Foo
    x::Int
    y::Int
end

@derive Foo[Hash, Eq, Show]
```

In this example, we define a struct `Foo` with two fields `x` and `y`. We then use the `@derive` macro to derive the `Hash`, `Eq`, and `Show` traits for the `Foo` struct. This is equivalent to the following code:

```julia
Base.hash(f::Foo, h::UInt) = hash(f.x, hash(f.y, h))
Base.==(a::Foo, b::Foo) = a.x == b.x && a.y == b.y
Base.isequal(a::Foo, b::Foo) = isequal(a.x, b.x) && isequal(a.y, b.y)
Base.show(io::IO, f::Foo) = print(io, "Foo($(f.x), $(f.y))")
```
