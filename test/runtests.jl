using Test
using Moshi
using Moshi.IRTypes
using Moshi.Transforms

Transforms.expr_to_pattern(:(x + 1))
Transforms.expr_to_pattern(:([1 x 1;1 2 3]))
Transforms.expr_to_pattern(:(:(1 + a[$(x::Int)])))
Transforms.expr_to_pattern(:(::Int))
Transforms.expr_to_pattern(:(::T where {T <: Real}))
Transforms.expr_to_pattern(:(x::Int))
Transforms.expr_to_pattern(:([x for x in 1:3]))
ex = :([x for x in 1:3])
ex.head
ex.args[1]

ex = :(x for x in 1:3)
ex.args

function check_dict(A::Dict) 
    @match A begin
        Dict(a => 1, "b" => b) => (a, b)
        _ => error()
    end
end
