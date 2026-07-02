module CurveDiagrams

### CURVEPIECE ###

export EndpointDirection, IN, OUT, invert
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece, first, last, endpoint_idx, reverse
export change_endpoint_location
include("curvepiece.jl")

### TILE ###

export EndpointRef, curvepiece_partner
export Tile
include("tile.jl")

# tile geometry
export num_edges, next_edge, prev_edge
# erefs
export all_edge_erefs
export num_edge_erefs, has_edge_erefs, edge_erefs
export num_anyon_erefs, has_anyon_erefs, anyon_erefs
export has_edge_eref, edge_eref
export anyon_eref
# endpoints
export endpoint, curvepiece_partner_type
# curvepieces
export curvepiece_ids, central_curvepiece_ids
export curvepiece, is_central_curvepiece
include("tile/getters/basic.jl")

export next_eref, prev_eref
export next_eref_wrap, prev_eref_wrap
export edge_eref_clockwise_sort, edge_eref_clockwise_arc
include("tile/getters/edge_eref_traversal.jl")

export tile_partner
include("tile/getters/tile_partner.jl")

export other_central_curvepiece_id
export ordered_central_curvepieces
export curve_id, anyon_count
include("tile/getters/central_curvepiece_functions.jl")

export u_turn_curvepiece_ids, hugs_corner
include("tile/getters/boundary_curvepiece_functions.jl")

export nesting_hierarchy
include("tile/getters/nesting_hierarchy.jl")

export violated_partitions
include("tile/getters/violated_partitions.jl")

include("tile/mutators/basic_internal.jl")

export set_curvepiece_metadata!, reverse_curvepiece!
export insert_curvepiece!, remove_curvepiece!, move_endpoint!
include("tile/mutators/one_curvepiece.jl")

export edge_split!, edge_merge!
export anyon_split!, anyon_merge!
include("tile/mutators/two_curvepiece.jl")

### LATTICE ###

export CurvepieceRef, TileEdgeRef
export Lattice
include("lattice.jl")

# latice geometry
export num_tiles, get_tile, corresponding_edge, shared_edge
# curves
export curve_ids, get_curve, tiles_in, find_cref_index
include("lattice/getters/basic.jl")

export sibling_location, sibling_eref
include("lattice/getters/sibling.jl")

export prev_curvepiece, next_curvepiece, extremity_distances
include("lattice/getters/curve_traversal.jl")

export anyon_tiles, next_anyon, prev_anyon
include("lattice/getters/anyon.jl")

include("lattice/mutators/basic_internal.jl")
include("lattice/mutators/u_turn.jl")
include("lattice/mutators/shielding.jl")

export simplify!
include("lattice/mutators/simplify.jl")

export swap!
include("lattice/mutators/swap.jl")

export remove_anyon!
include("lattice/mutators/remove_anyon.jl")

export move_anyon!
include("lattice/mutators/move_anyon.jl")

export create_pair!, grow!, merge!, make_neighbors!
include("lattice/mutators/make_neighbors.jl")

export visualize!, visualize
function visualize! end
function visualize end

end # module CurveDiagrams
