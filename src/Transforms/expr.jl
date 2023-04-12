function expr_to_pattern(expr; line = nothing, toplevel::Bool=false)
    expr isa Symbol && return Pattern.Var(expr)
    expr isa Pattern.MoshiLiteralType && return Pattern.Literal(expr)

    pattern = if Meta.isexpr(expr, :call)
        name = expr.args[1]
        if Meta.isexpr(expr.args[2], :parameters)
            args = expr.args[3:end]
            kwargs = expr.args[2].args
        else
            args = expr.args[2:end]
            kwargs = []
        end

        args = pattern_map(args)
        kwargs = pattern_map(kwargs)
        args isa Vector{Pattern.Type} || return args
        kwargs isa Vector{Pattern.Type} || return kwargs

        Pattern.Call(
            # this gets forward to uncall despite what
            # it actually is, can decide what they
            # want to do with it later in validating
            Pattern.Literal(name),
            args, kwargs
        )
    elseif Meta.isexpr(expr, :tuple)
        patterns = pattern_map(expr.args)
        patterns isa Vector{Pattern.Type} || return patterns
        Pattern.Tuple(patterns...)
    elseif Meta.isexpr(expr, :vect)
        patterns = pattern_map(expr.args)
        patterns isa Vector{Pattern.Type} || return patterns
        Pattern.Array((1, ), patterns)
    elseif Meta.isexpr(expr, :vcat)
        all(x->Meta.isexpr(x, :row), expr.args) ||
            return Pattern.Err(InvalidPattern(;msg="invalid pattern", expr, line))
        dims = Int[length(expr.args), length(expr.args[1].args)]
        args = mapreduce(vcat, expr.args) do row
            expr_to_pattern.(row.args)
        end
        Pattern.Array(dims, args)
    elseif Meta.isexpr(expr, :kw)
        pattern = expr_to_pattern(expr.args[2])
        pattern.tag == Err && return pattern
        Pattern.Assign(expr.args[1], pattern)
    elseif Meta.isexpr(expr, :quote)
        pattern = quote_pattern(expr.args[1])
        pattern isa Pattern.Type && pattern.tag == Err && return pattern
        Pattern.Quote(pattern)
    elseif Meta.isexpr(expr, :(::)) && length(expr.args) == 1
        type = expr_to_pattern(expr.args[1]; line, toplevel)
        type.tag == Err && return type
        Pattern.Annotate(Pattern.NoExpr, type)
    elseif Meta.isexpr(expr, :(::)) && length(expr.args) == 2
        pattern = expr_to_pattern(expr.args[1]; line, toplevel)
        pattern.tag == Err && return pattern
        type = expr_to_pattern(expr.args[2]; line, toplevel)
        type.tag == Err && return type
        Pattern.Annotate(pattern, type)
    elseif Meta.isexpr(expr, :(<:))
        pattern = expr_to_pattern(expr.args[1]; line, toplevel)
        pattern.tag == Err && return pattern
        type = expr_to_pattern(expr.args[2]; line, toplevel)
        type.tag == Err && return type
        Pattern.Subtype(pattern, type)
    elseif Meta.isexpr(expr, :where)
        pattern = expr_to_pattern(expr.args[1]; line, toplevel)
        pattern.tag == Err && return pattern
        where_params = pattern_map(expr.args[2:end]; line, toplevel)
        where_params isa Vector{Pattern.Type} || return where_params
        Pattern.Where(pattern, where_params)
    elseif Meta.isexpr(expr, :comprehension)
    elseif Meta.isexpr(expr, :typed_comprehension)
    elseif Meta.isexpr(expr, :generator)
    else
        return Pattern.Err(InvalidPattern(;msg="invalid pattern", expr, line))
    end

    toplevel || return pattern
    # only wrap up the pattern if it's a top-level pattern
    return if isnothing(line)
        Pattern.Meta(pattern; expr)
    else
        Pattern.Meta(pattern; line, expr)
    end
end # expr_to_pattern

function quote_pattern(expr; line = nothing, toplevel::Bool=false)
    if Meta.isexpr(expr, :$)
        return expr_to_pattern(expr.args[1], line=line, toplevel=toplevel)
    elseif expr isa Expr
        ret = Expr(expr.head)
        for each in expr.args
            stmt = quote_pattern(each, line=line, toplevel=toplevel)
            stmt isa Pattern.Type && stmt.tag == Err && return stmt
            push!(ret.args, stmt)
        end
        return ret
    else
        return expr
    end
end # quote_pattern

function pattern_map(list; line = nothing, toplevel::Bool=false)
    ret = Vector{Pattern.Type}(undef, length(list))
    for (idx, each) in enumerate(list)
        pattern = expr_to_pattern(each; line, toplevel)
        pattern.tag == Err && return pattern
        ret[idx] = pattern
    end
    return ret
end
