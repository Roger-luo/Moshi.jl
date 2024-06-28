function decons(::Type{Pattern.Wildcard}, ::PatternContext, pat::Pattern.Type)
    return function wildcard(value)
        return true
    end
end
