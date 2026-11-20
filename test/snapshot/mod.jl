module TestSnapshot

using Test
using ReferenceTests: @test_reference
using Moshi.Data: @data
using Moshi.Match: @match
using Moshi.Derive: @derive

include("normalize.jl")

# Julia's printing of expressions changes between versions, so the references are only
# compared on the version they were generated with. Regenerate them after bumping this,
# with `JULIA_REFERENCETESTS_UPDATE=true`.
const SNAPSHOT_VERSION = v"1.13"

@data Message begin
    Quit()
    struct Move
        x::Int
        y::Int
    end
    Write(String)
end

@data Shape begin
    Circle(Float64)
    struct Rect
        w::Float64
        h::Float64
    end
end

@data Option{T} begin
    None()
    Some(T)
end

if (VERSION.major, VERSION.minor) != (SNAPSHOT_VERSION.major, SNAPSHOT_VERSION.minor)
    @info "skipping expansion snapshots: they are generated with Julia $SNAPSHOT_VERSION"
else
    @testset "@match" begin
        @test_reference "references/match/tuple.jl" snapshot(
            @__MODULE__, :(@match x begin
                (a, b) => a + b
                _ => 0
            end)
        )
        @test_reference "references/match/literal_or.jl" snapshot(
            @__MODULE__, :(@match x begin
                1 || 2 => :small
                y::Int => y
                _ => nothing
            end)
        )
        @test_reference "references/match/vector_splat.jl" snapshot(
            @__MODULE__, :(@match x begin
                [1, xs..., y] => (xs, y)
                _ => nothing
            end)
        )
        @test_reference "references/match/guard.jl" snapshot(
            @__MODULE__, :(@match x begin
                y && if y > 0
                end => y
                _ => 0
            end)
        )
        @test_reference "references/match/data.jl" snapshot(
            @__MODULE__, :(@match x begin
                Message.Quit() => 0
                Message.Move(; x, y) => x + y
                Message.Write(msg) => msg
            end)
        )
        @test_reference "references/match/expr.jl" snapshot(
            @__MODULE__, :(@match x begin
                :($f($(args...))) => (f, args)
                _ => nothing
            end)
        )
    end

    @testset "@data" begin
        @test_reference "references/data/shape.jl" snapshot(
            @__MODULE__, :(@data Shape begin
                Circle(Float64)
                struct Rect
                    w::Float64
                    h::Float64
                end
            end)
        )
        @test_reference "references/data/option.jl" snapshot(
            @__MODULE__, :(@data Option{T} begin
                None()
                Some(T)
            end)
        )
    end

    @testset "@derive" begin
        @test_reference "references/derive/eq.jl" snapshot(
            @__MODULE__, :(@derive Shape[Eq])
        )
        @test_reference "references/derive/show.jl" snapshot(
            @__MODULE__, :(@derive Shape[Show])
        )
    end
end

end # module
