"""
Provides the Algebraic Data Types (ADTs) for the project.
"""
module Data

using DocStringExtensions
using ExproniconLite: JLKwField, JLKwStruct, rm_lineinfo, rm_nothing, no_default
using Jieko: @interface, INTERFACE, INTERFACE_LIST, @export_all_interfaces

include("err.jl")
include("macro.jl")
include("syntax.jl")

include("reflect.jl")
include("guess.jl")
include("scan.jl")
include("show.jl")
include("emit/mod.jl")
include("runtime.jl")

@export_all_interfaces begin
    @data
    pprint
end

end # Data
