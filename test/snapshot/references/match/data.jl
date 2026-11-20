begin
    value_1 = x
    value_2 = value_1
    @goto next_1
    @label next_1
    if Data.isa_variant(value_2, Main.TestSnapshot.Message.Quit)
        @goto matched_1
    else
        @goto unmatched_1
    end
    @label matched_1
    return_1 = let
            0
        end
    @goto final_1
    @label unmatched_1
    value_3 = value_1
    @goto next_2
    @label next_2
    if Data.isa_variant(value_3, Main.TestSnapshot.Message.Move)
        @goto next_3
    else
        @goto unmatched_2
    end
    @label next_3
    Call_y_1 = Data.variant_getfield(value_3, Main.TestSnapshot.Message.Move, :y)
    @goto next_4
    @label next_4
    Call_x_1 = Data.variant_getfield(value_3, Main.TestSnapshot.Message.Move, :x)
    @goto matched_2
    @label matched_2
    return_1 = let y = Call_y_1, x = Call_x_1
            x + y
        end
    @goto final_1
    @label unmatched_2
    value_4 = value_1
    @goto next_5
    @label next_5
    if Data.isa_variant(value_4, Main.TestSnapshot.Message.Write)
        @goto next_6
    else
        @goto unmatched_3
    end
    @label next_6
    Call_msg_1 = Data.variant_getfield(value_4, Main.TestSnapshot.Message.Write, 1)
    @goto matched_3
    @label matched_3
    return_1 = let msg = Call_msg_1
            msg
        end
    @goto final_1
    @label unmatched_3
    Base.error("matching non-exhaustive")
    Base.@label final_1
    return_1
end
