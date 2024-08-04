module MoshiHackyBench

using Random
using Moshi.Data: Data, @data, isa_variant, variant_getfield
using Moshi.Match: @match

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
        k::Complex{Real} = 1 + 2im # not isbits
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
    @inbounds for i in eachindex(xs)
        x = xs[i]
        xs[i] = if isa_variant(x, AT.A)
            cf = Data.variant_getfield(x, AT.A, :common_field)
            a = Data.variant_getfield(x, AT.A, :a)
            b = Data.variant_getfield(x, AT.A, :b)
            AT.B(cf + 1, a, b, b)
        elseif isa_variant(x, AT.B)
            cf = Data.variant_getfield(x, AT.B, :common_field)
            a = Data.variant_getfield(x, AT.B, :a)
            b = Data.variant_getfield(x, AT.B, :b)
            d = Data.variant_getfield(x, AT.B, :d)
            AT.C(cf - 1, b, isodd(a), b, d)
        elseif isa_variant(x, AT.C)
            cf = Data.variant_getfield(x, AT.C, :common_field)
            AT.D(cf + 1, isodd(cf) ? "hi" : "bye")
        else
            cf = Data.variant_getfield(x, AT.D, :common_field)
            b = Data.variant_getfield(x, AT.D, :b)
            AT.A(cf - 1, b == "hi", cf)
        end
    end
end

end # module
