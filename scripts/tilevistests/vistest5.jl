using GLMakie
using CurveDiagrams

# a2e curvepiece C acts as a barrier; A (nesting 1) is enclosed by B (nesting 2)
# clockwise boundary on edge 2: A, B, C, B, A
t = Tile(3)
insert_curvepiece!(t, 1, 1, 2, 1, 2, 2)  # A: IN edge2/1, OUT edge2/2 (same edge, IN then OUT)
insert_curvepiece!(t, 2, 1, 2, 2, 2, 3)  # B: IN edge2/2, OUT edge2/3 (post-IN coords; shifts A.out to pos 4)
insert_curvepiece!(t, 3, 1, 2, 3, IN)    # C: IN edge2/3, anyon (shifts B.out and A.out forward)

v = Point2f[
    Point2f(0,            1),
    Point2f( sqrt(3f0)/2, -0.5f0),
    Point2f(-sqrt(3f0)/2, -0.5f0),
]

f = visualize(t, v)
display(f)
