"""
$DEFLIST
"""
module Match

using Jieko: @pub, DEF, DEFLIST
using Moshi.Data: Data, @data, isa_variant, variant_type, variant_name
using Moshi.Derive: @derive
using ExproniconLite: Maybe, expr_map, xcall, xtuple, JLFunction, rm_lineinfo, rm_nothing

include("exception.jl")
include("repr.jl")
include("scan.jl")
include("show.jl")
include("verify/mod.jl")
include("emit/mod.jl")
include("macro.jl")

end # Match
