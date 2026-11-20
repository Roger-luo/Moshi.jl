begin
    value_1 = x
    if value_1 isa Base.Vector
        @goto next_1
    else
        @goto unmatched_1
    end
    @label next_1
    if Base.length(value_1) >= 2
        @goto next_2
    else
        @goto unmatched_1
    end
    @label next_2
    if Base.:(==)(Base.@inbounds(value_1[Base.firstindex(value_1)]), 1)
        @goto next_3
    else
        @goto unmatched_1
    end
    @label next_3
    placeholder_1 = Base.@views(value_1[Base.firstindex(value_1) + 1:var"end" - 1])
    @goto next_4
    @label next_4
    Vector_xs_1 = placeholder_1
    @goto next_5
    @label next_5
    Vector_y_1 = Base.@inbounds(value_1[var"end"])
    @goto matched_1
    @label matched_1
    return_1 = let y = Vector_y_1, xs = Vector_xs_1
            (xs, y)
        end
    @goto final_1
    @label unmatched_1
    return_1 = let
            nothing
        end
    @goto final_1
    Base.error("matching non-exhaustive")
    Base.@label final_1
    return_1
end
