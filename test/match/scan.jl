using Test
using Moshi.Data.Prelude
using Moshi.Match: Pattern, expr2pattern

@test expr2pattern(:(_::Int)) == Pattern.TypeAnnotate(Pattern.Wildcard(), :Int)
@test expr2pattern(:(x::Int)) == Pattern.TypeAnnotate(Pattern.Variable(:x), :Int)
@test isa_variant(expr2pattern(:(x::$(Expr(:$, :Int)))), Pattern.Err)
@test expr2pattern(:($(Expr(:$, :x))::Int)) == Pattern.TypeAnnotate(Pattern.Quote(:x), :Int)
@test expr2pattern(:(x::Int && if x > 2
end)) ==
    Pattern.And(Pattern.TypeAnnotate(Pattern.Variable(:x), :Int), Pattern.Guard(:(x > 2)))
@test expr2pattern(:(Int[1, x])) ==
    Pattern.Ref(:Int, [Pattern.Quote(1), Pattern.Variable(:x)])
@test expr2pattern(:(Foo(x; y=1))) ==
    Pattern.Call(:Foo, [Pattern.Variable(:x)], Dict(:y => Pattern.Quote(1)))
@test expr2pattern(:((1, x, y))) ==
    Pattern.Tuple([Pattern.Quote(1), Pattern.Variable(:x), Pattern.Variable(:y)])
@test expr2pattern(:([1, x, y])) ==
    Pattern.Vector([Pattern.Quote(1), Pattern.Variable(:x), Pattern.Variable(:y)])
@test expr2pattern(:(x...)) == Pattern.Splat(Pattern.Variable(:x))

@test expr2pattern(:([1 x])) == Pattern.HCat([Pattern.Quote(1), Pattern.Variable(:x)])
@test expr2pattern(:([1; x])) == Pattern.VCat([Pattern.Quote(1), Pattern.Variable(:x)])
@test expr2pattern(:([1 x; y])) == Pattern.VCat([
    Pattern.Row([Pattern.Quote(1), Pattern.Variable(:x)]), Pattern.Variable(:y)
])
@test expr2pattern(:([
    1 2; 3 4;;;
    x 6; 7 8;;;
    9 0; 2 3
])) == Pattern.NCat(
    3,
    [
        Pattern.NRow(
            1,
            [
                Pattern.Row([Pattern.Quote(1), Pattern.Quote(2)]),
                Pattern.Row([Pattern.Quote(3), Pattern.Quote(4)]),
            ],
        ),
        Pattern.NRow(
            1,
            [
                Pattern.Row([Pattern.Variable(:x), Pattern.Quote(6)]),
                Pattern.Row([Pattern.Quote(7), Pattern.Quote(8)]),
            ],
        ),
        Pattern.NRow(
            1,
            [
                Pattern.Row([Pattern.Quote(9), Pattern.Quote(0)]),
                Pattern.Row([Pattern.Quote(2), Pattern.Quote(3)]),
            ],
        ),
    ],
)

@test expr2pattern(:(Float64[1, x, 3])) ==
    Pattern.Ref(:Float64, [Pattern.Quote(1), Pattern.Variable(:x), Pattern.Quote(3)])
@test expr2pattern(:(Float64[1 x 3])) == Pattern.TypedHCat(
    :Float64, [Pattern.Quote(1), Pattern.Variable(:x), Pattern.Quote(3)]
)
@test expr2pattern(:(Float64[1 x; y])) == Pattern.TypedVCat(
    :Float64, [Pattern.Row([Pattern.Quote(1), Pattern.Variable(:x)]), Pattern.Variable(:y)]
)
@test expr2pattern(:(Float64[
    x
    y
    z
])) == Pattern.TypedVCat(
    :Float64, [Pattern.Variable(:x), Pattern.Variable(:y), Pattern.Variable(:z)]
)

@test expr2pattern(:(Float64[
    1 2; 3 4;;;
    x 6; 7 8;;;
    9 0; 2 3
])) == Pattern.TypedNCat(
    :Float64,
    3,
    [
        Pattern.NRow(
            1,
            [
                Pattern.Row([Pattern.Quote(1), Pattern.Quote(2)]),
                Pattern.Row([Pattern.Quote(3), Pattern.Quote(4)]),
            ],
        ),
        Pattern.NRow(
            1,
            [
                Pattern.Row([Pattern.Variable(:x), Pattern.Quote(6)]),
                Pattern.Row([Pattern.Quote(7), Pattern.Quote(8)]),
            ],
        ),
        Pattern.NRow(
            1,
            [
                Pattern.Row([Pattern.Quote(9), Pattern.Quote(0)]),
                Pattern.Row([Pattern.Quote(2), Pattern.Quote(3)]),
            ],
        ),
    ],
)
