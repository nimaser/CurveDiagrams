module CurveDiagrams

export EndpointDirection, IN, OUT
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece
include("tile/curvepiece.jl")

export EndpointRef, Tile
export num_edges, next_edge, prev_edge # tile geometry
export has_endpoints, num_endpoints
export num_anyon_curvepieces, curvepiece_ids, get_curvepiece
export get_endpoint
export get_edge_EndpointRef, get_edge_EndpointRefs, get_anyon_EndpointRefs
export get_partner_EndpointRef, has_edge_partner, has_anyon_partner
export get_anyon_EndpointRef, is_anyon_curvepiece, get_anyon_cp_ids, get_partner_cp_id, anyon_curve_id
export next_EndpointRef_on_edge, prev_EndpointRef_on_edge, next_EndpointRef, prev_EndpointRef
include("tile/tile.jl")

export insert_curvepiece!, remove_curvepiece!, move_endpoint!, set_curvepiece_metadata!
include("tile/mutators.jl")

export CurvepieceRef, TileEdgeRef, Lattice
export num_tiles, get_tile, corresponding_edge, shared_edge
export num_curves, curve_ids, get_curvediagram, is_deleted
export sibling_EndpointRef#, curvepieces_on_edge
export prev_curvepiece, next_curvepiece, find_curve_position
export anyon_curve_id, anyon_tiles
include("lattice/lattice.jl")

export visualize!, visualize
function visualize! end
function visualize end

end # module CurveDiagrams
