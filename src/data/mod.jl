"""
$DEFLIST
"""
module Data

using Jieko: @pub, DEF, DEFLIST, @prelude_module
using ExproniconLite:
    Maybe,
    JLFunction,
    JLIfElse,
    JLStruct,
    JLKwStruct,
    JLField,
    JLKwField,
    no_default,
    codegen_ast,
    expr_map,
    guess_type,
    xtuple

"""
    @data <head> <variants>

Create a new algebraic data type (also known as a sum type) with the given head and variants.
"""
@pub macro data(head, body)
    def = TypeDef(__module__, false, head, body; source=__source__)
    info = EmitInfo(def)
    return esc(emit(info))
end

@pub macro data(mutable_kw, head, body)
    @assert mutable_kw == :mutable
    def = TypeDef(__module__, true, head, body; source=__source__)
    info = EmitInfo(def)
    return esc(emit(info))
end

include("exception.jl")
include("repr.jl")
include("cons.jl")
include("show.jl")
include("scan.jl")
include("emit/mod.jl")
include("runtime.jl")

@prelude_module

end # Data
