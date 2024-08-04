module BaseBench

using Random

Base.@kwdef struct A
    common_field::Int = 0
    a::Bool = true
    b::Int = 10
end
Base.@kwdef struct B
    common_field::Int = 0
    a::Int = 1
    b::Float64 = 1.0
    d::Complex = 1 + 1.0im # not isbits
end
Base.@kwdef struct C
    common_field::Int = 0
    b::Float64 = 2.0
    d::Bool = false
    e::Float64 = 3.0
    k::Complex{Real} = 1 + 2im # not isbits
end
Base.@kwdef struct D
    common_field::Int = 0
    b::Any = "hi" # not isbits
end

struct Object
    data::Union{A,B,C,D}
end

function generate(len::Int)
    rng = Random.MersenneTwister(123)
    return rand(rng, (Object(A()), Object(B()), Object(C()), Object(D())), len)
end

function main!(xs)
    for i in eachindex(xs)
        x = xs[i]
        data = getfield(x, :data)
        if data isa A
            xs[i] = Object(B(data.common_field + 1, data.a, data.b, data.b))
            @goto final
        end

        if data isa B
            xs[i] = Object(C(data.common_field - 1, data.b, isodd(data.a), data.b, data.d))
            @goto final
        end

        if data isa C
            xs[i] = Object(D(data.common_field + 1, isodd(data.common_field) ? "hi" : "bye"))
            @goto final
        end
        
        xs[i] = Object(A(data.common_field - 1, data.b == "hi", data.common_field))
        @label final
    end
end

end # module
