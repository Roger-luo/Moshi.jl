const MoshiLiteralType = Union{
    Int, Float64, String,
    Symbol,
    Bool, Nothing,
    Missing,
}

@data Pattern begin
    NoExpr
    Var(Symbol)
    Literal(IRTypes.MoshiLiteralType)

    # data structures
    Tuple(Vector{Type})
    struct Array
        dims::Vector{Int}
        args::Vector{Type}
    end # Array

    struct Dict
        keys::Vector{Type}
        values::Vector{Type}
    end

    # composition
    And(Type, Type)
    Or(Type, Type)
    Not(Type)

    # constructors
    struct Call
        name::Type # must be Literal
        args::Vector{Type}
        kwargs::Vector{Type}
    end

    struct Guard
        pattern::Type
        cond::Type
    end

    # special
    Wildcard
    Flatten(Type)
    Assign(Type, Type)
    Quote(Type)

    struct Annotate
        pattern::Type
        type::Type
    end

    struct Range
        start::Type
        stop::Type
        step::Type
    end

    struct Comprehension
        pattern::Type
        variables::Vector{Type}
        iterators::Vector{Type}
        cond::Union{Type, Nothing}
    end

    struct Where
        pattern::Type
        params::Vector{Type}
    end

    struct Subtype
        pattern::Type
        type::Type
    end

    struct StringLiteral
        prefix::Symbol
        suffix::Symbol
        parts::Vector{Type}
    end

    struct Meta
        lineno::Int
        expr::Type
    end

    Err(IRTypes.PatternError.Type)
end
