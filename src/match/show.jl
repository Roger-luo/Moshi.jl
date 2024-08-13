function Base.show(io::IO, pattern::Pattern.Type)
    if isa_variant(pattern, Pattern.Err)
        printstyled(io, "err: ", abbr(pattern.:1); color=:red)
    elseif isa_variant(pattern, Pattern.Wildcard)
        printstyled(io, "_"; color=:red)
    elseif isa_variant(pattern, Pattern.Variable)
        printstyled(io, pattern.:1; color=:blue)
    elseif isa_variant(pattern, Pattern.Quote)
        if pattern.:1 isa Union{Symbol,Expr}
            printstyled(io, "\$(", pattern.:1, ")")
        else
            print(io, pattern.:1)
        end
    elseif isa_variant(pattern, Pattern.Guard)
        printstyled(io, "if "; color=:red)
        show(io, pattern.:1)
        printstyled(io, " end"; color=:red)
    elseif isa_variant(pattern, Pattern.And)
        print(io, "(")
        show(io, pattern.:1)
        print(io, ")")
        printstyled(io, " && "; color=:red)
        print(io, "(")
        show(io, pattern.:2)
        print(io, ")")
    elseif isa_variant(pattern, Pattern.Or)
        print(io, "(")
        show(io, pattern.:1)
        print(io, ")")
        printstyled(io, " || "; color=:red)
        print(io, "(")
        show(io, pattern.:2)
        print(io, ")")
    elseif isa_variant(pattern, Pattern.Ref)
        print(io, "\$(", pattern.head, ")")
        print(io, "[")
        for (idx, arg) in enumerate(pattern.args)
            idx > 1 && print(io, ", ")
            show(io, arg)
        end
        print(io, "]")
    elseif isa_variant(pattern, Pattern.Call)
        if pattern.head === :(:)
            for (idx, each) in enumerate(pattern.args)
                idx > 1 && print(io, ":")
                show(io, each)
            end
            # some common infix operators
        elseif pattern.head in (:(+), :(-), :(*), :(/), :(\))
            show(io, pattern.args[1])
            print(io, " ", pattern.head, " ")
            show(io, pattern.args[2])
        else
            print(io, "\$(", pattern.head, ")")
            print(io, "(")
            for (idx, arg) in enumerate(pattern.args)
                idx > 1 && print(io, ", ")
                show(io, arg)
            end
            if !isempty(pattern.kwargs)
                print(io, "; ")
                for (idx, (key, val)) in enumerate(pattern.kwargs)
                    idx > 1 && print(io, ", ")
                    print(io, key, "=", val)
                end
            end
            print(io, ")")
        end
    elseif isa_variant(pattern, Pattern.Tuple)
        print(io, "(")
        for (idx, each) in enumerate(pattern.xs)
            idx > 1 && print(io, ", ")
            show(io, each)
        end
        print(io, ")")
        # elseif isa_variant(pattern, Pattern.NamedTuple)
        #     print(io, "(")
        #     for (idx, arg) in enumerate(pattern.xs)
        #         idx > 1 && print(io, ", ")
        #         print(io, pattern.names[idx], "=", arg)
        #     end
    elseif isa_variant(pattern, Pattern.Vector)
        print(io, "[")
        for (idx, each) in enumerate(pattern.xs)
            idx > 1 && print(io, ", ")
            show(io, each)
        end
        print(io, "]")
    elseif isa_variant(pattern, Pattern.Row)
        for (idx, arg) in enumerate(pattern.xs)
            idx > 1 && print(io, " ")
            show(io, arg)
        end
    elseif isa_variant(pattern, Pattern.NRow)
        for (idx, arg) in enumerate(pattern.xs)
            idx > 1 && print(io, ";"^pattern.n)
            show(io, arg)
        end
    elseif isa_variant(pattern, Pattern.VCat)
        show_vcat(io, pattern)
    elseif isa_variant(pattern, Pattern.HCat)
        show_hcat(io, pattern)
    elseif isa_variant(pattern, Pattern.NCat)
        show_ncat(io, pattern)
    elseif isa_variant(pattern, Pattern.TypedVCat)
        printstyled(io, pattern.type; color=:light_cyan)
        show_vcat(io, pattern)
    elseif isa_variant(pattern, Pattern.TypedHCat)
        printstyled(io, pattern.type; color=:light_cyan)
        show_hcat(io, pattern)
    elseif isa_variant(pattern, Pattern.TypedNCat)
        printstyled(io, pattern.type; color=:light_cyan)
        show_ncat(io, pattern)
    elseif isa_variant(pattern, Pattern.Splat)
        show(io, pattern.body)
        printstyled(io, "..."; color=:red)
    elseif isa_variant(pattern, Pattern.TypeAnnotate)
        show(io, pattern.body)
        printstyled(io, "::"; color=:red)
        printstyled(io, pattern.type; color=:light_cyan)
    elseif isa_variant(pattern, Pattern.Generator)
        show(io, pattern.body)
        printstyled(io, " for "; color=:red)
        for (idx, (var, iter)) in enumerate(zip(pattern.vars, pattern.iterators))
            idx > 1 && printstyled(io, ", "; color=:red)
            print(io, var)
            printstyled(io, " in "; color=:red)
            show(io, iter)
        end

        if !isnothing(pattern.filter)
            printstyled(io, " if "; color=:red)
            show(io, pattern.filter)
        end
    elseif isa_variant(pattern, Pattern.Comprehension)
        print(io, "[")
        show(io, pattern.body)
        print(io, "]")
    elseif isa_variant(pattern, Pattern.Expression)
        show_expr(io, pattern)
    else
        error("unhandled pattern: $pattern")
    end
end # show_variant

function abbr(s::String, max::Int=10)
    length(s) > max && return s[1:max] * "..."
    return s
end

function show_vcat(io::IO, pattern::Pattern.Type)
    return show_xcat(io, pattern, "; ")
end

function show_hcat(io::IO, pattern::Pattern.Type)
    return show_xcat(io, pattern, " ")
end

function show_ncat(io::IO, pattern::Pattern.Type)
    return show_xcat(io, pattern, ";"^pattern.n)
end

function show_xcat(io::IO, pattern::Pattern.Type, sep::String)
    print(io, "[")
    for (idx, each) in enumerate(pattern.xs)
        idx > 1 && print(io, sep)
        show(io, each)
    end
    return print(io, "]")
end

# NOTE: this is for pretty printing
# a pattern inside an expression
struct QuotedPattern
    pat::Pattern.Type
end

function Base.show(io::IO, qp::QuotedPattern)
    print(io, "\$(")
    show(io, qp.pat)
    return print(io, ")")
end

function show_expr(io::IO, pattern::Pattern.Type)
    function unquote(pat::Pattern.Type)
        if isa_variant(pat, Pattern.Quote)
            if pat.:1 isa QuoteNode
                x = pat.:1
                x.value isa Symbol && return x.value
            else
                return pat.:1
            end
        end

        isa_variant(pat, Pattern.Expression) || return QuotedPattern(pat)
        return Expr(pat.head, map(unquote, pat.args)...)
    end
    ex = unquote(pattern)
    return show(io, ex)
end
