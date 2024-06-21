const EMIT_PASS = [[] for _ in 1:10] # priority => [pass]

"""
    @pass [priority] <function definition>

Add a function to the list of functions to be called when emitting code.

Optionally, you can specify a priority for the function. The default priority is 5.
Lower priority number functions are called first.
"""
macro pass(fn)
    jlfn = JLFunction(fn; source=__source__)
    return esc(pass_m(jlfn.name, fn))
end

macro pass(priority::Int, fn)
    jlfn = JLFunction(fn; source=__source__)
    return esc(pass_m(jlfn.name, fn, priority))
end

function pass_m(name, expr, priority::Int=5)
    quote
        $(expr)
        push!(EMIT_PASS[$(priority)], $name)
        unique!(EMIT_PASS[$(priority)])
    end
end

function emit(info::EmitInfo)
    ret = quote
        using Base: ==
    end
    for pass in EMIT_PASS, fn in pass
        expr = fn(info)
        isnothing(expr) || push!(ret.args, expr)
    end

    return Expr(
        :toplevel,
        Expr(:module, false, info.def.head.name, ret),
        Expr(
            :macrocall,
            GlobalRef(Core, Symbol("@__doc__")),
            info.def.source,
            info.def.head.name,
        ),
    )
end

include("storage.jl")
include("cons.jl")
include("type.jl")
include("stub.jl")
include("getproperty.jl")
include("show.jl")
include("reflect.jl")
