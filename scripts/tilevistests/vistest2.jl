using GLMakie
using CurveDiagrams

# single a2e curvepiece: absent from nesting hierarchy result
t = Tile(3)
insert_curvepiece!(t, 1, 1, 1, 1, IN)

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
