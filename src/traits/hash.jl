module Hash

mutable struct Cache
    value::UInt64
    is_set::Bool
end

Cache() = Cache(0, false)

Base.getindex(cache::Cache) = cache.value
function Base.setindex!(cache::Cache, value)
    cache.value = value
    cache.is_set = true
    return cache
end

end # Hash
