function decons_splat(view_type_check, ctx::PatternContext, pat::Pattern.Type)
    return function splat(value)
        if isa_variant(pat.body, Pattern.TypeAnnotate)
            type_check = view_type_check(value, pat.body.type)
            and_expr(type_check, decons(ctx, pat.body.body)(value))
        else
            decons(ctx, pat.body)(value)
        end
    end
end
