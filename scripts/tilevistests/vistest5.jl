using GLMakie
using CurveDiagrams

# a2e curvepiece C acts as a barrier; A (nesting 1) is enclosed by B (nesting 2)
# clockwise boundary on edge 2: A, B, C, B, A
t = Tile(3)
t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 2, 1), EdgeEndpoint(OUT, 2, 5))  # A
t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 2, 2), EdgeEndpoint(OUT, 2, 4))  # B
t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 2, 3), AnyonEndpoint(IN))        # C
push!(t._edge_endpoints[2], EndpointRef(1, 1))  # A.endpoint1
push!(t._edge_endpoints[2], EndpointRef(2, 1))  # B.endpoint1
push!(t._edge_endpoints[2], EndpointRef(3, 1))  # C.endpoint1
push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
push!(t._edge_endpoints[2], EndpointRef(1, 2))  # A.endpoint2
push!(t._anyon_endpoints, EndpointRef(3, 2))    # C.anyon endpoint

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
