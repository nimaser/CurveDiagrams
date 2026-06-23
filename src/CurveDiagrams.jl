module CurveDiagrams

export EndpointDirection, IN, OUT
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece, change_endpoint_location
include("tile/curvepiece.jl")

export EndpointRef, curvepiece_partner
export Tile
include("tile/tile.jl")

# tile geometry
export num_edges, next_edge, prev_edge
# eref getters
export all_edge_erefs
export num_edge_erefs, has_edge_erefs, edge_erefs
export has_edge_eref, edge_eref
export num_anyon_erefs, has_anyon_erefs, anyon_erefs
export anyon_eref
# eref traversal
export next_eref, prev_eref
export next_eref_wrap, prev_eref_wrap
export clockwise_sort
# endpoints
export endpoint, curvepiece_partner_type, tile_partner
# curvepieces
export curvepiece_ids, curvepiece
export central_curvepiece_ids, is_central_curvepiece, other_central_curvepiece_id
export curve_id, anyon_count
export u_turn_curvepiece_ids, hugs_corner, nesting_hierarchy
include("tile/public_getters.jl")

export insert_curvepiece!, move_endpoint!, remove_curvepiece!
export edge_merge!, edge_split!, anyon_merge!, anyon_split!
export reverse_curvepiece!, set_curvepiece_metadata!
include("tile/public_mutators.jl")

export CurvepieceRef, TileEdgeRef
export Lattice
include("lattice/lattice.jl")

# geometry
export num_tiles, get_tile, corresponding_edge, shared_edge
# curve diagrams
export num_curves, curve_ids, get_curvediagram, is_deleted, tiles_in
# # endpoints
export sibling_location, sibling_insert_pos, sibling_eref
# # curvepieces
export find_cref_index, prev_curvepiece, next_curvepiece
# # anyons
export anyon_tiles, next_anyon, prev_anyon
include("lattice/public_getters.jl")

export create_pair!
export stretch!
include("lattice/public_mutators.jl")

export simplify!
include("lattice/simplify.jl")

export visualize!, visualize
function visualize! end
function visualize end

end # module CurveDiagrams
