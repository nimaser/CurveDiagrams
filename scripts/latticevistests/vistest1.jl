using GLMakie
using CurveDiagrams

include("../geometryhelper.jl")

# 3×3 hex lattice on a sphere; tiles are row-major from the bottom:
#   7 8 9
#   4 5 6
#   1 2 3
# Tile 10 is the virtual outer plaquette (not visualized).
l = hexagonal_sphere(3, 3)

# Build one curve diagram manually spanning three tiles in the middle row:
#   anyon(tile 4) --e2(tile4)/e5(tile5)--> e2e(tile 5) --e2(tile5)/e5(tile6)--> anyon(tile 6)
#
# Edge numbering for pointy-top hexagons (clockwise from NE):
#   1=NE, 2=E, 3=SE, 4=SW, 5=W, 6=NW
# direction=OUT on an anyon endpoint: curve exits the anyon (a2e piece)
# direction=IN  on an anyon endpoint: curve enters the anyon (e2a piece)

curve_id = CurveDiagrams._allocate_curve_id!(l)

# tile 4: a2e — exits its anyon outward through edge 2 (E, toward tile 5)
cp4 = insert_curvepiece!(get_tile(l, 4), curve_id, 1, 2, 1, OUT)

# tile 5: e2e — IN from edge 5 (W, from tile 4), OUT through edge 2 (E, toward tile 6)
cp5 = insert_curvepiece!(get_tile(l, 5), curve_id, 1, 5, 1, 2, 1)

# tile 6: e2a — enters its anyon through edge 5 (W, from tile 5)
cp6 = insert_curvepiece!(get_tile(l, 6), curve_id, 1, 5, 1, IN)

# Register the three curvepieces in the curve diagram in traversal order
CurveDiagrams._insert_cref!(l, curve_id, 1, CurvepieceRef(4, cp4))
CurveDiagrams._insert_cref!(l, curve_id, 2, CurvepieceRef(5, cp5))
CurveDiagrams._insert_cref!(l, curve_id, 3, CurvepieceRef(6, cp6))

tile_vertices = hex_lattice_tile_vertices(3, 3)
f = visualize(l, tile_vertices)
display(f)
