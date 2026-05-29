using GeometryBasics: Point2f

###############################################################################
# POLYGON HELPERS
###############################################################################

"""
Return the vertices of a regular `n`-gon with circumradius `scale`, with the first vertex at
`(scale, 0)` rotated counterclockwise by `θ`, and subsequent vertices progressing clockwise.
"""
function regular_polygon_vertices(n::Int, scale::Real, θ::Real)
    Point2f[Point2f(scale * cos(θ - 2π*(k-1)/n), scale * sin(θ - 2π*(k-1)/n)) for k in 1:n]
end

###############################################################################
# HEX LATTICE HELPERS
###############################################################################

# Edge numbering for pointy-top hexagons, clockwise from the upper-right edge:
#   1 = NE, 2 = E, 3 = SE, 4 = SW, 5 = W, 6 = NW
# conjugate_edge(e): the edge on the neighboring tile that faces back toward the original tile.
conjugate_edge(e::Int) = mod(e + 2, 6) + 1

# Row-offset convention: odd rows have no horizontal offset; even rows are shifted right
# by half the horizontal center-spacing (√3/2 * circumradius).
#
# Neighbor offsets (dr, dc) for each edge direction:
const _HEX_OFFSET_ODD  = [(1, 0), (0, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
const _HEX_OFFSET_EVEN = [(1, 1), (0, 1), (-1, 1), (-1,  0), (0, -1), (1,  0)]

_hex_offset(e::Int, r::Int) = isodd(r) ? _HEX_OFFSET_ODD[e] : _HEX_OFFSET_EVEN[e]

"""
Return the vertex positions for each inner tile in a `rows` × `cols` hexagonal lattice at
circumradius 1, laid out with pointy-top hexagons. Tile IDs are row-major from the bottom row
upwards: `tile_id = (r-1)*cols + c`.

Returns a `Dict{Int, Vector{Point2f}}` containing only the inner tiles (1 .. rows*cols);
the virtual outer plaquette tile created by `hexagonal_sphere` is omitted.
"""
function hex_lattice_tile_vertices(rows::Int, cols::Int)
    s = 1.0f0
    base_verts = regular_polygon_vertices(6, s, π/2)  # pointy-top: first vertex at top
    result = Dict{Int, Vector{Point2f}}()
    for r in 1:rows, c in 1:cols
        tile_id = (r - 1) * cols + c
        cx = Float32((c - 1) * √3 * s + (iseven(r) ? √3/2 * s : 0.0))
        cy = Float32((r - 1) * 3/2 * s)
        result[tile_id] = [v + Point2f(cx, cy) for v in base_verts]
    end
    result
end

###############################################################################
# LATTICE CONSTRUCTORS
###############################################################################

"""Hexagonal lattice on a torus: all edges wrap around."""
function hexagonal_torus(rows::Int, cols::Int)
    flat(r, c) = (r - 1) * cols + c
    n = rows * cols
    adjacency = [Vector{Tuple{Int,Int}}(undef, 6) for _ in 1:n]
    for r in 1:rows, c in 1:cols
        tid = flat(r, c)
        for e in 1:6
            dr, dc = _hex_offset(e, r)
            nr = mod(r + dr - 1, rows) + 1
            nc = mod(c + dc - 1, cols) + 1
            adjacency[tid][e] = (flat(nr, nc), conjugate_edge(e))
        end
    end
    Lattice(adjacency)
end

"""
Hexagonal lattice on a sphere: boundary edges connect to a single virtual outer plaquette.
The outer plaquette has one edge per boundary edge of the grid; it is assigned tile id
`rows*cols + 1` by the `Lattice` constructor.
"""
function hexagonal_sphere(rows::Int, cols::Int)
    flat(r, c) = (r - 1) * cols + c
    n = rows * cols
    outer_id = n + 1

    inner_adj = [Vector{Tuple{Int,Int}}(undef, 6) for _ in 1:n]
    boundary = Tuple{Int,Int}[]   # (tile_id, edge) pairs on the boundary, in discovery order

    for r in 1:rows, c in 1:cols
        tid = flat(r, c)
        for e in 1:6
            dr, dc = _hex_offset(e, r)
            nr, nc = r + dr, c + dc
            if 1 <= nr <= rows && 1 <= nc <= cols
                inner_adj[tid][e] = (flat(nr, nc), conjugate_edge(e))
            else
                push!(boundary, (tid, e))
                inner_adj[tid][e] = (outer_id, length(boundary))
            end
        end
    end

    M = length(boundary)
    outer_adj = Vector{Tuple{Int,Int}}(undef, M)
    for (outer_edge, (tid, e)) in enumerate(boundary)
        outer_adj[outer_edge] = (tid, e)
    end

    Lattice(vcat(inner_adj, [outer_adj]))
end
