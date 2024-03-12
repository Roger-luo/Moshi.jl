module Match

using ExproniconLite: expr_map, xtuple, xcall
using Moshi.Data: Data, @data, isa_variant, SyntaxError, guess_type
using Moshi.Traits: PartialEq
using Moshi.Derive: @derive

include("data.jl")
include("scan.jl")
include("macro.jl")
include("emit/mod.jl")
include("show.jl")

end # Match
