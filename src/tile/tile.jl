"""
A reference to a curvepiece endpoint: contains the curvepiece's tile-unique id
`cp_id` and `endpoint_idx`, the index of the endpoint in the curvepiece (whether it
comes first or second).
"""
struct EndpointRef
    cp_id::Int
    endpoint_idx::Int  # 1 or 2, for Curvepiece.endpoint1/endpoint2
end

"""
Each `Tile` is comprised of a number of curvepieces which enter/exit the tile. Methods on
`Tile` manage all of the details of inserting, removing, and modifying curvepieces in
that `Tile`. The fields of a `Tile` should never be modified directly by user code.

Each tile assigns curvepiece ids in sequence starting from 1. `_next_cp_id` contains the id
which will be assigned to the next curvepiece that is created.

Each tile contains a dictionary `_curvepieces` which maps from curvepiece ids to `Curvepiece`
structs, which contain all of the information about each curvepiece. The reason to choose a
dictionary rather than an array here (unlike what we do in `Lattice` for `_curvediagrams`) is
that in this case if we store the curvepieces in an array, its eltype must be `Union{Nothing, Curvepiece}`.
This seems like it might induce a performance penalty, and more importantly there aren't clear
runtime guarantees on the maximum number of curvepieces that can be created in a tile during
the simulation, meaning if we did not use a `Dict` we could end up with an extremely large and
sparse array of `nothing` stored densely.

A tile can have any number of edges `n_edges`, which is the sole parameter for the constructor.
For each edge, we store a vector of `EndpointRef`s in the order the endpoints are encountered
when walking along the edges of the tile clockwise. This allows backward-lookups from endpoint
location to curvepiece struct. All of these vectors of `EndpointRef`s are themselves stored in
the vector `_edge_endpoints`, which has a length equal to `n_edges`.

This design pattern reflects the need to support two data access patterns:
- given the id of a curvepiece, we want to obtain the endpoint locations
- given the endpoint locations of a curvepiece, we want to obtain the curvepiece information
We also generally want to store all of the information about a curvepiece in one centralized
datastructure, and then to enable any 'backwards-lookups' or other data access patterns not
supported by the chosen data structure, store various lightweight references.

The alternative would be something like storing the endpoint objects in the edge endpoint lists,
and then storing an index into this list (which would therefore encode the location) in each
`Curvepiece`, which leads to the data being spread across two different datastructures, which is
less clean and adds layers of indirection when trying to perform lookups.

Finally, 0, 1, or 2 endpoints can be located at the anyon in each tile. These endpoints are
stored in `_anyon_endpoints`.
"""
struct Tile
    _next_cp_id::Ref{Int}
    _curvepieces::Dict{Int, Curvepiece}
    _edge_endpoints::Vector{Vector{EndpointRef}}
    _anyon_endpoints::Set{EndpointRef}
    Tile(n_edges::Int) = new(Ref(1), Dict{Int, Curvepiece}(), [EndpointRef[] for _ in 1:n_edges], Set{EndpointRef}())
end

### PUBLIC GETTERS ###

"""The number of edges in the tile `t`."""
num_edges(t::Tile) = length(t._edge_endpoints)

"""The next edge number after edge `edge` in the tile `t`."""
next_edge(t::Tile, edge::Int) = mod1(edge + 1, num_edges(t))

"""The prev edge number after edge `edge` in the tile `t`."""
prev_edge(t::Tile, edge::Int) = mod1(edge - 1, num_edges(t))

"""Whether the edge `edge` in tile `t` has any endpoints on it."""
has_endpoints(t::Tile, edge::Int) = !isempty(t._edge_endpoints[edge])

"""The number of endpoints present on edge `edge` in `t`."""
num_endpoints(t::Tile, edge::Int) = length(t._edge_endpoints[edge])

"""Number of curvepieces with an endpoint at the tile's anyon."""
num_anyon_curvepieces(t::Tile) = length(t._anyon_endpoints)

"""Gets the sorted list of all curvepiece ids present in `t`."""
curvepiece_ids(t::Tile) = sort(collect(keys(t._curvepieces)))

"""Gets the curvepiece with id `cp_id` inside of `t`."""
get_curvepiece(t::Tile, cp_id::Int) = t._curvepieces[cp_id]

"""Gets the endpoint in `t` pointed to by `eref`."""
get_endpoint(t::Tile, eref::EndpointRef) =
    eref.endpoint_idx == 1 ? t._curvepieces[eref.cp_id].endpoint1 : t._curvepieces[eref.cp_id].endpoint2

"""Gets the EndpointRef for the `pos`th endpoint located on edge `edge` in tile `t`."""
get_edge_EndpointRef(t::Tile, edge::Int, pos::Int) = t._edge_endpoints[edge][pos]

