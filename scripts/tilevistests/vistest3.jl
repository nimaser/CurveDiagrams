using GLMakie
using CurveDiagrams

# A (nesting 2) encloses B (nesting 1), both siblings of C (nesting 1)
# clockwise boundary: A, B, B, A, C, C
t = Tile(3)
insert_curvepiece!(t, 1, 1, 1, 1, 2, 1)  # A: IN edge1/1, OUT edge2/1
insert_curvepiece!(t, 2, 1, 1, 2, 2, 1)  # B: IN edge1/2, OUT edge2/1 (shifts A.out to pos 2)
insert_curvepiece!(t, 3, 1, 2, 3, 3, 1)  # C: IN edge2/3, OUT edge3/1

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
