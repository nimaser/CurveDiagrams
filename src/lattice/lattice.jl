"""
We identify each `Curvepiece` in a lattice by storing its tile and its id within that tile.
"""
struct CurvepieceRef
    tile_id::Int
    cp_id::Int
end

"""A curve diagram is a list of sequential curvepieces."""
const CurveDiagram = Vector{CurvepieceRef}

"""
We identify each edge of a tile in a lattice by storing its tile and its edge number within that tile.
"""
struct TileEdgeRef
    tile_id::Int
    edge::Int
end

"""
A `Lattice` is a collection of `Tile`s connected by sharing edges. Curve diagrams snake through
the `Tile`s on the lattice. A lattice must be defined on a closed, compact manifold, e.g. a sphere
or a torus. The fields of this struct should not be directly modified by the user.

`_tiles[tile_id]` gives the `Tile` with id `tile_id`
`_adjacency[tile_id][edge]` gives a `TileEdgeRef` for the corresponding edge in the neighboring tile
`_curvediagrams[curve_id]` gives the `CurveDiagram` with id `curve_id`

`_curvediagrams` is stored as an array which has a uniform eltype of `CurveDiagram` - this means that
unlike the case of `_curvepieces` in `Tile`, we don't need to store `nothing` but can just use empty
vectors for deleted curve diagrams, meaning our array is homogeneously typed. Furthermore, we assume
that we have a reasonable upper bound on the number of curve diagrams created, meaning the array size
has a maximum, and it can't be more than the number of simulated tiles, which is not going to be more
than a few hundred, meaning worst case we have a few hundred pointers to empty lists, which is not
extraordinarily memory intensive.

The `Lattice` constructor accepts `adjacency` and creates the necessary `Tile`s and other internal
datastructures from it. `adjacency` should use tuples of `tile_id`, `edge` rather than `TileEdgeRef`
structs, and the conversion is done internally. `edge` should be assigned in clockwise order
going around each tile starting from 1.
"""
struct Lattice
    _tiles::Vector{Tile}
    _adjacency::Vector{Vector{TileEdgeRef}}
    _curvediagrams::Vector{CurveDiagram}
    function Lattice(adjacency::Vector{Vector{Tuple{Int, Int}}})
        adjacency = [[TileEdgeRef(edge_dat...) for edge_dat in tile_dat] for tile_dat in adjacency]
        tiles = Tile[]
        for tile_id in eachindex(adjacency)
            for edge in eachindex(adjacency[tile_id])
                # simple validation that each edge's partner has that original edge as its partner;
                # in other words, that finding corresponding edges is its own inverse operation
                cedge = adjacency[tile_id][edge]
                this_edge = adjacency[cedge.tile_id][cedge.edge]
                this_edge.tile_id == tile_id && this_edge.edge == edge ||
                    throw(ArgumentError("edge correspondence inconsistency on $this_edge and $cedge"))
            end
            # add the tile to the list
            push!(tiles, Tile(length(adjacency[tile_id])))
        end
        curvediagrams = CurveDiagram[]
        new(tiles, adjacency, curvediagrams)
    end
end

### PUBLIC GETTERS ###

"""Returns the number of tiles in the lattice."""
num_tiles(l::Lattice) = length(l._tiles)

"""Returns the `Tile` with id `tile_id` in `l`."""
get_tile(l::Lattice, tile_id::Int) = l._tiles[tile_id]

"""Returns the `TileEdgeRef` for the edge corresponding to the provided one."""
corresponding_edge(l::Lattice, tile_id::Int, edge::Int) = l._adjacency[tile_id][edge]

"""
Returns the edge numbers `(edge1, edge2)` such that `_adjacency[tile_id1][edge1]` points to
`tile_id2` and vice versa. Returns `nothing` if the tiles do not share an edge.
"""
function shared_edge(l::Lattice, tile_id1::Int, tile_id2::Int)
    for (e, ter) in enumerate(l._adjacency[tile_id1])
        ter.tile_id == tile_id2 && return e, ter.edge
    end
    nothing
end

"""
Returns the number of allocated curve ids, including ids for deleted (empty) curve diagrams.
Use `curve_ids(l)` to get only active curves.
"""
num_curves(l::Lattice) = length(l._curvediagrams)

"""Returns all non-deleted curve ids, in allocation order."""
curve_ids(l::Lattice) = [i for i in 1:num_curves(l) if !is_deleted(l, i)]

