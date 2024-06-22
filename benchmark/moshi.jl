using Test
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
        k::Complex{Real} = 1 + 2im # not isbits
    end
    struct D
        common_field::Int = 0
        b::Any = "hi" # not isbits
    end
end

foo!(xs) = for i in eachindex(xs)
    x = xs[i]
    data = getfield(x, :data)
    xs[i] = if data isa AT.var"##Storage#A"
        AT.B(data.common_field+1, data.a, data.b, data.b)
    elseif data isa AT.var"##Storage#B"
        AT.C(data.common_field-1, data.b, isodd(data.a), data.b, data.d)
    elseif data isa AT.var"##Storage#C"
        AT.D(data.common_field+1, isodd(data.common_field) ? "hi" : "bye")
    else
        AT.A(data.common_field-1, data.b == "hi", data.common_field)
    end
end

# foo!(xs) = for i in eachindex(xs)
#     x = xs[i]
#     data = getfield(x, :data)
#     xs[i] = if data isa AT.var"##Storage#A"
#         AT.Type(AT.var"##Storage#B"(data.common_field+1, data.a, data.b, data.b))
#     elseif data isa AT.var"##Storage#B"
#         AT.Type(AT.var"##Storage#C"(data.common_field-1, data.b, isodd(data.a), data.b, data.d))
#     elseif data isa AT.var"##Storage#C"
#         AT.Type(AT.var"##Storage#D"(data.common_field+1, isodd(data.common_field) ? "hi" : "bye"))
#     else
#         AT.Type(AT.var"##Storage#A"(data.common_field-1, data.b == "hi", data.common_field))
#     end
# end

# foo!(xs) = for i in eachindex(xs)
#     x = xs[i]
#     xs[i] = if @inline isa_variant(x, AT.A)
#         AT.B(x.common_field+1, x.a, x.b, x.b)
#     elseif @inline isa_variant(x, AT.B)
#         AT.C(x.common_field-1, x.b, isodd(x.a), x.b, x.d)
#     elseif @inline isa_variant(x, AT.C)
#         AT.D(x.common_field+1, isodd(x.common_field) ? "hi" : "bye")
#     else
#         AT.A(x.common_field-1, x.b == "hi", x.common_field)
#     end
# end

using Random
rng = Random.MersenneTwister(123)
xs = rand(rng, (AT.A(), AT.B(), AT.C(), AT.D()), 10000)

@code_warntype foo!(xs)

using BenchmarkTools
@benchmark foo!($xs)

@profview for _ in 1:1000
    foo!(xs)
end
