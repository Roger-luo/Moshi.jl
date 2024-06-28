function decons(::Type{Pattern.Variable}, ctx::PatternContext, pat::Pattern.Type)
    return function variable(value)
        # NOTE: this is used to create a scope
        # using let ... end later, so we cannot
        # directly assign it to the pattern variable
        #
        # we use a new variable everytime we match a pattern
        # variable, so that we can check if duplicated
        # variables are equivalent later
        #
        # placeholder! is used to control within the same pattern
        # that branches created by or are using the same placeholder
        placeholder = var!(ctx, pat.:1)
        ctx[pat.:1] = placeholder
        return quote
            $(placeholder) = $value
            true
        end
    end
end
