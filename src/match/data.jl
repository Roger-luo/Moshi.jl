const JLType = Union{Symbol,Expr,DataType,UnionAll}

@data Pattern begin
    Err(String) # invalid pattern
    Wildcard
    Variable(Symbol)
    Quote(Any)

    And(Pattern, Pattern)
    Or(Pattern, Pattern)
    Kw(Symbol, Pattern)
    Guard(Expr)

    struct Ref
        head # must be some constant object
        args::Vector{Pattern}
    end

    struct Call
        head # must be constant object
        args::Vector{Pattern}
        kwargs::Dict{Symbol,Pattern}
    end

    struct Tuple
        xs::Vector{Pattern}
    end

    struct Vector
        xs::Vector{Pattern}
    end

    # <splat>...
    struct Splat
        body::Pattern
    end

    struct TypeAnnotate
        body::Pattern
        type::JLType
    end

    struct Row
        xs::Vector{Pattern}
    end

    struct NRow
        n::Int
        xs::Vector{Pattern}
    end

    struct VCat
        xs::Vector{Pattern}
    end

    struct HCat
        xs::Vector{Pattern}
    end

    struct NCat
        n::Int
        xs::Vector{Pattern}
    end

    struct TypedVCat
        type::JLType
        xs::Vector{Pattern}
    end

    struct TypedHCat
        type::JLType
        xs::Vector{Pattern}
    end

    struct TypedNCat
        type::JLType
        n::Int
        xs::Vector{Pattern}
    end

    struct Comprehension
        body::Pattern # generator
    end

    struct Generator
        body::Pattern
        vars::Vector{Symbol}
        iterators::Vector{Pattern}
        filter::Union{Nothing,Pattern}
    end
end

@derive Pattern[PartialEq]
