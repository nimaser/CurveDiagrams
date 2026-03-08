module CurveDiagrams

### tile.jl ###
export EndpointDirection, IN, OUT
export CurvepieceEndpoint, AnyonEndpoint, EdgeEndpoint
export Curvepiece, EndpointId, Tile
# getters
export get_curvepiece, get_curvepiece_ids, get_endpoint, get_other_endpointid
export get_edge_endpointid, get_anyon_endpointid, adjacent_endpointids, edge_length
# mutators
export insert_curvepiece!, remove_curvepiece!, move_endpoint!, set_curvepiece_metadata!

include("tile.jl")

### lattice.jl ###
export CurvepieceRef, Lattice
# geometric helpers
export conjugate_edge
# getters
export neighbor, sister_endpointid, get_path, get_curve_ids, find_curve, anyon_tiles
# mutators
export hexagonal_torus, hexagonal_sphere

include("lattice.jl")

end # module CurveDiagrams