"""Gets a clockwise-ordered list of all EndpointRefs located on edge `edge` of tile `t`."""
get_edge_EndpointRefs(t::Tile, edge::Int) = collect(t._edge_endpoints[edge])

"""Gets a clockwise-ordered list of all EndpointRefs located on the edges of tile `t`."""
get_edge_EndpointRefs(t::Tile) = cat([get_edge_EndpointRefs(t, i) for i in 1:num_edges(t)]...; dims=1)

"""Gets a list of all the EndpointRefs for all endpoints located on the anyon in tile `t`."""
get_anyon_EndpointRefs(t::Tile) = collect(t._anyon_endpoints)

"""Gets an EndpointRef to the partner of the endpoint that `eref` is pointing to."""
get_partner_EndpointRef(eref::EndpointRef) = EndpointRef(eref.cp_id, 3 - eref.endpoint_idx)

"""Whether the partner of `eref` is an `EdgeEndpoint`."""
has_edge_partner(t::Tile, eref::EndpointRef) =
    get_endpoint(t, get_partner_EndpointRef(eref)) isa EdgeEndpoint

"""Whether the partner of `eref` is an `AnyonEndpoint`."""
has_anyon_partner(t::Tile, eref::EndpointRef) =
    get_endpoint(t, get_partner_EndpointRef(eref)) isa AnyonEndpoint

"""
If `cp_id`'s curvepiece has an endpoint at `t`'s anyon, returns the EndpointRef for that endpoint.
Otherwise, returns `nothing`.
"""
function get_anyon_EndpointRef(t::Tile, cp_id::Int)
    for eref in t._anyon_endpoints
        eref.cp_id == cp_id && return eref
    end
    nothing
end

"""Whether this curvepiece has an anyon endpoint."""
is_anyon_curvepiece(t::Tile, cp_id::Int) = get_anyon_EndpointRef(t, cp_id) != nothing

"""Returns `cp_id`s for all anyon-to-edge curvepieces in `t`."""
function get_anyon_cp_ids(t::Tile)
    erefs = get_anyon_EndpointRefs(t)
    erefs == nothing && return nothing
    [eref.cp_id for eref in erefs]
end

"""
Given an anyon curvepiece `cp_id` in tile `t`, returns the `cp_id` of the other anyon
curvepiece on the same curve (its partner), or `nothing` if no such piece exists. Throws
an error if `cp_id` is not an anyon curvepiece.
"""
function get_partner_cp_id(t::Tile, cp_id::Int)
    is_anyon_curvepiece(t, cp_id) ||
        throw(ArgumentError("curvepiece $cp_id is not an anyon curvepiece so has no partner"))
    anyon_ids = get_anyon_cp_ids(t)
    anyon_ids === nothing && return nothing
    partner_idx = findfirst(id -> id != cp_id, anyon_ids)
    partner_idx === nothing ? nothing : anyon_ids[partner_idx]
end

"""
Returns the `curve_id` of the curvepieces which have endpoints on the anyon, `nothing` if there are
no such curvepieces. If there are two curvepieces with endpoints on the anyon, note that they will
have the same `curve_id`.
"""
function anyon_curve_id(t::Tile)
    cp_ids = get_anyon_cp_ids(t)
    cp_ids == nothing && return nothing
    cp = get_curvepiece(t, first(cp_ids))
    cp.curve_id
end

"""
Returns the `EndpointRef` of the endpoint next encountered while traversing edge `edge` of `t` *clockwise*
starting at position `pos`. Returns `nothing` if there is no further endpoint on that edge.
"""
function next_EndpointRef_on_edge(t::Tile, edge::Int, pos::Int)
    endpoints = t._edge_endpoints[edge]
    pos < length(endpoints) ? endpoints[pos + 1] : nothing
end

"""
Returns the `EndpointRef` of the endpoint next encountered while traversing edge `edge` of `t` *counterclockwise*
starting at position `pos`. Returns `nothing` if there is no further endpoint on that edge.
"""
function prev_EndpointRef_on_edge(t::Tile, edge::Int, pos::Int)
    endpoints = t._edge_endpoints[edge]
    pos > 1 ? endpoints[pos - 1] : nothing
end

"""
Gets the `EndpointRef` of the endpoint next encountered when traversing `t`s edges *clockwise* starting at
position `pos` on edge `edge`.

If there is only one endpoint attached to the edges of the tile (for example, in the case where there is just
one curvepiece with one end connected to the anyon), the `EndpointRef` returned will be the one at `edge`, `pos`.
"""
function next_EndpointRef(t::Tile, edge::Int, pos::Int)
    # try to return the next endpointref on the same edge, if it exists
    next = next_EndpointRef_on_edge(t, edge, pos)
    if next !== nothing return next end
    # traverse the remaining edges, returning the first endpoint on the first nonempty one found
    e = next_edge(t, edge)
    while e != edge
        if has_endpoints(t, e) return get_edge_EndpointRef(t, e, 1) end
        e = next_edge(t, e)
    end
    # we wrapped back around to the starting edge, so return the first endpoint on it
    get_edge_EndpointRef(t, edge, 1)
