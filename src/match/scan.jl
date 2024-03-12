struct EmitInfo
    mod::Module
    value::Any
    cases::Vector{Pattern.Type}
    exprs::Vector{Any}
    lines::Vector{Union{LineNumberNode,Nothing}}
    value_holder::Symbol
    final_label::Symbol
    return_var::Symbol
    source
end

function EmitInfo(mod::Module, value, body, source=nothing)
    # single pattern
    if Meta.isexpr(body, :call) && body.args[1] === :(=>)
        cases = [toplevel_expr2pattern(mod, body.args[2])]
        exprs = [body.args[3]]
        lines = [source]
    elseif Meta.isexpr(body, :block)
        line_info = source
        cases = Pattern.Type[]
        exprs, lines = Any[], Union{LineNumberNode,Nothing}[]
        for stmt in body.args
            if stmt isa LineNumberNode
                line_info = stmt
            elseif Meta.isexpr(stmt, :call) && stmt.args[1] === :(=>)
                push!(cases, toplevel_expr2pattern(mod, stmt.args[2]))
                push!(exprs, stmt.args[3])
                push!(lines, line_info)
            else
                throw(SyntaxError("invalid pattern table: $body"; source=line_info))
            end
        end
    else
        throw(SyntaxError("invalid pattern table: $body"; source))
    end

    return EmitInfo(
        mod,
        value,
        split_toplevel_or(cases, exprs, lines)...,
        gensym("value"),
        gensym("final"),
        gensym("return"),
        source,
    )
end

function split_toplevel_or(cases::Vector{Pattern.Type}, exprs::Vector, lines::Vector)
    new_cases, new_exprs, new_lines = Pattern.Type[], [], Union{LineNumberNode,Nothing}[]
    for (case, expr, line) in zip(cases, exprs, lines)
        if isa_variant(case, Pattern.Or)
            push!(new_cases, case.:1)
            push!(new_exprs, expr)
            push!(new_lines, line)

            push!(new_cases, case.:2)
            push!(new_exprs, expr)
            push!(new_lines, line)
        else
            push!(new_cases, case)
            push!(new_exprs, expr)
            push!(new_lines, line)
        end
    end
    return new_cases, new_exprs, new_lines
end

function toplevel_expr2pattern(mod::Module, expr)
    expr isa Symbol &&
        isdefined(mod, expr) &&
        return Pattern.Err("you are using a pattern variable \
                           name that is already defined \
                           in the module: $(expr). This can be \
                           ambiguous and cause unexpected behavior.")
    return expr2pattern(mod, expr)
end

function expr2pattern(mod::Module, expr)
    expr === :_ && return Pattern.Wildcard
    expr isa Symbol && return Pattern.Variable(expr)
    expr isa Expr || return Pattern.Quote(expr)

    head = expr.head
    head === :$ && return quote2pattern(mod, expr)
    head === :(&&) && return and2pattern(mod, expr)
    head === :(||) && return or2pattern(mod, expr)
    head === :if && return if2pattern(mod, expr)
    head === :ref && return ref2pattern(mod, expr)
    head === :call && return call2pattern(mod, expr)
    head === :. && return dot2pattern(mod, expr)
    head === :(::) && return type2pattern(mod, expr)
    head === :(=) && return kw2pattern(mod, expr)
    head === :tuple && return tuple2pattern(mod, expr)
    head === :vect && return vect2pattern(mod, expr)
    head === :vcat && return vcat2pattern(mod, expr)
    head === :hcat && return hcat2pattern(mod, expr)
    head === :ncat && return ncat2pattern(mod, expr)
    head === :typed_vcat && return typed_vcat2pattern(mod, expr)
    head === :typed_hcat && return typed_hcat2pattern(mod, expr)
    head === :typed_ncat && return typed_ncat2pattern(mod, expr)
    head === :row && return row2pattern(mod, expr)
    head === :nrow && return nrow2pattern(mod, expr)
    head === :... && return splat2pattern(mod, expr)
    head === :comprehension && return comprehension2pattern(mod, expr)
    head === :generator && return generator2pattern(mod, expr)

    return Pattern.Err("unsupported pattern expression: $(expr)")
end

function quote2pattern(mod::Module, expr)
    return Pattern.Quote(expr.args[1])
end

function and2pattern(mod::Module, expr)
    return Pattern.And(expr2pattern(mod, expr.args[1]), expr2pattern(mod, expr.args[2]))
