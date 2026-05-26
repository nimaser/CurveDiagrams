using GLMakie
using CurveDiagrams

# same as vistest3 but C wraps across the edge-1/edge-3 boundary, testing wraparound-awareness
# clockwise boundary: C, A, B, B, A, C
t = Tile(3)
t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 2, 2))  # A
t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 3), EdgeEndpoint(OUT, 2, 1))  # B
t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 1, 1))  # C
push!(t._edge_endpoints[1], EndpointRef(3, 2))  # C.endpoint2
push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
push!(t._edge_endpoints[2], EndpointRef(1, 2))  # A.endpoint2
push!(t._edge_endpoints[3], EndpointRef(3, 1))  # C.endpoint1

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
