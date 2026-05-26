using GLMakie
using CurveDiagrams

# single a2e curvepiece: absent from nesting hierarchy result
t = Tile(3)
t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
push!(t._edge_endpoints[1], EndpointRef(1, 1))
push!(t._anyon_endpoints, EndpointRef(1, 2))

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
