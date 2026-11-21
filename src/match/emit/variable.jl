function decons(::Type{Pattern.Variable}, ctx::PatternContext, pat::Pattern.Type)
    return function variable(value)
        # NOTE: this is used to create a scope
        # using let ... end later, so we cannot
        # directly assign it to the pattern variable
        #
        # a name already bound on this path tests equality in place, so every
        # branch of an or pattern binds the name to the same placeholder
        name = pat.:1
        if get(ctx.variable_count, name, 0) > 0
            return equal_expr(placeholder(ctx, name, 1), value)
        end
        bound = var!(ctx, name)
        ctx[name] = bound
        return quote
            $(bound) = $value
            true
        end
    end
end
