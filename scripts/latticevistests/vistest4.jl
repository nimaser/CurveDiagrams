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

create_pair!(l, 4, 1)   # tile 4 edge 4 (SW) ↔ tile 1 edge 1 (NE)
create_pair!(l, 5, 8)   # tile 5 edge 6 (NW) ↔ tile 8 edge 3 (SE)

tile_vertices = hex_lattice_tile_vertices(3, 3)
f = visualize(l, tile_vertices)
display(f)
