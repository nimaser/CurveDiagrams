module CurveDiagrams

### tile.jl ###

# endpoints
export EndpointDirection, EndpointType, CurvepieceEndpoint
export order_curvepiece_endpoints, Base.isless
# Tile and its getters and setters
export CurvepieceEndpointIndex, CurvepieceData, Tile, get_curvepiece_ids
export get_curvepiece_endpoint, get_curvepiece_edge_endpoint, get_curvepiece_anyon_endpoint
export get_curvepiece_endpoints, get_curvepiece_edge_endpoints, get_curvepiece_anyon_endpoints
export get_other_curvepiece_endpoint, get_curvepiece_endpoint_index
# medium level Tile methods
export insert_curvepiece!

include("tile.jl")

end # Module CurveDiagrams
