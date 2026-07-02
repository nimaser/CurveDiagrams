###############################################################################
# LATTICE GEOMETRY
###############################################################################

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

###############################################################################
# CURVES
###############################################################################

"""Returns all non-deleted curve ids, in allocation order."""
curve_ids(l::Lattice) = findall(map(!isempty, l._curves))
# [i for i in 1:num_curves(l) if !isempty(get_curve(l, i))]

"""Returns the `Curve` with id `curve_id` in `l`."""
get_curve(l::Lattice, curve_id::Int) = l._curves[curve_id]

"""Return the set of tiles containing curvepieces from `curve_id`."""
tiles_in(l::Lattice, curve_id::Int) =
    Set{Int}(cref.tile_id for cref in get_curve(l, curve_id))

"""
Returns the 1-based index in the curve diagram where `cref` appears, or `nothing` if not found.
"""
function find_cref_index(l::Lattice, curve_id::Int, cref::CurvepieceRef)
    findfirst(==(cref), l._curves[curve_id])
end
