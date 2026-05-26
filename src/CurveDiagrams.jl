module CurveDiagrams

export EndpointDirection, IN, OUT
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece
include("tile/curvepiece.jl")

export EndpointRef, Tile
export num_edges, next_edge, prev_edge # tile geometry
export has_edge_erefs, has_edge_eref, num_edge_erefs, num_anyon_erefs
export edge_eref, edge_erefs, anyon_erefs, anyon_eref, endpoint
export curvepiece_ids, curvepiece
export calculate_nesting_hierarchy
export cp_partner, cp_partner_type
export tile_partner
export is_anyon_curvepiece, anyon_cp_ids, partner_cp_id, anyon_curve_id
export next_eref, prev_eref, next_eref_wrap, prev_eref_wrap
export erefs_between, unpaired_erefs, ordered_erefs
include("tile/tile.jl")

export insert_curvepiece!, remove_curvepiece!, move_endpoint!, flip_direction!, set_curvepiece_metadata!
include("tile/mutators.jl")

export CurvepieceRef, TileEdgeRef, Lattice
export num_tiles, get_tile, corresponding_edge, shared_edge
export num_curves, curve_ids, get_curvediagram, is_deleted
export sibling_insert_pos, sibling_eref
export find_cref_index, prev_curvepiece, next_curvepiece
export anyon_tiles, next_anyon, prev_anyon
include("lattice/lattice.jl")

export visualize!, visualize
function visualize! end
function visualize end

end # module CurveDiagrams
