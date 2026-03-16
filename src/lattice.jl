"""
We identify each `Curvepiece` in a lattice by storing its tile and its id within that tile.
"""
struct CurvepieceRef
    tile_id::Int
    cp_id::Int
end

"""A curve diagram is a list of sequential curvepieces."""
const CurveDiagram = Vector{CurvepieceRef}

"""
We identify each edge of a tile in a lattice by storing its tile and its edge number within that tile.
"""
struct TileEdgeRef
    tile_id::Int
    edge::Int
end

"""
A `Lattice` is a collection of `Tile`s connected by sharing edges. Curve diagrams snake through
the `Tile`s on the lattice. A lattice must be defined on a closed, compact manifold, e.g. a sphere
or a torus. The fields of this struct should not be directly modified by the user.

`_tiles[tile_id]` gives the `Tile` with id `tile_id`
`_adjacency[tile_id][edge]` gives a `TileEdgeRef` for the corresponding edge in the neighboring tile
`_curvediagrams[curve_id]` gives the `CurveDiagram` with id `curve_id`

The `Lattice` constructor accepts a filled `adjacency` and creates the necessary `Tile`s and other
internal datastructures.
"""
struct Lattice
    _tiles::Vector{Tile}
    _adjacency::Vector{Vector{TileEdgeRef}}
    _curvediagrams::Dict{Int, CurveDiagram}
    function Lattice(adjacency::Vector{Vector{TileEdgeRef}})
        tiles = Tile[]
        for tile_id in 1:length(adjacency)
            for edge in 1:length(adjacency[tile_id])
                # simple validation that each edge's partner has that original edge as its partner;
                # in other words, that finding corresponding edges is its own inverse operation
                cedge = adjacency[tile_id][edge]
                this_edge = adjacency[cedge.tile_id][cedge.edge]
                this_edge.tile_id == tile_id && this_edge.edge == edge ||
                    throw(ArgumentError("edge correspondence inconsistency on $this_edge and $cedge"))
            end
            # add the tile to the list
            push!(tiles, Tile(length(adjacency[tile_id])))
        end
        curvediagrams = Dict{Int, CurveDiagram}()
        new(tiles, adjacency, curvediagrams)
    end
end

### PUBLIC GETTERS ###

"""Returns the `Tile` with id `tile_id` in `l`."""
get_tile(l::Lattice, tile_id::Int) = l._tiles[tile_id]

"""Returns the `TileEdgeRef` for the edge corresponding to the provided one."""
corresponding_edge(l::Lattice, tile_id::Int, edge::Int) = l._adjacency[tile_id][edge]

"""Returns the `CurveDiagram` with id `curve_id` in `l`."""
get_curvediagram(l::Lattice, curve_id::Int) = l._curvediagrams[curve_id]

"""
Curvepieces can only start or end at anyons, so being made up of curvepieces, any `CurveDiagram`
can also only start or end on an anyon. This means that any curvepiece endpoint on a tile edge
must have a 'sibling' endpoint which lives on the corresponding edge in the adjacent tile. For
any edge with N endpoints on it, its corresponding edge also has N endpoints.

Given an edge endpoint in `tile_id`, this function returns `(neighbor_tile_id, EndpointRef)` of its
sibling endpoint. Note that because endpoint positions on edges are assigned clockwise and 1-indexed,
if an endpoint has position `n` out of `N` total endpoints on an edge, its sibling endpoint has position
`N - n + 1` on the corresponding edge.
"""
function sibling_endpoint(l::Lattice, tile_id::Int, eid::EndpointId)
    ep::EdgeEndpoint = get_endpoint(get_tile(l, tile_id), eid)
    cedge = corresponding_edge(l, tile_id, ep.edge)
    neighbortile = get_tile(l, cedge.tile_id)
    N = num_endpoints(neighbortile, cedge.edge)
    sibling_pos = N - ep.pos + 1
    cedge.tile_id, get_edge_EndpointRef(neighbortile, cedge.edge, sibling_pos)
end

"""
Returns the `curve_id` of the curve diagram which contains the anyon of the tile
with id `tile_id`. Returns nothing if that tile's anyon is not on any curve diagram.
"""
function anyon_curve_id(l::Lattice, tile_id::Int)
    t = get_tile(l, tile_id)
    anyon_curve_id(t)
end

