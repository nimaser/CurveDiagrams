using GLMakie
using CurveDiagrams

# single e2e curvepiece with endpoints on different edges: nesting 1, not enclosed
t = Tile(3)
insert_curvepiece!(t, 1, 1, 1, 1, 2, 1)

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
