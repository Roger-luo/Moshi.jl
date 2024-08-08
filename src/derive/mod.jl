
"""
$DEFLIST
"""
module Derive

using Jieko: @pub, DEF, DEFLIST
using ExproniconLite: expr_map, JLIfElse, codegen_ast, xcall, xtuple
using ..Data: Data

"""
    $DEF

Automatically derive traits for a concrete type. The following traits are supported:

- `PartialEq`
- `Hash`
- `Tree`
"""
@pub macro derive(expr)
    return esc(derive_m(__module__, expr))
end

function derive_m(mod::Module, expr)
    Meta.isexpr(expr, :ref) || error("expected a ref expression")
    type_expr = expr.args[1]
    traits = expr.args[2:end]
    type = Base.eval(mod, type_expr)
    type isa Module || type isa DataType || error("expected a type")

    return expr_map(traits) do trait
        derive_impl(Val(trait), mod, type)
    end
end

include("hash.jl")
include("eq.jl")
include("show.jl")

end # module Derive
