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
going around each tile starting from 1. Two tiles sharing multiple edges with each other is unsupported.

Each lattice mutator function in the public API returns an 'action', a ... TODO
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

###############################################################################
# PUBLIC GETTERS
###############################################################################

### GEOMETRY ###

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

### CURVE DIAGRAMS ###

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

"""Return the set of tiles containing curvepieces from `curve_id`."""
tiles_in(l::Lattice, curve_id::Int) =
    Set{Int}(cref.tile_id for cref in get_curvediagram(l, curve_id))

### ENDPOINTS ###

"""
Curvepieces can only start or end at anyons, so being made up of curvepieces, any `CurveDiagram`
can also only start or end on an anyon. This means that any curvepiece endpoint on a tile edge
must have a 'sibling' endpoint which lives on the corresponding edge in the adjacent tile. For
any edge with N endpoints on it, its corresponding edge also has N endpoints.

Given a position `n` of an endpoint on an edge `edge` in `tile_id`, this function returns the
`(neighbor_tile_id, neighbor_edge, neighbor_pos)` of its sibling endpoint. Because endpoint
positions on edges are assigned clockwise and 1-indexed, if an endpoint has position `n` out of
`N` total endpoints on an edge, its sibling endpoint has position `N - n + 1` on the corresponding
edge.

This function cannot be relied upon when the lattice is in an incorrect state, i.e. when the
number of endpoints on an edge of one tile is different than the number on its corresponding edge.
This means that its use near tile mutation methods such as `insert_curvepiece!` must be cautious.

Similarly, note that using this function to get an insertion position will lead to wrong behavior
if used naively: getting the sibling location in tile t2 of (edge, pos) in tile t1, then inserting
at t1, edge, pos and t2, sibling_edge, sibling_pos, will not lead to aligned curvepieces. This is
because insertions on either side shift everything clockwise locally which are opposite directions
on either side of the edge. So the sibling insertion must be done at sibling_pos + 1.
"""
function sibling_location(l::Lattice, tile_id::Int, edge::Int, n::Int)
    cedge = corresponding_edge(l, tile_id, edge)
    neighbortile = get_tile(l, cedge.tile_id)
    N = num_edge_erefs(neighbortile, cedge.edge)
    sibling_pos = N - n + 1
    cedge.tile_id, cedge.edge, sibling_pos
end

"""
Return the insertion position on the corresponding edge for the sibling of a new endpoint
being inserted at position `pos` on `(tile_id, edge)`. Call this before inserting on
side 1, and use the result as `pos` when inserting the sibling endpoint on side 2.
"""
function sibling_insert_pos(l::Lattice, tile_id::Int, edge::Int, pos::Int)
    _, _, spos = sibling_location(l, tile_id, edge, pos)
    spos + 1
end

"""
Given an edge endpoint in `tile_id`, this function returns `(neighbor_tile_id, EndpointRef)` of its
sibling endpoint, using `sibling_location` internally.
"""
function sibling_eref(l::Lattice, tile_id::Int, eref::EndpointRef)
    ep::EdgeEndpoint = endpoint(get_tile(l, tile_id), eref)
    neighbor_tile_id, neighbor_edge, neighbor_pos = sibling_location(l, tile_id, ep.edge, ep.pos)
    neighbortile = get_tile(l, neighbor_tile_id)
    neighbor_tile_id, edge_eref(neighbortile, neighbor_edge, neighbor_pos)
end

### CURVEPIECES ###

"""
Returns the 1-based index in the curve diagram where `cref` appears, or `nothing` if not found.
"""
function find_cref_index(l::Lattice, curve_id::Int, cref::CurvepieceRef)
    findfirst(==(cref), l._curvediagrams[curve_id])
end

