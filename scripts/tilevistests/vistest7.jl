using GLMakie
using CurveDiagrams

# Build the tile from the nesting hierarchy test case in test/tiletest.jl.
# 3-edge tile with 8 curvepieces: A–H, including two anyon curvepieces (E, G).
t = Tile(3)
t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 3, 5))  # A
t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 3, 4))  # B
t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 1, 3), EdgeEndpoint(OUT, 3, 1))  # C
t._curvepieces[4] = Curvepiece(4, 1, EdgeEndpoint(IN, 1, 4), EdgeEndpoint(OUT, 1, 5))  # D
t._curvepieces[5] = Curvepiece(5, 1, EdgeEndpoint(IN, 1, 6), AnyonEndpoint(IN))        # E
t._curvepieces[6] = Curvepiece(6, 1, EdgeEndpoint(IN, 2, 1), EdgeEndpoint(OUT, 2, 2))  # F
t._curvepieces[7] = Curvepiece(7, 1, EdgeEndpoint(IN, 2, 3), AnyonEndpoint(IN))        # G
t._curvepieces[8] = Curvepiece(8, 1, EdgeEndpoint(IN, 3, 2), EdgeEndpoint(OUT, 3, 3))  # H
push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
push!(t._edge_endpoints[1], EndpointRef(3, 1))  # C.endpoint1
push!(t._edge_endpoints[1], EndpointRef(4, 1))  # D.endpoint1
push!(t._edge_endpoints[1], EndpointRef(4, 2))  # D.endpoint2
push!(t._edge_endpoints[1], EndpointRef(5, 1))  # E.endpoint1
push!(t._edge_endpoints[2], EndpointRef(6, 1))  # F.endpoint1
push!(t._edge_endpoints[2], EndpointRef(6, 2))  # F.endpoint2
push!(t._edge_endpoints[2], EndpointRef(7, 1))  # G.endpoint1
push!(t._edge_endpoints[3], EndpointRef(3, 2))  # C.endpoint2
push!(t._edge_endpoints[3], EndpointRef(8, 1))  # H.endpoint1
push!(t._edge_endpoints[3], EndpointRef(8, 2))  # H.endpoint2
push!(t._edge_endpoints[3], EndpointRef(2, 2))  # B.endpoint2
push!(t._edge_endpoints[3], EndpointRef(1, 2))  # A.endpoint2
push!(t._anyon_endpoints, EndpointRef(5, 2))    # E.anyon endpoint
push!(t._anyon_endpoints, EndpointRef(7, 2))    # G.anyon endpoint

# Regular triangle vertices in clockwise order
v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
