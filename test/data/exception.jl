using Test
using Moshi.Data: Unreachable, IllegalDispatch

@test sprint(showerror, Unreachable()) == "unreachable reached"
@test sprint(showerror, IllegalDispatch("X")) ==
    "illegal dispatch, expect to be overloaded by @data: X"