end

"""
Gets the `EndpointRef` of the endpoint next encountered when traversing `t`s edges *counterclockwise* starting
at position `pos` on edge `edge`.

If there is only one endpoint attached to the edges of the tile (for example, in the case where there is just
one curvepiece with one end connected to the anyon), the `EndpointRef` returned will be the one at `edge`, `pos`.
"""
function prev_EndpointRef(t::Tile, edge::Int, pos::Int)
    # try to return the next endpointref on the same edge, if it exists
    prev = prev_EndpointRef_on_edge(t, edge, pos)
    if prev !== nothing return prev end
    # traverse the remaining edges, returning the first endpoint on the first nonempty one found
    e = prev_edge(t, edge)
    while e != edge
        if has_endpoints(t, e) return get_edge_EndpointRef(t, e, num_endpoints(t, e)) end
        e = prev_edge(t, e)
    end
    # we wrapped back around to the starting edge, so return the last endpoint on it
    get_edge_EndpointRef(t, edge, num_endpoints(t, e))
end

### INTERNAL MUTATORS ###

"""Returns the next cp_id to be assigned."""
function _allocate_cp_id!(t::Tile)
    id = t._next_cp_id[]
    t._next_cp_id[] += 1
    id
end

"""
Replaces the stored location (edge and pos) of one endpoint within a `Curvepiece`.

This function should be called for `EndpointRefs` whose locations have been shifted
as a result of other curvepiece endpoints being added/moved/removed. This is
necessary because endpoint locations are relative to all of the endpoints present
rather than being absolute. Note that this means `eref` must point to an `EdgeEndpoint`,
as `AnyonEndpoint`s do not have a location.

The direction or endpoint type (edge vs anyon) of the endpoint indicated by `eref`,
and its partner, does not change as a result of mutating other curvepieces. Therefore,
the ordering of the endpoints in the curvepiece does not change, so no revalidation
or reordering is needed.
"""
function _set_endpoint_location!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    ep::EdgeEndpoint = get_endpoint(t, eref)
    cp = get_curvepiece(t, eref.cp_id)
    if eref.endpoint_idx == 1
        t._curvepieces[eref.cp_id] = Curvepiece(cp.curve_id, cp.anyon_count,
            EdgeEndpoint(ep.direction, edge, pos), cp.endpoint2)
    else
        t._curvepieces[eref.cp_id] = Curvepiece(cp.curve_id, cp.anyon_count,
            cp.endpoint1, EdgeEndpoint(ep.direction, edge, pos))
    end
end

"""
Replaces the stored pos of an endpoint within a `Curvepiece`.

Convenience wrapper for _set_endpoint_location! for the case when an endpoint has been
shifted along an edge, so only the pos needs to be updated.
"""
_set_endpoint_pos!(t::Tile, eref::EndpointRef, new_pos::Int) =
    _set_endpoint_location!(t, eref, (get_endpoint(t, eref)::EdgeEndpoint).edge, new_pos)

"""Insert `eref` into edge `edge` at position `pos`, shifting subsequent endpoint locations up."""
function _insert_edge_EndpointRef!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    # shift all endpoints above the insertion point to have positions incremented by 1
    for oldendpointpos in pos:num_endpoints(t, edge)
        _set_endpoint_pos!(t, get_edge_EndpointRef(t, edge, oldendpointpos), oldendpointpos + 1)
    end
    # insert eref at pos
    insert!(t._edge_endpoints[edge], pos, eref)
end

"""Remove EndpointRef at position `pos` in edge `edge`, shifting subsequent endpoint locations down."""
function _remove_edge_EndpointRef!(t::Tile, edge::Int, pos::Int)
    # remove eref at pos
    deleteat!(t._edge_endpoints[edge], pos)
    # shift all endpoints above the removal point to have positions equal to their index in the array
    for newendpointpos in pos:num_endpoints(t, edge)
        _set_endpoint_pos!(t, get_edge_EndpointRef(t, edge, newendpointpos), newendpointpos)
    end
end

"""Pushes an EndpointRef onto the anyon. Errors if this would result in more than 2 endpoints on the anyon."""
function _push_anyon_EndpointRef!(t::Tile, eref::EndpointRef)
    length(t._anyon_endpoints) < 2 || throw(ArgumentError("cannot add another EndpointRef to the anyon"))
    push!(t._anyon_endpoints, eref)
end

### PUBLIC MUTATORS ###

include("mutators.jl")
