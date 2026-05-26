using GLMakie
using CurveDiagrams

# pentagon: A, B, F nesting 1; C, E nesting 2; D is a2e (barrier)
# clockwise boundary: A, B, B, C, D, E, F, F, E, C, A
t = Tile(5)
insert_curvepiece!(t, 1, 1, 1, 1, 5, 1)  # A: IN edge1/1, OUT edge5/1
insert_curvepiece!(t, 2, 1, 1, 2, 2, 1)  # B: IN edge1/2, OUT edge2/1
insert_curvepiece!(t, 3, 1, 2, 2, 5, 1)  # C: IN edge2/2, OUT edge5/1 (shifts A.out to pos 2)
insert_curvepiece!(t, 4, 1, 2, 3, IN)    # D: IN edge2/3, anyon
insert_curvepiece!(t, 5, 1, 3, 1, 4, 1)  # E: IN edge3/1, OUT edge4/1
insert_curvepiece!(t, 6, 1, 3, 2, 4, 1)  # F: IN edge3/2, OUT edge4/1 (shifts E.out to pos 2)

# Regular pentagon vertices in clockwise order, starting from top
v = Point2f[Point2f(cos(π/2 - 2π*k/5), sin(π/2 - 2π*k/5)) for k in 0:4]

f = visualize(t, v)
display(f)
