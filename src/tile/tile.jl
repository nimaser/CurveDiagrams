################################################################################
# TILE HELPER STRUCTS
################################################################################

"""
A reference to a `CurvepieceEndpoint` for a `Curvepiece` contained within a
`Tile`. Type name is often shortened to 'eref'. Contains:
- `cp_id`, the curvepiece's tile-unique id
- `endpoint_idx`, the index of the endpoint in the curvepiece (whether it comes
first or second)
"""
struct EndpointRef
    cp_id::Int
    endpoint_idx::Int  # 1 or 2, for Curvepiece.endpoints[endpoint_idx]
    function EndpointRef(cp_id, endpoint_idx)
        endpoint_idx ∈ (1, 2) || throw(ArgumentError("endpoint_idx must be 1 or 2, got $endpoint_idx"))
        new(cp_id, endpoint_idx)
    end
end

"""
Return an `EndpointRef` for the curvepiece partner of the `CurvepieceEndpoint`
that `eref` is pointing to.
"""
@inline curvepiece_partner(eref::EndpointRef) =
    EndpointRef(eref.cp_id, 3 - eref.endpoint_idx) # idx: 1 -> 2, 2 -> 1

################################################################################
# TILE
################################################################################

"""
A `Tile` stores all of the information related to curvepieces contained within
one face of a curve diagram's `Lattice`. Said face is an n-gon with a fixed but
unrestricted number of sides, `n_edges`, which is the sole parameter for the
`Tile` constructor. Each `Tile` contains one `Curvepiece` struct for each boundary
or central curvepiece contained within it, where said struct in principle contains
all of the information about its curvepiece.

The fields of a `Tile` should not be modified directly by user code; instead,
public mutator methods on `Tile` manage all of the details of inserting, removing,
and modifying curvepieces in that `Tile`, while public getter methods can be used
to query the `Tile`'s state.

Each `Curvepiece` within the `Tile` is assigned a unique id and stored internally
in a dictionary, `_curvepieces`, with its id as its key. Internally, each `Tile`
assigns curvepiece ids in sequence starting from `1`, tracking the next id to be
assigned with `_next_cp_id`, but this implementation shouldn't be relied upon.
Use `_allocate_cp_id!` to get ids for new curvepieces instead.

We choose a dictionary rather than an array here because if we were to store the
curvepieces in an array, using the index as the id, its eltype would have to be
`Union{Nothing, Curvepiece}` (because curvepieces can be removed), which might
induce a performance penalty. Furthermore, there aren't clear runtime guarantees
on the number of curvepieces that can be created in a tile during the simulation,
meaning that we could end up with an extremeley large and sparse array of `nothing`
stored densely.

For each edge, we store a vector of `EndpointRef`s, each of which identifies one
endpoint of one `Curvepiece`, in the order that the endpoints are encountered when
walking along the edges of the `Tile` clockwise. This allows backward-lookups from
endpoint location to `Curvepiece` struct. All of these vectors of `EndpointRef`s
are themselves stored in the vector `_edge_erefs`, which has length `n_edges`.

This design pattern allows us to store all of the information about all curvepieces
in one centralized, canonical location, while still enabling backwards-lookups via
lightweight references; overall, it reflects the need to support two data access
patterns:
- given the id of a curvepiece, get all of its information, e.g. endpoint locations
- given the endpoint locations of a curvepiece, get all of its information

The alternative would be something like storing the endpoint objects in the edge
endpoint lists, and then storing an index into this list (which would therefore
encode the location) in each `Curvepiece`. This leads to the data being spread
across two different datastructures, which is less clean and adds layers of
indirection when trying to perform lookups.

Additionally, a `Tile` can contain up to two central curvepieces, meaning it can
contain 0, 1, or 2 `AnyonEndpoint`s at its anyon. `EndpointRef`s for these endpoints
are stored in `_anyon_erefs`.

If there are two central curvepieces in the `Tile`, they should be on the same `Curve`,
where the incoming central curvepiece has an `anyon-count` one less than the outgoing
one.
"""
struct Tile
    _next_cp_id::Ref{Int}
    _curvepieces::Dict{Int, Curvepiece}
    _edge_erefs::Vector{Vector{EndpointRef}}
    _anyon_erefs::Set{EndpointRef}
    function Tile(n_edges::Int)
        n_edges > 0 || throw(ArgumentError("n_edges must be positive, got $n_edges"))
        n_edges isa Integer || throw(ArgumentError("n_edges must be an integer, got $n_edges"))
        new(Ref(1), Dict{Int, Curvepiece}(), [EndpointRef[] for _ in 1:n_edges], Set{EndpointRef}())
    end
end

################################################################################
# INTERNAL MUTATORS
################################################################################

"""Return the next cp_id to be assigned."""
@inline function _allocate_cp_id!(t::Tile)
    id = t._next_cp_id[]
    t._next_cp_id[] += 1
    id
end

"""
Insert `eref` at location `(edge, pos)` in `t`, shifting subsequent endpoint
locations up.

Return `nothing`.
"""
function _insert_edge_eref!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    erefs = t._edge_erefs[edge]
    insert!(erefs, pos, eref)
    # erefs now above pos have been shifted upwards by one index, so we need to
    # update the pos of the corresponding CurvepieceEndpoints to match
    for erefpos in pos+1:length(erefs)
        shifted_eref = erefs[erefpos]
        cp = t._curvepieces[shifted_eref.cp_id]
        new_cp = change_endpoint_location(cp, shifted_eref.endpoint_idx, edge, erefpos)
        t._curvepieces[shifted_eref.cp_id] = new_cp
    end
end

"""
Remove `EndpointRef` at location `(edge, pos)` in `t`, shifting subsequent endpoint
locations down.

Return `nothing`.
"""
function _remove_edge_eref!(t::Tile, edge::Int, pos::Int)
    erefs = t._edge_erefs[edge]
    deleteat!(erefs, pos)
    # erefs now at and above pos have been shifted downwards by one index, so we
    # need to update the pos of the corresponding CurvepieceEndpoints to match
    for erefpos in pos:length(erefs)
        # the interior of this loop is the same as that of _insert_edge_eref!
        shifted_eref = erefs[erefpos]
        cp = t._curvepieces[shifted_eref.cp_id]
        new_cp = change_endpoint_location(cp, shifted_eref.endpoint_idx, edge, erefpos)
        t._curvepieces[shifted_eref.cp_id] = new_cp
    end
    nothing
end

"""
Insert `eref` into `t`'s anyon. Errors if this would result in more than two
`AnyonEndpoint`s on the anyon.

Return `nothing`.
"""
@inline function _insert_anyon_eref!(t::Tile, eref::EndpointRef)
    length(t._anyon_erefs) < 2 || throw(ArgumentError("cannot add another EndpointRef to the anyon"))
    push!(t._anyon_erefs, eref)
    nothing
end

"""
Remove `eref` from `t`'s anyon.

Return `nothing`.
"""
@inline function _remove_anyon_eref!(t::Tile, eref::EndpointRef)
    delete!(t._anyon_erefs, eref)
    nothing
end