end

function or2pattern(mod::Module, expr)
    return Pattern.Or(expr2pattern(mod, expr.args[1]), expr2pattern(mod, expr.args[2]))
end

function if2pattern(mod::Module, expr)
    cond = expr.args[1] # just ignore body
    return Pattern.Guard(cond)
end

function generator2pattern(mod::Module, expr)
    body = expr2pattern(mod, expr.args[1])
    if Meta.isexpr(expr.args[2], :filter) # contains if
        filter = expr2pattern(mod, expr.args[2].args[1])
        stmts = expr.args[2].args[2:end]
    else # just plain generator
        filter = nothing
        stmts = expr.args[2:end]
    end

    vars, iterators = Symbol[], Pattern.Type[]
    for each in stmts
        key, it = each.args
        push!(vars, key)
        push!(iterators, expr2pattern(mod, it))
    end
    return Pattern.Generator(body, vars, iterators, filter)
end

function ref2pattern(mod::Module, expr)
    return Pattern.Ref(expr.args[1], expr2pattern.(Ref(mod), expr.args[2:end]))
end

function comprehension2pattern(mod::Module, expr)
    return Pattern.Comprehension(generator2pattern(mod, expr.args[1]))
end

function splat2pattern(mod::Module, expr)
    return Pattern.Splat(expr2pattern(mod, expr.args[1]))
end

function ncat2pattern(mod::Module, expr)
    return Pattern.NCat(expr.args[1], expr2pattern.(Ref(mod), expr.args[2:end]))
end

function hcat2pattern(mod::Module, expr)
    return Pattern.HCat(expr2pattern.(Ref(mod), expr.args))
end

function vcat2pattern(mod::Module, expr)
    return Pattern.VCat(expr2pattern.(Ref(mod), expr.args))
end

function typed_ncat2pattern(mod::Module, expr)
    return Pattern.TypedNCat(
        expr.args[1], # type
        expr.args[2], # n
        expr2pattern.(Ref(mod), expr.args[2:end]),
    )
end

function typed_hcat2pattern(mod::Module, expr)
    return Pattern.TypedHCat(
        expr.args[1], # type
        expr2pattern.(Ref(mod), expr.args[2:end]),
    )
end

function typed_vcat2pattern(mod::Module, expr)
    return Pattern.TypedVCat(
        expr.args[1], # type
        expr2pattern.(Ref(mod), expr.args[2:end]),
    )
end

function row2pattern(mod::Module, expr)
    return Pattern.Row(expr2pattern.(Ref(mod), expr.args))
end

function nrow2pattern(mod::Module, expr)
    return Pattern.NRow(expr.args[1], expr2pattern.(Ref(mod), expr.args[2:end]))
end

function vect2pattern(mod::Module, expr)
    return Pattern.Vector(expr2pattern.(Ref(mod), expr.args))
end

function tuple2pattern(mod::Module, expr)
    return Pattern.Tuple(expr2pattern.(Ref(mod), expr.args))
end

function kw2pattern(mod::Module, expr)
    return Pattern.Kw(expr.args[1], expr2pattern(mod, expr.args[2]))
end

function type2pattern(mod::Module, expr)
    if length(expr.args) == 1
        return Pattern.TypeAnnotate(Pattern.Wildcard, expr.args[1])
    else
        return Pattern.TypeAnnotate(expr2pattern(mod, expr.args[1]), expr.args[2])
    end
end

function dot2pattern(mod::Module, expr)
    # NOTE: let's assume all dot expression
    # refers to some existing module/struct object
    # so they gets eval-ed later in the generated
    # code
    return Pattern.Quote(expr)
end

function call2pattern(mod::Module, expr)
    args = Pattern.Type[]
    kwargs = Dict{Symbol,Pattern.Type}()
    if Meta.isexpr(expr.args[2], :parameters)
        for each in expr.args[2].args
            if each isa Symbol
                key, val = (each, each)
            else
                key, val = each.args
            end
            kwargs[key] = expr2pattern(mod, val)
        end
    else
    end

    for each in expr.args[2:end]
        Meta.isexpr(each, :parameters) && continue
        if Meta.isexpr(each, :kw)
            key, val = each.args
            kwargs[key] = expr2pattern(mod, val)
        else
            push!(args, expr2pattern(mod, each))
        end
    end

    # NOTE: might need to eval this?
    return Pattern.Call(expr.args[1], args, kwargs)
end
