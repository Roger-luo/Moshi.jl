function decons_and(info::PatternInfo, pat::Pattern.Type)
    return function and(value)
        return quote
            $(decons(info, pat.:1)(value)) && $(decons(info, pat.:2)(value))
        end
    end
end

function decons_or(info::PatternInfo, pat::Pattern.Type)
    return function or(value)
        placeholder_count = copy(info.placeholder_count)
        lhs = decons(info, pat.:1)(value)
        copy!(info.placeholder_count, placeholder_count)
        rhs = decons(info, pat.:2)(value)
        return quote
            $lhs || $rhs
        end
    end
end
