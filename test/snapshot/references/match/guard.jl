begin
    value_1 = x
    And_y_1 = value_1
    @goto next_1
    @label next_1
    if And_y_1 > 0
        @goto matched_1
    else
        @goto unmatched_1
    end
    @label matched_1
    return_1 = let y = And_y_1
            y
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
