module CurveDiagrams

export EndpointDirection, IN, OUT
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece
include("tile/curvepiece.jl")

export EndpointRef, cp_partner, Tile
# tile geometry
export num_edges, next_edge, prev_edge
# eref getters
export has_edge_erefs, num_edge_erefs, edge_erefs
export has_edge_eref, edge_eref
export num_anyon_erefs, has_anyon_erefs, anyon_erefs, anyon_eref
# eref traversal
export next_eref, prev_eref, next_eref_wrap, prev_eref_wrap
export ordered_erefs, erefs_between, unpaired_erefs
# endpoints
export endpoint, cp_partner_type, tile_partner
# curvepieces
export curvepiece_ids, anyon_cp_ids, partner_cp_id, u_turn_cp_ids
export curvepiece, is_anyon_curvepiece, anyon_curve_id, anyon_count
export calculate_nesting_hierarchy
include("tile/tile.jl")

export insert_curvepiece!, remove_curvepiece!, merge_curvepieces!
export move_endpoint!, reverse_curvepiece!, set_curvepiece_metadata!
include("tile/mutators.jl")

export CurvepieceRef, TileEdgeRef, Lattice
# geometry
export num_tiles, get_tile, corresponding_edge, shared_edge
# curve diagrams
export num_curves, curve_ids, get_curvediagram, is_deleted
# endpoints
export sibling_location, sibling_insert_pos, sibling_eref
# curvepieces
export find_cref_index, prev_curvepiece, next_curvepiece
# anyons
export anyon_tiles, next_anyon, prev_anyon
include("lattice/lattice.jl")

export visualize!, visualize
function visualize! end
function visualize end

end # module CurveDiagrams
