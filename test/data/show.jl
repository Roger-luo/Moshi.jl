using Test
using ExproniconLite: @expr, no_default
using Moshi.Data: Variant, Singleton, Named, Anonymous, Field, NamedField, TypeHead, TypeDef

ex = quote
    """
    Goo
    """
    Goo

    """
    GooBar
    """
    GooBar(Int, Int)

    """
    Baz
    """
    struct Baz
        x::Float64
        y::Float64 = 2.0
    end
end

def = TypeDef(Main, false, :Foo, ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, false, :(Foo{T}), ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, false, :(Foo{T} <: SuperType), ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, true, :Foo, ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, true, :(Foo{T}), ex)
show(devnull, MIME("text/plain"), def)

def = TypeDef(Main, true, :(Foo{T} <: SuperType), ex)
show(devnull, MIME("text/plain"), def)
