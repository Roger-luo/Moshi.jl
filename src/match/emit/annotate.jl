function decons(::Type{Pattern.TypeAnnotate}, ctx::PatternContext, pat::Pattern.Type)
    return function annotate(value)
        return and_expr(:($value isa $(pat.type)), decons(ctx, pat.body)(value))
    end
end
