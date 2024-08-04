using CairoMakie
using BenchmarkTools

function benchmark(mod::Module, N::Int)
    xs = getproperty(mod, :generate)(N)
    println("$(mod): $(Base.format_bytes(Base.summarysize(xs)))")
    result = @benchmark $(getproperty(mod, Symbol("main!")))($xs)
    display(result)
    return Base.summarysize(xs), minimum(result.times)/1e6 # ms
end

include("base.jl")
include("dsymtypes.jl")
include("expronicon.jl")
include("moshi.jl")
include("moshi_match.jl")
include("moshi_hacky.jl")
include("moshi_debug.jl")
include("sumtypes.jl")

data = Dict(
    "baseline" => benchmark(BaseBench, 10000),
    "DynamicSumTypes" => benchmark(DynamicSumTypesBench, 10000),
    "Expronicon" => benchmark(ExproniconBench, 10000),
    "Moshi (reflection)" => benchmark(MoshiBench, 10000),
    "Moshi (match)" => benchmark(MoshiMatchBench, 10000),
    "Moshi (hacky)" => benchmark(MoshiHackyBench, 10000),
    "SumType" => benchmark(SumTypeTest, 10000),
)

fig = barplot(
    [i for i in 1:length(data)],
    [each[2] for each in values(data)],
    axis = (
        xticks = (1:length(data), [key for key in keys(data)]),
        xticklabelrotation = pi/4,
    ),
)
