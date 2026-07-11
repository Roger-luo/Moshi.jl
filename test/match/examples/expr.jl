using Test
using Moshi.Match: @match

@test :x === @match :(x::Int) begin
    :($x::Int) => x
end

@test :y === @match :(x + y::Int) begin
    :(x + $x::Int) => x
end

a = 1
@test :x === @match :(x + $a::Int) begin
    :($x + $($a)::Int) => x
end

expr = quote
    struct S{T}
        a::Int
        b::T
    end
end

@test (:S, :T, :a, :Int, :b, :T) == @match expr begin
    quote
        struct $name{$tvar}
            $f1::$t1
            $f2::$t2
        end
    end => (name, tvar, f1, t1, f2, t2)
end

@test (1, :aaa) == @match LineNumberNode(1, "aaa") begin
    LineNumberNode(line, file) => (line, file)
end

@testset "match LineNumberNode" begin
    (line,) = @match expr begin
        quote
            $(line::LineNumberNode)
            struct $name{$tvar}
                $f1::$t1
                $f2::$t2
            end
        end => (line, name, tvar, f1, t1, f2, t2)
    end
    @test line isa LineNumberNode

    @test @match expr begin
        quote
            $(line::LineNumberNode && if line.line == 0
            end)
            struct $name{$tvar}
                $f1::$t1
                $f2::$t2
            end
        end => false
        quote
            struct $name{$tvar}
                $f1::$t1
                $f2::$t2
            end
        end => true
    end

    @test expr.args[1].line == @match expr begin
        quote
            $(LineNumberNode(line, file))
            struct $name{$tvar}
                $f1::$t1
                $f2::$t2
            end
        end => line
    end
end # match LineNumberNode

@testset "splatting pattern in Exprs (#53)" begin
    # https://github.com/Roger-luo/Moshi.jl/issues/53
    # a splat interpolation `$(args...)` inside a quoted `Expr` pattern should
    # capture the remaining arguments, mirroring MLStyle's behavior.
    expr = :(a = sin(5))
    @test (:a, :sin, 5, Any[]) == @match expr begin
        :($out = $f($arg0, $(args...))) => (out, f, arg0, args)
        _ => nothing
    end

    # the trailing splat captures every remaining argument
    @test (:f, 1, [2, 3, 4]) == @match :(f(1, 2, 3, 4)) begin
        :($f($a, $(rest...))) => (f, a, rest)
        _ => nothing
    end

    # a splat that consumes zero arguments still matches
    @test (:g, 1, []) == @match :(g(1)) begin
        :($f($a, $(rest...))) => (f, a, rest)
        _ => nothing
    end

    # the captured splat elements keep their original (possibly nested) exprs
    @test (:k, :a, [:(b + c), :d]) == @match :(k(a, b + c, d)) begin
        :($f($x, $(mid...))) => (f, x, mid)
        _ => nothing
    end

    # a leading splat before a fixed trailing argument
    @test ([1, 2], 3) == @match :(h(1, 2, 3)) begin
        :(h($(front...), $last)) => (front, last)
        _ => nothing
    end

    # without a splat the argument count must match exactly
    @test :fallthrough == @match :(f(1, 2)) begin
        :($f($a)) => (:matched, f, a)
        _ => :fallthrough
    end
end # splatting pattern in Exprs
