using GLMakie
using CurveDiagrams

# single e2e curvepiece with endpoints on different edges: nesting 1, not enclosed
t = Tile(3)
t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 2, 1))
push!(t._edge_endpoints[1], EndpointRef(1, 1))
push!(t._edge_endpoints[2], EndpointRef(1, 2))

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