"""Returns the `CurveDiagram` with id `curve_id` in `l`."""
get_curvediagram(l::Lattice, curve_id::Int) = l._curvediagrams[curve_id]

"""
A deleted curve diagram has had its `CurvepieceRef`s removed and its id permanently retired.
A deleted id will never be reallocated by `_allocate_curve_id!`.
"""
is_deleted(l::Lattice, curve_id::Int) = isempty(l._curvediagrams[curve_id])

"""
Curvepieces can only start or end at anyons, so being made up of curvepieces, any `CurveDiagram`
can also only start or end on an anyon. This means that any curvepiece endpoint on a tile edge
must have a 'sibling' endpoint which lives on the corresponding edge in the adjacent tile. For
any edge with N endpoints on it, its corresponding edge also has N endpoints.

Given an edge endpoint in `tile_id`, this function returns `(neighbor_tile_id, EndpointRef)` of its
sibling endpoint. Note that because endpoint positions on edges are assigned clockwise and 1-indexed,
if an endpoint has position `n` out of `N` total endpoints on an edge, its sibling endpoint has position
`N - n + 1` on the corresponding edge.
"""
function sibling_endpoint(l::Lattice, tile_id::Int, eref::EndpointRef)
    ep::EdgeEndpoint = get_endpoint(get_tile(l, tile_id), eref)
    cedge = corresponding_edge(l, tile_id, ep.edge)
    neighbortile = get_tile(l, cedge.tile_id)
    N = num_endpoints(neighbortile, cedge.edge)
    sibling_pos = N - ep.pos + 1
    cedge.tile_id, get_edge_EndpointRef(neighbortile, cedge.edge, sibling_pos)
end

"""Returns a `Vector{EndpointRef}` with an or all curvepieces in `tile_id` with an endpoint on `edge`."""
# curvepieces_on_edge(l::Lattice, tile_id::Int, edge::Int) =
#     get_edge_EndpointRefs(get_tile(l, tile_id), edge)

"""
Returns the tile and curvepiece ids for the curvepiece which precedes `cp_id` in its
curve diagram.

For `cp_id` being an edge-to-edge curvepiece:
Returns `(neighbor_tile_id, neighbor_cp_id)` for the corresponding curvepiece across the
edge hosting `endpoint1` (the `IN` endpoint) of the given curvepiece `cp_id`. This is
the curvepiece that comes *before* `cp_id` in curve diagram traversal order.

If `cp_id` is an edge-to-anyon curvepiece, it will do the above or return the other
edge-to-anyon curvepiece in the same tile, depending on whether `cp_id` refers to the
first or second such curvepiece in the tile.

Returns `nothing` if `endpoint1` is an `AnyonEndpoint` (the curvepiece is at
the start of its curve).
"""
function prev_curvepiece(l::Lattice, tile_id::Int, cp_id::Int)
    t = get_tile(l, tile_id)
    cp = get_curvepiece(t, cp_id)
    if cp.endpoint1 isa AnyonEndpoint
        partner = get_partner_cp_id(t, cp_id)
        partner === nothing && return nothing
        return tile_id, partner
    end
    neighbor_tile_id, neighbor_eref = sibling_endpoint(l, tile_id, EndpointRef(cp_id, 1))
    neighbor_tile_id, neighbor_eref.cp_id
end

"""
Returns the tile and curvepiece ids for the curvepiece which follows `cp_id` in its
curve diagram.

For `cp_id` being an edge-to-edge curvepiece:
Returns `(neighbor_tile_id, neighbor_cp_id)` for the corresponding curvepiece across the
edge hosting `endpoint2` (the `OUT` endpoint) of the given curvepiece `cp_id`. This is
the curvepiece that comes *after* `cp_id` in curve diagram traversal order.

If `cp_id` is an edge-to-anyon curvepiece, it will do the above or return the other
edge-to-anyon curvepiece in the same tile, depending on whether `cp_id` refers to the
first or second such curvepiece in the tile.

Returns `nothing` if `endpoint2` is an `AnyonEndpoint` (the curvepiece is at
the end of its curve).
"""
function next_curvepiece(l::Lattice, tile_id::Int, cp_id::Int)
    t = get_tile(l, tile_id)
    cp = get_curvepiece(t, cp_id)
    if cp.endpoint2 isa AnyonEndpoint
        partner = get_partner_cp_id(t, cp_id)
        partner === nothing && return nothing
        return tile_id, partner
    end
    neighbor_tile_id, neighbor_eref = sibling_endpoint(l, tile_id, EndpointRef(cp_id, 2))
    neighbor_tile_id, neighbor_eref.cp_id
