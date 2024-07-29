using Test
using Moshi.Match: @match

@test :x === @match :(x::Int) begin
    :($x::Int) => x
end

@test :y === @match :(x+y::Int) begin
    :(x+$x::Int) => x
end

a = 1
@test :x === @match :(x+$a::Int) begin
    :($x+$($a)::Int) => x
end

expr = quote
    struct S{T}
        a :: Int
        b :: T
    end
end

@test (:S, :T, :a, :Int, :b, :T) == @match expr begin
    quote
        struct $name{$tvar}
            $f1 :: $t1
            $f2 :: $t2
        end
    end => (name, tvar, f1, t1, f2, t2)
end
