function decons_wildcard(info::PatternInfo, pat::Pattern.Type)
    return function wildcard(value)
        return true
    end
end

function decons_variable(info::PatternInfo, pat::Pattern.Type)
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
        placeholder = placeholder!(info, pat.:1)
        info[pat.:1] = placeholder
        return quote
            $(placeholder) = $value
            true
        end
    end
end

function decons_quote(info::PatternInfo, pat::Pattern.Type)
    return function _quote(value)
        return xcall(PartialEq, :eq, value, pat.:1)
    end
end

function decons_splat(view_type_check, info::PatternInfo, pat::Pattern.Type)
    return function splat(value)
        if isa_variant(pat.body, Pattern.TypeAnnotate)
            type_check = view_type_check(value, pat.body.type)
            and_expr(type_check, decons(info, pat.body.body)(value))
        else
            decons(info, pat.body)(value)
        end
    end
end