"""
Function to get the tiles which contain anyons on a specific curve.

Returns a vector of `tile_id`s for tiles which contain anyons which are on the curve with `curve_id`.
Tiles are returned in path order.
"""
function anyon_tiles(l::Lattice, curve_id::Int)
    ids = Int[] # returned result, containing tile_ids
    seen = Set{Int}() # tile_ids for tiles with anyons which have already been added to ids
    # go through all of the CurvepieceRefs in the curve
    for ref in get_curvediagram(l, curve_id)
        ref.tile_id ∈ seen && continue # only one anyon per tile, so we can just skip
        t = get_tile(l, ref.tile_id)
        if is_anyon_curvepiece(t, ref.cp_id)
            push!(ids, ref.tile_id)
            push!(seen, ref.tile_id)
        end
    end
    ids
end

### INTERNAL MUTATORS ###

# Row/column offset for each edge on a pointy-top hex grid with odd-row offset.
# Edges numbered clockwise: 1=E, 2=SE, 3=SW, 4=W, 5=NW, 6=NE.
function _hex_offset(edge::Int, row::Int)::Tuple{Int,Int}
    if isodd(row)
        if edge == 1; ( 0,  1)
        elseif edge == 2; ( 1,  1)
        elseif edge == 3; ( 1,  0)
        elseif edge == 4; ( 0, -1)
        elseif edge == 5; (-1,  0)
        else;             (-1,  1)   # edge == 6
        end
    else
        if edge == 1; ( 0,  1)
        elseif edge == 2; ( 1,  0)
        elseif edge == 3; ( 1, -1)
        elseif edge == 4; ( 0, -1)
        elseif edge == 5; (-1, -1)
        else;             (-1,  0)   # edge == 6
        end
    end
end

# ---- path mutators ----

function _insert_path_entry!(l::Lattice, curve_id::Int, pos::Int, ref::CurvepieceRef)
    insert!(l.paths[curve_id], pos, ref)
end

function _remove_path_entry!(l::Lattice, curve_id::Int, pos::Int)
    deleteat!(l.paths[curve_id], pos)
end

function _allocate_curve_id!(l::Lattice)
    push!(l.paths, CurvepieceRef[])
    length(l.paths)
end

# ---- constructors ----

# Hexagonal lattice on a torus: all edges wrap around.
function hexagonal_torus(Nr::Int, Nc::Int)
    flat(r, c) = (c - 1) * Nr + r
    n = Nr * Nc
    tiles     = [Tile(6) for _ in 1:n]
    adjacency = [[Union{Nothing,Tuple{Int,Int}}(nothing) for _ in 1:6] for _ in 1:n]
    for r in 1:Nr, c in 1:Nc
        tid = flat(r, c)
        for e in 1:6
            dr, dc = _hex_offset(e, r)
            nr = mod(r + dr - 1, Nr) + 1
            nc = mod(c + dc - 1, Nc) + 1
            adjacency[tid][e] = (flat(nr, nc), conjugate_edge(e))
        end
    end
    Lattice(tiles, adjacency, Vector{CurvepieceRef}[])
end

# Hexagonal lattice on a sphere: boundary edges connect to a single outer plaquette.
# The outer plaquette has one edge per boundary edge of the grid; it never holds anyons.
function hexagonal_sphere(Nr::Int, Nc::Int)
    flat(r, c) = (c - 1) * Nr + r
    n = Nr * Nc
    tiles     = [Tile(6) for _ in 1:n]
    adjacency = Vector{Vector{Union{Nothing,Tuple{Int,Int}}}}(
        [[nothing for _ in 1:6] for _ in 1:n])

    boundary = Tuple{Int,Int}[]   # (tile_id, edge) pairs with no regular neighbor
    for r in 1:Nr, c in 1:Nc
        tid = flat(r, c)
        for e in 1:6
            dr, dc = _hex_offset(e, r)
            nr, nc = r + dr, c + dc
            if 1 <= nr <= Nr && 1 <= nc <= Nc
                adjacency[tid][e] = (flat(nr, nc), conjugate_edge(e))
            else
                push!(boundary, (tid, e))
            end
        end
    end

    # Outer plaquette: one edge per boundary edge, numbered in discovery order.
    M        = length(boundary)
    outer_id = n + 1
    push!(tiles, Tile(M))
    push!(adjacency, [Union{Nothing,Tuple{Int,Int}}(nothing) for _ in 1:M])
    for (outer_edge, (tid, e)) in enumerate(boundary)
        adjacency[tid][e]         = (outer_id, outer_edge)
        adjacency[outer_id][outer_edge] = (tid, e)
    end

    Lattice(tiles, adjacency, Vector{CurvepieceRef}[])
end
