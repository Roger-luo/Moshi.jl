begin
    value_1 = x
    if value_1 isa Base.Tuple{Any, Any}
        @goto next_1
    else
        @goto unmatched_1
    end
    @label next_1
    if Base.length(value_1) == 2
        @goto next_2
    else
        @goto unmatched_1
    end
    @label next_2
    Tuple_a_1 = Base.@inbounds(value_1[Base.firstindex(value_1)])
    @goto next_3
    @label next_3
    Tuple_b_1 = Base.@inbounds(value_1[Base.firstindex(value_1) + 1])
    @goto matched_1
    @label matched_1
    return_1 = let a = Tuple_a_1, b = Tuple_b_1
            a + b
        end
    @goto final_1
    @label unmatched_1
    return_1 = let
            0
        end
    @goto final_1
    Base.error("matching non-exhaustive")
    Base.@label final_1
    return_1
end
