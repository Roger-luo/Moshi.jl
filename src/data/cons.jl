# concrete
function TypeDef(mod::Module, head::Symbol, body::Expr)
end

# generic
function TypeDef(mod::Module, head::Expr, body::Expr)
end

function Variant(expr::Symbol)
    Variant(Singleton, expr, nothing, nothing, nothing)
end

function Variant(expr::Expr; source=nothing)
    if Meta.isexpr(expr, :call)
        expr.args[1] isa Symbol || throw(ArgumentError("invalid variant expression: $expr"))
        return Variant(Anonymous, expr.args[1], Field.(expr.args[2:end]), doc, source)
    elseif Meta.isexpr(expr, :struct)
        jl = JLKwStruct(expr)
        jl.ismutable && throw(ArgumentError("invalid variant expression: $expr, cannot be mutable"))
        isempty(jl.constructors) || throw(ArgumentError("invalid variant expression: $expr, cannot have constructors"))
        isnothing(jl.supertype) || throw(ArgumentError("invalid variant expression: $expr, cannot have supertype"))
        isempty(jl.typevars) || throw(ArgumentError("invalid variant expression: $expr, cannot have typevars"))
        return Variant(Named, jl.name, NamedField.(jl.fields), jl.doc, source)
    else
        throw(ArgumentError("invalid variant expression: $expr"))
    end
end

function NamedField(expr::JLKwField; source=nothing)
    return NamedField(expr.name, expr.type, expr.default, expr.line)
end
