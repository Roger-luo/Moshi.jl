Base.@assume_effects :foldable function unsafe_padded_reinterpret(
    ::Type{T}, x::U
) where {T,U}
    @assert isbitstype(T) && isbitstype(U)
    n, m = sizeof(T), sizeof(U)
    if sizeof(U) < sizeof(T)
        payload = (x, ntuple(_ -> zero(UInt8), Val(n - m)))
    else
        payload = x
    end
    let r = Ref(payload)
        GC.@preserve r begin
            p = pointer_from_objref(r)
            unsafe_load(Ptr{T}(p))
        end
    end
end

Base.@assume_effects :foldable function padded_tuple_any(::Val{N}, x::Tuple) where {N}
    length(x) == N && return x
    return ntuple(Val(N)) do i
        i <= length(x) ? x[i] : nothing
    end
end
