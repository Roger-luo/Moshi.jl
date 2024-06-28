function decons(::Type{Pattern.Quote}, ::PatternContext, pat::Pattern.Type)
    return function _quote(value)
        return xcall(Base, :(==), value, pat.:1)
    end
end
