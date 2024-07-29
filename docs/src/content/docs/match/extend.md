---
title: Extending Patterns
description: How to extend patterns in Moshi.jl
---

For example, the `Regex` pattern in `Moshi` is defined
as following

```julia
function decons_call(::Type{Regex}, ctx::PatternContext, pat::Pattern.Type)
    Data.isa_variant(pat.args[1], Pattern.Quote) || error("Regex head must be a string")
    re = Regex(pat.args[1].:1)
    return function regex(x)
        return quote
            $Base.occursin($re, $x)
        end
    end
end
```
