module CurveDiagrams

### tile.jl ###
export EndpointDirection, IN, OUT
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece, EndpointRef, Tile
# edge/tile geometry
export num_edges, next_edge, prev_edge
# endpoint queries
export has_endpoints, num_endpoints, num_anyon_curvepieces
export curvepiece_ids, get_curvepiece, get_endpoint
export get_edge_EndpointRef, get_edge_EndpointRefs, get_anyon_EndpointRefs, get_anyon_EndpointRef
export get_partner_EndpointRef, has_edge_partner, has_anyon_partner
export next_EndpointRef_on_edge, prev_EndpointRef_on_edge, next_EndpointRef, prev_EndpointRef
export EndpointRefs_between
# mutators
export insert_curvepiece!, remove_curvepiece!, move_endpoint!, set_curvepiece_metadata!

include("tile.jl")

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
