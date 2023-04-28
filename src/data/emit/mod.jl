const EMIT_PASS = [[] for _ in 1:10] # priority => [pass]

macro pass(fn)
    jlfn = JLFunction(fn; source = __source__)
    esc(pass_m(jlfn.name, fn))
end

macro pass(priority::Int, fn)
    jlfn = JLFunction(fn; source = __source__)
    esc(pass_m(jlfn.name, fn, priority))
end

function pass_m(name, expr, priority::Int = 5)
    quote
        $(expr)
        push!(EMIT_PASS[$(priority)], $name)
        unique!(EMIT_PASS[$(priority)])
    end
end

function emit(info::EmitInfo)
    ret = Expr(:block)
    for pass in EMIT_PASS, fn in pass
        expr = fn(info)
        isnothing(expr) || push!(ret.args, expr)
    end
    return ret
end

"""
    foreach_variant(f, info::EmitInfo, type) -> Expr

Call `f` for each variant of `type`, and return a `Expr(:block)` of the results.

# Args

- `f`: `(variant::Variant, vinfo::VariantInfo) -> Expr`
- `info`: `EmitInfo`
- `type`: an expression that contains the tag value (`UInt8`).
"""
function foreach_variant(f, info::EmitInfo, type)
    body = JLIfElse()
    for (variant, vinfo::VariantInfo) in info.variants
        body[:($type == $(vinfo.tag))] = f(variant, vinfo)
    end
    body.otherwise = quote
        throw(ArgumentError("invalid variant type: $($type)"))
    end
    return codegen_ast(body)
end

include("type.jl")
include("cons.jl")
include("namespace.jl")
include("property.jl")
include("convert.jl")
include("reflection.jl")
include("generated/mod.jl")
