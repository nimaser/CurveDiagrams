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
# mutators
export insert_curvepiece!, remove_curvepiece!, move_endpoint!, set_curvepiece_metadata!
include("tile/tile.jl")

# ### lattice.jl ###
# export CurvepieceRef, Lattice
# # geometric helpers
# export conjugate_edge
# # getters
# export neighbor, sister_endpointid, get_path, get_curve_ids, find_curve, anyon_tiles
# # mutators
# export hexagonal_torus, hexagonal_sphere

# include("lattice.jl")

### visualization ###
export visualize!, visualize
function visualize! end
function visualize end

end # module CurveDiagrams
