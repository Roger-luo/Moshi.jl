# @data MyADT begin
#     Foo
#     Bar(Int, Float64)

#     struct Baz
#         x::Int
#         y::Float64
#         z::Vector{MyADT}
#     end
# end

macro data(name::Symbol, expr)
    return esc(data_m(__module__, name, expr, __source__))
end

function data_m(mod::Module, name::Symbol, expr, source)
    expr isa Expr || throw(SyntaxError("Expected an \
        expression, got $(typeof(expr)): $expr"))

    def = TypeDef(mod, name, expr; source)
    info = EmitInfo(def)
    return Emit.emit(info)
end
