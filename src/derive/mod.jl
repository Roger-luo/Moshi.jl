module Derive

using ExproniconLite: expr_map, JLIfElse, codegen_ast, xcall, xtuple
using Moshi.Data.Prelude
using Moshi.Traits: Hash, PartialEq

include("macro.jl")
include("eq.jl")
include("hash.jl")
include("show.jl")

end # Derive
