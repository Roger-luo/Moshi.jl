module ExproniconBench

using Expronicon.ADT: @adt
using MLStyle: @match

@adt AT begin
    struct A
        common_field::Int = 0
        a::Bool = true
        b::Int = 10
    end
    struct B
        common_field::Int = 0
        a::Int = 1
        b::Float64 = 1.0
        d::Complex = 1 + 1.0im # not isbits
    end
    struct C
        common_field::Int = 0
        b::Float64 = 2.0
        d::Bool = false
        e::Float64 = 3.0
        k::Complex{Real} = 1 + 2im # not isbits
    end
    struct D
        common_field::Int = 0
        b::Any = "hi" # not isbits
    end
end

foo!(xs) =
    for i in eachindex(xs)
        @inbounds x = xs[i]
        @inbounds xs[i] = @match x begin
            AT.A(_...) => AT.D()
            AT.B(_...) => AT.A()
            AT.C(_...) => AT.B()
            AT.D(_...) => AT.A()
            _ => error("aaa")
        end
    end

end # ExproniconBench
