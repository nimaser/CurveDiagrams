using GLMakie
using CurveDiagrams

# Build the tile from the nesting hierarchy test case in test/tiletest.jl.
# 3-edge tile with 8 curvepieces: A–H, including two anyon curvepieces (E, G).
# E and G share curve_id 5; G uses direction OUT (opposite to E's IN).
t = Tile(3)
insert_curvepiece!(t, 1, 1, 1, 1, 3, 1)  # A: IN edge1/1, OUT edge3/1
insert_curvepiece!(t, 2, 1, 1, 2, 3, 1)  # B: IN edge1/2, OUT edge3/1 (shifts A.out to pos 2)
insert_curvepiece!(t, 3, 1, 1, 3, 3, 1)  # C: IN edge1/3, OUT edge3/1 (shifts B.out, A.out forward)
insert_curvepiece!(t, 4, 1, 1, 4, 1, 5)  # D: IN edge1/4, OUT edge1/5 (same edge, IN then OUT)
insert_curvepiece!(t, 5, 1, 1, 6, IN)    # E: IN edge1/6, anyon IN
insert_curvepiece!(t, 6, 1, 2, 1, 2, 2)  # F: IN edge2/1, OUT edge2/2 (same edge, IN then OUT)
insert_curvepiece!(t, 5, 1, 2, 3, OUT)   # G: IN edge2/3, anyon OUT (same curve as E)
insert_curvepiece!(t, 8, 1, 3, 2, 3, 3)  # H: IN edge3/2, OUT edge3/3 (same edge, IN then OUT)

# Regular triangle vertices in clockwise order
v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
