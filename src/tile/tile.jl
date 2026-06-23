###############################################################################
# TILE HELPER STRUCTS
###############################################################################

"""
A reference to a curvepiece endpoint contained within a tile. Type name is often
shortened to 'eref'. Contains:
- `cp_id`, the curvepiece's tile-unique id
- `endpoint_idx`, the index of the endpoint in the curvepiece (whether it comes
first or second)
"""
struct EndpointRef
    cp_id::Int
    endpoint_idx::Int  # 1 or 2, for Curvepiece.endpoints[endpoint_idx]
    function EndpointRef(cp_id, endpoint_idx)
        endpoint_idx ∈ [1, 2] || throw(ArgumentError("endpoint_idx must be 1 or 2, got $endpoint_idx"))
        new(cp_id, endpoint_idx)
    end
end

"""
Returns an `EndpointRef` for the curvepiece partner of the endpoint that `eref`
is pointing to.
"""
@inline curvepiece_partner(eref::EndpointRef) =
    EndpointRef(eref.cp_id, 3 - eref.endpoint_idx) # idx: 1 -> 2, 2 -> 1

###############################################################################
# TILE
###############################################################################

"""
Each `Tile` is comprised of a number of curvepieces which enter/exit the tile.
The fields of a `Tile` should not be modified directly by user code; instead,
public mutator methods on `Tile` manage all of the details of inserting,
removing, and modifying curvepieces in that `Tile`.

Each tile assigns curvepiece ids in sequence starting from 1. `_next_cp_id` contains
the id which will be assigned to the next curvepiece that is created.

Each tile contains a dictionary `_curvepieces` which maps from curvepiece ids to
`Curvepiece` structs, which each contain all of the information about a curvepiece.
The reason to choose a dictionary rather than an array here (unlike what we do in
`Lattice` for `_curvediagrams`) is that in this case if we store the curvepieces
in an array, its eltype must be `Union{Nothing, Curvepiece}`. This seems like it
might induce a performance penalty, and more importantly there aren't clear runtime
guarantees on the maximum number of curvepieces that can be created in a tile during
the simulation, meaning if we did not use a `Dict` we could end up with an extremely
large and sparse array of `nothing` stored densely.

A tile can have any number of edges `n_edges`, which is the sole parameter for
the constructor. For each edge, we store a vector of `EndpointRef`s in the order
the endpoints are encountered when walking along the edges of the tile clockwise.
This allows backward-lookups from endpoint location to curvepiece struct. All of
these vectors of `EndpointRef`s are themselves stored in the vector `_edge_erefs`,
which has a length equal to `n_edges`.

This design pattern reflects the need to support two data access patterns:
- given the id of a curvepiece, we want to obtain the endpoint locations
- given the endpoint locations of a curvepiece, we want to obtain the curvepiece
information

Also, we generally want to store all of the information about a curvepiece in one
centralized datastructure. Then, to enable any 'backwards-lookups' or other data
access patterns not supported by the chosen data structure, we store various
lightweight references.

The alternative would be something like storing the endpoint objects in the edge
endpoint lists, and then storing an index into this list (which would therefore
encode the location) in each `Curvepiece`. This leads to the data being spread
across two different datastructures, which is less clean and adds layers of
indirection when trying to perform lookups.

Finally, 0, 1, or 2 endpoints can be located at the anyon in each tile. These
`EndpointRef`s are stored in `_anyon_erefs`. This means that a tile can contain
0, 1, or 2 central curvepieces. If there are two central curvepieces in the tile,
they should be on the same curve diagram, where the incoming central curvepiece
has an `anyon_count` one less than the outgoing one.
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

"""Return the next cp_id to be assigned."""
function _allocate_cp_id!(t::Tile)
    id = t._next_cp_id[]
    t._next_cp_id[] += 1
    id
end

"""
Insert `eref` into edge `edge` at position `pos`, shifting subsequent endpoint
locations up.

Returns `nothing`.
"""
function _insert_edge_eref!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    erefs = t._edge_erefs[edge]
    # insert eref at pos
    insert!(erefs, pos, eref)
    # erefs above pos have been shifted upwards by one position, so we need to update
    # the positions of the corresponding CurvepieceEndpoints to match
    for erefpos in pos+1:length(erefs)
        shifted_eref = erefs[erefpos]
        cp = t._curvepieces[shifted_eref.cp_id]
        new_cp = change_endpoint_location(cp, shifted_eref.endpoint_idx, edge, erefpos)
        t._curvepieces[shifted_eref.cp_id] = new_cp
    end
end

"""
Remove `EndpointRef` at position `pos` in edge `edge`, shifting subsequent endpoint
locations down.

Returns `nothing`.
"""
function _remove_edge_eref!(t::Tile, edge::Int, pos::Int)
    erefs = t._edge_erefs[edge]
    # remove eref at pos
    deleteat!(erefs, pos)
    # erefs above pos have been shifted downwards by one position, so we need to update
    # the positions of the corresponding CurvepieceEndpoints to match
    for erefpos in pos:length(erefs)
        shifted_eref = erefs[erefpos]
        cp = t._curvepieces[shifted_eref.cp_id]
        new_cp = change_endpoint_location(cp, shifted_eref.endpoint_idx, edge, erefpos)
        t._curvepieces[shifted_eref.cp_id] = new_cp
    end
    nothing
end

"""
Push `eref` onto the anyon. Errors if this would result in more than 2 endpoints
on the anyon.

Returns `nothing`.
"""
function _push_anyon_eref!(t::Tile, eref::EndpointRef)
    length(t._anyon_erefs) < 2 || throw(ArgumentError("cannot add another EndpointRef to the anyon"))
    push!(t._anyon_erefs, eref)
    nothing
end

"""
Remove `eref` from the anyon.

Returns `nothing`.
"""
function _remove_anyon_eref!(t::Tile, eref::EndpointRef)
    delete!(t._anyon_erefs, eref)
    nothing
end
