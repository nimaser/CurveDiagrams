using GLMakie
using CurveDiagrams

# same as vistest3 but C wraps across the edge-1/edge-3 boundary, testing wraparound-awareness
# clockwise boundary: C, A, B, B, A, C
t = Tile(3)
insert_curvepiece!(t, 3, 1, 3, 1, 1, 1)  # C: IN edge3/1, OUT edge1/1
insert_curvepiece!(t, 1, 1, 1, 2, 2, 1)  # A: IN edge1/2, OUT edge2/1
insert_curvepiece!(t, 2, 1, 1, 3, 2, 1)  # B: IN edge1/3, OUT edge2/1 (shifts A.out to pos 2)

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
