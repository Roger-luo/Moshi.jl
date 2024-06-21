struct SelfType end

"""
Syntax placeholder for self type.
"""
const Self = SelfType()
Base.show(io::IO, x::SelfType) = print(io, "Self")

const SymbolOrExpr = Union{Symbol,Expr}

@enum VariantKind begin
    Singleton = 1
    Anonymous = 2
    Named = 3
end

struct Field
    type::SymbolOrExpr
end

struct NamedField
    name::Symbol
    type::SymbolOrExpr

    default::Any # nothing,literal,Expr,Symbol
    source::Maybe{LineNumberNode}
end

struct Variant
    kind::VariantKind
    name::Symbol
    fields::Maybe{Union{Vector{Field},Vector{NamedField}}}
    doc::Maybe{String}
    source::Maybe{LineNumberNode}
end

struct TypeVarExpr
    name::Symbol
    lb::Maybe{SymbolOrExpr}
    ub::Maybe{SymbolOrExpr}
end

TypeVarExpr(name::Symbol; lb=nothing,ub=nothing) = TypeVarExpr(name, lb, ub)

function Base.show(io::IO, var::TypeVarExpr)
    if var.lb === nothing && var.ub === nothing
        print(io, var.name)
    elseif var.lb === nothing
        print(io, "$(var.name) <: $(var.ub)")
    elseif var.ub === nothing
        print(io, "$(var.name) >: $(var.lb)")
    else
        print(io, "$(var.lb) <: $(var.name) <: $(var.ub)")
    end
end

mutable struct TypeHead
    name::Symbol
    params::Vector{TypeVarExpr}
    supertype::Maybe{SymbolOrExpr}

    function TypeHead(;name::Maybe{Symbol}=nothing, params=[], supertype=nothing)
        obj = new()
        isnothing(name) || (obj.name = name)
        obj.params = params
        obj.supertype = supertype
        return obj
    end
end

function Base.:(==)(lhs::TypeHead, rhs::TypeHead)
    lhs.name == rhs.name && lhs.params == rhs.params && lhs.supertype == rhs.supertype
end

struct TypeDef
    mod::Module
    head::TypeHead
    variants::Vector{Variant}
    source::LineNumberNode
end