end

"""
Returns the 1-based position in the curve diagram where `CurvepieceRef(tile_id, cp_id)` appears,
or `nothing` if not found.
"""
function find_curve_position(l::Lattice, curve_id::Int, tile_id::Int, cp_id::Int)
    target = CurvepieceRef(tile_id, cp_id)
    findfirst(==(target), l._curvediagrams[curve_id])
end


"""
Returns the `curve_id` of the curve diagram which contains the anyon of the tile
with id `tile_id`. Returns nothing if that tile's anyon is not on any curve diagram.
"""
function anyon_curve_id(l::Lattice, tile_id::Int)
    t = get_tile(l, tile_id)
    anyon_curve_id(t)
end

"""
Function to get the tiles which contain anyons on a specific curve.

Returns a vector of `tile_id`s for tiles which contain anyons which are on the curve with `curve_id`.
Tiles are returned in path order.
"""
function anyon_tiles(l::Lattice, curve_id::Int)
    ids = Int[] # returned result, containing tile_ids
    seen = Set{Int}() # tile_ids for tiles with anyons which have already been added to ids
    # go through all of the CurvepieceRefs in the curve
    for ref in get_curvediagram(l, curve_id)
        ref.tile_id ∈ seen && continue # only one anyon per tile, so we can just skip
        t = get_tile(l, ref.tile_id)
        if is_anyon_curvepiece(t, ref.cp_id)
            push!(ids, ref.tile_id)
            push!(seen, ref.tile_id)
        end
    end
    ids
end

### INTERNAL MUTATORS ###

"""Returns the next curve_id to be assigned."""
function _allocate_curve_id!(l::Lattice)
    push!(l._curvediagrams, CurvepieceRef[])
    length(l._curvediagrams)
end

"""
Inserts `ref` at position `pos` in the curve diagram with id `curve_id`.
"""
function _insert_CurvepieceRef!(l::Lattice, curve_id::Int, pos::Int, ref::CurvepieceRef)
    insert!(l._curvediagrams[curve_id], pos, ref)
end

"""
Removes the entry at position `pos` from the curve diagram with id `curve_id`.
"""
function _remove_CurvepieceRef!(l::Lattice, curve_id::Int, pos::Int)
    deleteat!(l._curvediagrams[curve_id], pos)
end

"""
For every entry in the curve diagram at list-position >= `from_pos`, calls
`set_curvepiece_metadata!` on its tile to add `delta` to `anyon_count`.
Call with `delta=+1` after inserting an anyon, `delta=-1` after removing one.
"""
function _shift_anyon_count!(l::Lattice, curve_id::Int, from_pos::Int, delta::Int)
    diagram = l._curvediagrams[curve_id]
    for pos in from_pos:length(diagram)
        ref = diagram[pos]
        t = get_tile(l, ref.tile_id)
        cp = get_curvepiece(t, ref.cp_id)
        set_curvepiece_metadata!(t, ref.cp_id, cp.curve_id, cp.anyon_count + delta)
    end
end

"""
Empties `l._curvediagrams[curve_id]`, permanently retiring the id. All `CurvepieceRef`s in the
diagram must have been removed from their tiles before calling this.
"""
function _delete_curvediagram!(l::Lattice, curve_id::Int)
    isempty(l._curvediagrams[curve_id]) || throw(ArgumentError("curvediagram $curve_id not empty"))
    empty!(l._curvediagrams[curve_id])
end

"""
Updates the `curve_id` field on every `Curvepiece` in every tile that currently has `old_curve_id`,
replacing it with `new_curve_id`. Used in `merge!` after the two `CurveDiagram` vectors have been
concatenated into the surviving curve. Does not delete `old_curve_id`; call `_delete_curvediagram!`
separately.
"""
function _relabel_curve!(l::Lattice, old_curve_id::Int, new_curve_id::Int)
    for ref in l._curvediagrams[new_curve_id]
        t = get_tile(l, ref.tile_id)
        cp = get_curvepiece(t, ref.cp_id)
        cp.curve_id == old_curve_id || continue
        set_curvepiece_metadata!(t, ref.cp_id, new_curve_id, cp.anyon_count)
    end
end
