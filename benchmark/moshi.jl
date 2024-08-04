module MoshiBench

using Random
using Moshi.Data: Data, @data, isa_variant

@data AT begin
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
        k::Complex{Float64} = 1 + 2im # not isbits
    end
    struct D
        common_field::Int = 0
        b::Any = "hi" # not isbits
    end
end

function generate(len::Int)
    return rand(Random.MersenneTwister(123), (AT.A(), AT.B(), AT.C(), AT.D()), len)
end

function main!(xs)
    for i in eachindex(xs)
        x = xs[i]
        xs[i] = if isa_variant(x, AT.A)
            AT.B(x.common_field + 1, x.a, x.b, x.b)
        elseif isa_variant(x, AT.B)
            AT.C(x.common_field - 1, x.b, isodd(x.a), x.b, x.d)
        elseif isa_variant(x, AT.C)
            AT.D(x.common_field + 1, isodd(x.common_field) ? "hi" : "bye")
        else
            AT.A(x.common_field - 1, x.b == "hi", x.common_field)
        end
    end
end

end # MoshiBench
