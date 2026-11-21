begin
    value_1 = x
    if Base.:(===)(Base.:(==)(value_1, 1), true)
        @goto matched_1
    else
        @goto next_1
    end
    @label next_1
    if Base.:(===)(Base.:(==)(value_1, 2), true)
        @goto matched_1
    else
        @goto unmatched_1
    end
    @label matched_1
    return_1 = let
            :small
        end
    @goto final_1
    @label unmatched_1
    if value_1 isa Int
        @goto next_2
    else
        @goto unmatched_2
    end
    @label next_2
    TypeAnnotate_y_1 = value_1
    @goto matched_2
    @label matched_2
    return_1 = let y = TypeAnnotate_y_1
            y
        end
    @goto final_1
    @label unmatched_2
    return_1 = let
            nothing
        end
    @goto final_1
    Base.error("matching non-exhaustive")
    Base.@label final_1
    return_1
end
