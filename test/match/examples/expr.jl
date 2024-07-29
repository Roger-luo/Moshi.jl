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
