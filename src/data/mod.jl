module Data

using Jieko: @interface, INTERFACE, INTERFACE_LIST, @export_all_interfaces
using ExproniconLite: Maybe, JLFunction, JLIfElse, JLStruct, JLKwStruct, JLField, JLKwField, no_default,
                      codegen_ast, expr_map, guess_type


"""
    @data <head> <variants>

Create a new algebraic data type (also known as a sum type) with the given head and variants.
"""
@interface macro data(head, body)
    def = TypeDef(__module__, head, body; source = __source__)
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

@export_all_interfaces begin
    @data
end

end # Data
