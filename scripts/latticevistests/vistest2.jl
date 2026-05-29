using GLMakie
using CurveDiagrams

include("../geometryhelper.jl")

# 3×3 hex lattice on a sphere; tiles are row-major from the bottom:
#   7 8 9
#   4 5 6
#   1 2 3
# Tile 10 is the virtual outer plaquette (not visualized).
l = hexagonal_sphere(3, 3)

# Edge numbering for pointy-top hexagons (clockwise from NE):
#   1=NE, 2=E, 3=SE, 4=SW, 5=W, 6=NW
# direction=OUT on an anyon endpoint: curve exits the anyon (a2e piece)
# direction=IN  on an anyon endpoint: curve enters the anyon (e2a piece)

# Curve 1: anyon(tile 4) → e2e(tile 5) → anyon(tile 6)  [middle row, left→right]
#   tile 4 edge 2 (E) ↔ tile 5 edge 5 (W)
#   tile 5 edge 2 (E) ↔ tile 6 edge 5 (W)
curve1 = CurveDiagrams._allocate_curve_id!(l)
cp4  = insert_curvepiece!(get_tile(l, 4), curve1, 1, 2, 1, OUT)
cp5a = insert_curvepiece!(get_tile(l, 5), curve1, 1, 5, 1, 2, 1)
cp6  = insert_curvepiece!(get_tile(l, 6), curve1, 1, 5, 1, IN)
CurveDiagrams._insert_cref!(l, curve1, 1, CurvepieceRef(4, cp4))
CurveDiagrams._insert_cref!(l, curve1, 2, CurvepieceRef(5, cp5a))
CurveDiagrams._insert_cref!(l, curve1, 3, CurvepieceRef(6, cp6))

# Curve 2: anyon(tile 8) → e2e(tile 5) → e2e(tile 9) → e2e(tile 6) →
#          anyon(tile 3) → e2e(tile 5) → anyon(tile 2)
#
# Segment 1 (anyon_count=1): tiles 8, 5, 9, 6, 3(enter)
#   tile 8 edge 3 (SE) ↔ tile 5 edge 6 (NW)
#   tile 5 edge 1 (NE) ↔ tile 9 edge 4 (SW)
#   tile 9 edge 3 (SE) ↔ tile 6 edge 6 (NW)
#   tile 6 edge 4 (SW) ↔ tile 3 edge 1 (NE)
# Segment 2 (anyon_count=2): tiles 3(exit), 5, 2
#   tile 3 edge 6 (NW) ↔ tile 5 edge 3 (SE)
#   tile 5 edge 4 (SW) ↔ tile 2 edge 1 (NE)
curve2 = CurveDiagrams._allocate_curve_id!(l)

cp8   = insert_curvepiece!(get_tile(l, 8), curve2, 1, 3, 1, OUT)       # a2e, seg 1
cp5b  = insert_curvepiece!(get_tile(l, 5), curve2, 1, 6, 1, 1, 1)      # e2e, seg 1
cp9   = insert_curvepiece!(get_tile(l, 9), curve2, 1, 4, 1, 3, 1)      # e2e, seg 1
cp6b  = insert_curvepiece!(get_tile(l, 6), curve2, 1, 6, 1, 4, 1)      # e2e, seg 1
cp3a  = insert_curvepiece!(get_tile(l, 3), curve2, 1, 1, 1, IN)        # e2a, seg 1
cp3b  = insert_curvepiece!(get_tile(l, 3), curve2, 2, 6, 1, OUT)       # a2e, seg 2
cp5c  = insert_curvepiece!(get_tile(l, 5), curve2, 2, 3, 1, 4, 1)      # e2e, seg 2
cp2   = insert_curvepiece!(get_tile(l, 2), curve2, 2, 1, 1, IN)        # e2a, seg 2

CurveDiagrams._insert_cref!(l, curve2, 1, CurvepieceRef(8, cp8))
CurveDiagrams._insert_cref!(l, curve2, 2, CurvepieceRef(5, cp5b))
CurveDiagrams._insert_cref!(l, curve2, 3, CurvepieceRef(9, cp9))
CurveDiagrams._insert_cref!(l, curve2, 4, CurvepieceRef(6, cp6b))
CurveDiagrams._insert_cref!(l, curve2, 5, CurvepieceRef(3, cp3a))
CurveDiagrams._insert_cref!(l, curve2, 6, CurvepieceRef(3, cp3b))
CurveDiagrams._insert_cref!(l, curve2, 7, CurvepieceRef(5, cp5c))
CurveDiagrams._insert_cref!(l, curve2, 8, CurvepieceRef(2, cp2))

tile_vertices = hex_lattice_tile_vertices(3, 3)
f = visualize(l, tile_vertices)
display(f)
