using GLMakie
using CurveDiagrams

# pentagon: A, B, F nesting 1; C, E nesting 2; D is a2e (barrier)
# clockwise boundary: A, B, B, C, D, E, F, F, E, C, A
t = Tile(5)
t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 5, 2))  # A
t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 2, 1))  # B
t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 2, 2), EdgeEndpoint(OUT, 5, 1))  # C
t._curvepieces[4] = Curvepiece(4, 1, EdgeEndpoint(IN, 2, 3), AnyonEndpoint(IN))        # D
t._curvepieces[5] = Curvepiece(5, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 4, 2))  # E
t._curvepieces[6] = Curvepiece(6, 1, EdgeEndpoint(IN, 3, 2), EdgeEndpoint(OUT, 4, 1))  # F
push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
push!(t._edge_endpoints[2], EndpointRef(3, 1))  # C.endpoint1
push!(t._edge_endpoints[2], EndpointRef(4, 1))  # D.endpoint1
push!(t._edge_endpoints[3], EndpointRef(5, 1))  # E.endpoint1
push!(t._edge_endpoints[3], EndpointRef(6, 1))  # F.endpoint1
push!(t._edge_endpoints[4], EndpointRef(6, 2))  # F.endpoint2
push!(t._edge_endpoints[4], EndpointRef(5, 2))  # E.endpoint2
push!(t._edge_endpoints[5], EndpointRef(3, 2))  # C.endpoint2
push!(t._edge_endpoints[5], EndpointRef(1, 2))  # A.endpoint2
push!(t._anyon_endpoints, EndpointRef(4, 2))    # D.anyon endpoint

# Regular pentagon vertices in clockwise order, starting from top
v = Point2f[Point2f(cos(π/2 - 2π*k/5), sin(π/2 - 2π*k/5)) for k in 0:4]

f = visualize(t, v)
display(f)
