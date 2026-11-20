begin
    value_1 = x
    if value_1 isa Expr
        @goto next_1
    else
        @goto unmatched_1
    end
    @label next_1
    if value_1.head == :call
        @goto next_2
    else
        @goto unmatched_1
    end
    @label next_2
    if value_1.args isa Base.Vector
        @goto next_3
    else
        @goto unmatched_1
    end
    @label next_3
    if Base.length(value_1.args) >= 1
        @goto next_4
    else
        @goto unmatched_1
    end
    @label next_4
    Expression_f_1 = Base.@inbounds(value_1.args[Base.firstindex(value_1.args)])
    @goto next_5
    @label next_5
    placeholder_1 = Base.@views(value_1.args[Base.firstindex(value_1.args) + 1:var"end"])
    @goto next_6
    @label next_6
    Expression_args_1 = placeholder_1
    @goto matched_1
    @label matched_1
    return_1 = let f = Expression_f_1, args = Expression_args_1
            (f, args)
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
