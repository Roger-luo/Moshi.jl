function decons(::Type{Pattern.Quote}, ::PatternContext, pat::Pattern.Type)
    return function _quote(value)
        return equal_expr(value, pat.:1)
    end
end