"""
Returns the `CurvepieceRef` for the curvepiece which precedes `cref` in its curve diagram.

For an edge-to-edge curvepiece: returns the `CurvepieceRef` for the corresponding curvepiece
across the edge hosting `endpoint1` (the `IN` endpoint). This is the curvepiece that comes
*before* `cref` in curve diagram traversal order.

If `cref` is an edge-to-anyon curvepiece, it will do the above or return the other
edge-to-anyon curvepiece in the same tile, depending on whether `cref` refers to the
first or second such curvepiece in the tile.

Returns `nothing` if `endpoint1` is an `AnyonEndpoint` (the curvepiece is at
the start of its curve).
"""
function prev_curvepiece(l::Lattice, cref::CurvepieceRef)
    t = get_tile(l, cref.tile_id)
    cp = curvepiece(t, cref.cp_id)
    if cp.endpoint1 isa AnyonEndpoint
        partner = partner_cp_id(t, cref.cp_id)
        partner === nothing && return nothing
        return CurvepieceRef(cref.tile_id, partner)
    end
    neighbor_tile_id, neighbor_eref = sibling_eref(l, cref.tile_id, EndpointRef(cref.cp_id, 1))
    CurvepieceRef(neighbor_tile_id, neighbor_eref.cp_id)
end

"""
Returns the `CurvepieceRef` for the curvepiece which follows `cref` in its curve diagram.

For an edge-to-edge curvepiece: returns the `CurvepieceRef` for the corresponding curvepiece
across the edge hosting `endpoint2` (the `OUT` endpoint). This is the curvepiece that comes
*after* `cref` in curve diagram traversal order.

If `cref` is an edge-to-anyon curvepiece, it will do the above or return the other
edge-to-anyon curvepiece in the same tile, depending on whether `cref` refers to the
first or second such curvepiece in the tile.

Returns `nothing` if `endpoint2` is an `AnyonEndpoint` (the curvepiece is at
the end of its curve).
"""
function next_curvepiece(l::Lattice, cref::CurvepieceRef)
    t = get_tile(l, cref.tile_id)
    cp = curvepiece(t, cref.cp_id)
    if cp.endpoint2 isa AnyonEndpoint
        partner = partner_cp_id(t, cref.cp_id)
        partner === nothing && return nothing
        return CurvepieceRef(cref.tile_id, partner)
    end
    neighbor_tile_id, neighbor_eref = sibling_eref(l, cref.tile_id, EndpointRef(cref.cp_id, 2))
    CurvepieceRef(neighbor_tile_id, neighbor_eref.cp_id)
end

### ANYONS ###

"""
Function to get the tiles which contain anyons on a specific curve.

Returns a vector of `tile_id`s for tiles which contain anyons which are on the
curve with `curve_id`. Tiles are returned in path order.

If this function turns out to be bottlenecking, a slightly more efficient solution
would be to scan the curve diagram's curvepieces with a window size of two, and
any time two successive curvepieces had the same tile_id, add them to the set.
This is because the only time this condition can be met is when there are two
anyon-to-edge curvepieces, meaning that tile's anyon is on the curve diagram.
The first and last anyons' tiles would need to be in the initial set as a special
case.
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

"""
Returns the id of the tile whose anyon is just after `tile_id`s anyon on its curve diagram.

Returns `nothing` if this is the last anyon on its curve diagram.
Throws an error if `tile_id`s anyon is not on a curve diagram.
"""
function next_anyon(l::Lattice, tile_id::Int)
    curve_id = anyon_curve_id(get_tile(l, tile_id))
    curve_id === nothing && throw(ArgumentError("tile $tile_id's anyon not on a curve diagram"))
    tiles = anyon_tiles(l, curve_id)
    idx = findfirst(==(tile_id), tiles)
    idx == length(tiles) ? nothing : tiles[idx + 1]
end

"""
Returns the id of the tile whose anyon is just before `tile_id`s anyon on its curve diagram.

Returns `nothing` if this is the first anyon on its curve diagram.
Throws an error if `tile_id`s anyon is not on a curve diagram.
"""
function prev_anyon(l::Lattice, tile_id::Int)
    curve_id = anyon_curve_id(get_tile(l, tile_id))
    curve_id === nothing && throw(ArgumentError("tile $tile_id's anyon not on a curve diagram"))
    tiles = anyon_tiles(l, curve_id)
    idx = findfirst(==(tile_id), tiles)
    idx == 1 ? nothing : tiles[idx - 1]
end
