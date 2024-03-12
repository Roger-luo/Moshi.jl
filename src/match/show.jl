function Base.show(io::IO, ::MIME"text/plain", x::EmitInfo)
    f = Data.FormatPrinter(io)
    f.print("EmitInfo:\n"; color=:light_cyan)
    ff = Data.indent(f, 2)
    ff.leading()
    ff.println("value: ", x.value)
    ff.print("table:\n")
    fff = Data.indent(ff, 2)
    fff.leading()
    pattern_strs = map(fff.show_str, x.cases)
    if isempty(pattern_strs)
        max_length = 0
    else
        max_length = maximum(length, pattern_strs)
    end

    for (idx, (key, val)) in enumerate(zip(pattern_strs, x.exprs))
        fff.print(" "^(max_length - length(key)))
        fff.print(key)
        fff.print(" => "; color=:red)
        fff.show(val)
        idx < length(x.cases) && fff.println()
    end
    ff.println("\n")
    ff.print("final_label: ")
    ff.println(x.final_label; color=:light_cyan)
    ff.print("return_var: ")
    return ff.print(x.return_var; color=:light_cyan)
end

function abbr(s::String, max::Int=10)
    length(s) > max && return s[1:max] * "..."
    return s
end

function Base.show(io::IO, x::Pattern.Type)
    f = Data.FormatPrinter(io)
    if isa_variant(x, Pattern.Err)
        f.print("err: ", abbr(x.:1); color=:red)
    elseif isa_variant(x, Pattern.Wildcard)
        f.print("_"; color=:red)
    elseif isa_variant(x, Pattern.Variable)
        f.print(x.:1; color=:blue)
    elseif isa_variant(x, Pattern.Quote)
        if x.:1 isa Union{Symbol,Expr}
            f.print("\$(", x.:1, ")")
        else
            f.print(x.:1)
        end
    elseif isa_variant(x, Pattern.Guard)
        f.print("if "; color=:red)
        f.show(x.:1)
        f.print(" end"; color=:red)
    elseif isa_variant(x, Pattern.And)
        f.print("(")
        f.show(x.:1)
        f.print(") ")
        f.print("&&"; color=:red)
        f.print(" (")
        f.show(x.:2)
        f.print(")")
    elseif isa_variant(x, Pattern.Or)
        f.print("(")
        f.show(x.:1)
        f.print(") ")
        f.print("||"; color=:red)
        f.print(" (")
        f.show(x.:2)
        f.print(")")
    elseif isa_variant(x, Pattern.Ref)
        f.print("\$(", x.head, ")")
        f.print("[")
        for (idx, arg) in enumerate(x.args)
            idx > 1 && f.print(", ")
            f.show(arg)
        end
        f.print("]")
    elseif isa_variant(x, Pattern.Call)
        if x.head === :(:)
            for (idx, each) in enumerate(x.args)
                idx > 1 && f.print(":")
                f.show(each)
            end
            # some common infix operators
        elseif x.head in (:(+), :(-), :(*), :(/), :(\))
            f.show(x.args[1])
            f.print(" ", x.head, " ")
            f.show(x.args[2])
        else
            f.print("\$(", x.head, ")")
            f.print("(")
            for (idx, arg) in enumerate(x.args)
                idx > 1 && f.print(", ")
                f.show(arg)
            end
            if !isempty(x.kwargs)
                f.print("; ")
                for (idx, (key, val)) in enumerate(x.kwargs)
                    idx > 1 && f.print(", ")
                    f.print(key, "=", val)
                end
            end
            f.print(")")
        end
    elseif isa_variant(x, Pattern.Tuple)
        f.print("(")
        for (idx, arg) in enumerate(x.xs)
            idx > 1 && f.print(", ")
            f.show(arg)
        end
        f.print(")")
    elseif isa_variant(x, Pattern.NamedTuple)
        f.print("(")
        for (idx, arg) in enumerate(x.xs)
            idx > 1 && f.print(", ")
            f.print(x.names[idx], "=", arg)
        end
        f.print(")")
    elseif isa_variant(x, Pattern.Vector)
        f.print("[")
        for (idx, arg) in enumerate(x.xs)
            idx > 1 && f.print(", ")
            f.show(arg)
        end
        f.print("]")
    elseif isa_variant(x, Pattern.Row)
        for (idx, arg) in enumerate(x.xs)
            idx > 1 && f.print(" ")
            f.show(arg)
        end
    elseif isa_variant(x, Pattern.NRow)
        for (idx, arg) in enumerate(x.xs)
            idx > 1 && f.print(";"^x.n)
            f.show(arg)
        end
    elseif isa_variant(x, Pattern.VCat)
        show_vcat(f, x)
    elseif isa_variant(x, Pattern.HCat)
        show_hcat(f, x)
    elseif isa_variant(x, Pattern.NCat)
        show_ncat(f, x)
    elseif isa_variant(x, Pattern.TypedVCat)
        f.print(x.type; color=:light_cyan)
        show_vcat(f, x)
    elseif isa_variant(x, Pattern.TypedHCat)
        f.print(x.type; color=:light_cyan)
        show_hcat(f, x)
    elseif isa_variant(x, Pattern.TypedNCat)
        f.print(x.type; color=:light_cyan)
        show_ncat(f, x)
    elseif isa_variant(x, Pattern.Splat)
        f.show(x.body)
        f.print("...")
    elseif isa_variant(x, Pattern.TypeAnnotate)
        f.show(x.body)
        f.print("::")
        f.print(x.type; color=:light_cyan)
    elseif isa_variant(x, Pattern.Generator)
        f.show(x.body)
        f.print(" for ")
        for (idx, (var, iter)) in enumerate(zip(x.vars, x.iterators))
            idx > 1 && f.print(", ")
            f.print(var)
            f.print(" in ")
            f.show(iter)
        end

        if !isnothing(x.filter)
            f.print(" if ")
            f.show(x.filter)
        end
    elseif isa_variant(x, Pattern.Comprehension)
        f.print("[")
        f.show(x.body)
        f.print("]")
    else
        error("unknown pattern type: ", x)
    end
end

function show_vcat(f::Data.FormatPrinter, x::Pattern.Type)
    f.print("[")
    for (idx, arg) in enumerate(x.xs)
        idx > 1 && f.print("; ")
        f.show(arg)
    end
    return f.print("]")
end

function show_hcat(f::Data.FormatPrinter, x::Pattern.Type)
    f.print("[")
    for (idx, arg) in enumerate(x.xs)
        idx > 1 && f.print(" ")
        f.show(arg)
    end
    return f.print("]")
end

function show_ncat(f::Data.FormatPrinter, x::Pattern.Type)
    f.print("[")
    for (idx, arg) in enumerate(x.xs)
        idx > 1 && f.print(";"^x.n)
        f.show(arg)
    end
    return f.print("]")
end
