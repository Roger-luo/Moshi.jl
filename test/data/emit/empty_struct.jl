# Issue #55

using Test
using Moshi.Data:
    @data, variant_kind, variant_fieldnames, variant_fieldtypes, is_data_type, Named

@data Food begin
    struct Apple end
    struct Banana end
    struct Pie
        slices::Int
    end
end

@testset "zero-field struct variant" begin
    @test variant_kind(Food.Apple) == Named
    @test variant_fieldnames(Food.Apple) == ()
    @test variant_fieldtypes(Food.Apple) == ()
    @test is_data_type(Food.Apple())
    @test propertynames(Food.Apple()) == ()
    @test Food.Pie(3).slices == 3
    @test Food.Pie(slices=4).slices == 4
end

@testset "zero-field struct variant precompiles" begin
    mktempdir() do dir
        src = joinpath(dir, "MoshiEmptyStructPC", "src")
        mkpath(src)
        write(
            joinpath(src, "MoshiEmptyStructPC.jl"),
            """
            module MoshiEmptyStructPC
            using Moshi.Data: @data
            @data Fruit begin
                struct Apple end
                struct Banana end
            end
            end
            """,
        )
        push!(LOAD_PATH, dir)
        try
            pkgid = Base.identify_package("MoshiEmptyStructPC")
            # This throws if the package cannot be precompiled
            d = Base.compilecache(pkgid, devnull, devnull)
            @test !(d isa Exception)
        finally
            filter!(!=(dir), LOAD_PATH)
        end
    end
end
