function Base.show(io::IO, p::PatternKind.Tag)
    idx = Int(Core.bitcast(UInt8, p)) + 1
    print(io, "Pattern.", PatternKind.TagNames[idx])
end

function Base.show(io::IO, p::Pattern.Type)
    value_io = if p.tag == PatternKind.Quote
        IOContext(io, :quote_pattern=>true)
    else
        io
    end # if

    show_str(p) = if p isa Vector
        "[" * join(map(show_str, p), ", ") * "]"
    else
        sprint(show, p; context=value_io)
    end

    quote_pattern = get(io, :quote_pattern, false)
    quote_pattern && print(io, "\$(@pattern(")
    if p.tag == PatternKind.Var
        printstyled(io, p.name, color=:blue)
    elseif p.tag == PatternKind.Literal
        printstyled(io, show_str(p.val), color=:yellow)
    elseif p.tag == PatternKind.Tuple
        print(io, "(")
        for (idx, v) in enumerate(p.val)
            idx > 1 && print(io, ", ")
            show(io, v)
        end
        print(io, ")")
    elseif p.tag == PatternKind.Call
        show(io, p.name)
        print(io, "(")
        for (idx, v) in enumerate(p.args)
            idx > 1 && print(io, ", ")
            show(io, v)
        end
        for (idx, v) in enumerate(p.kwargs)
            idx > 1 && print(io, ", ")
            print(io, v.name, "=")
            show(io, v.pattern)
        end
        print(io, ")")
    elseif p.tag == PatternKind.Quote
        show(io, p.pattern)
    elseif p.tag == PatternKind.Subtype
        show(io, p.pattern)
        print(io, " <: ")
        show(io, p.type)
    elseif p.tag == PatternKind.Where
        show(io, p.pattern)
        print(io, " where {")
        for (idx, each) in enumerate(p.where)
            idx > 1 && print(io, ", ")
            show(io, each)
        end # for
        print(io, "}")
    elseif p.tag == PatternKind.Annotate
        if p.pattern.tag != PatternKind.NoExpr
            show(io, p.pattern)
        end
        print(io, "::(")
        show(io, p.type)
        print(io, ")")
    else
        show(io, p.tag)
        print(io, "(")
        for (idx, f) in enumerate(propertynames(p))
            idx > 1 && print(io, ", ")
            print(io, f, "=")
            val = getproperty(p, f)
            if val isa Vector
                print(io, "[")
                for (idx, v) in enumerate(val)
                    idx > 1 && print(io, ", ")
                    show(io, v)
                end
                print(io, "]")
            else
                show(io, val)
            end
        end
        print(io, ")")
    end
    quote_pattern && print(io, "))")
end # show
