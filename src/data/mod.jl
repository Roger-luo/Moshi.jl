module Data

using ExproniconLite: Maybe, JLFunction, JLIfElse, JLStruct, JLKwStruct, JLField, JLKwField, no_default,
                      codegen_ast, expr_map, guess_type


macro data(head, body)
    def = TypeDef(__module__, head, body; source = __source__)
    info = EmitInfo(def)
    return esc(emit(info))
end

include("repr.jl")
include("cons.jl")
include("show.jl")
include("scan.jl")
include("emit/mod.jl")
include("runtime.jl")

end # Data
