###############################################################################
# LATTICE HELPER STRUCTS
###############################################################################
"""
We identify each `Curvepiece` in a lattice by storing its tile and its id within that tile.
"""
struct CurvepieceRef
    tile_id::Int
    cp_id::Int
end

"""
A `CurveDiagram` is a directed curve which starts and ends at tile anyons. It
snakes through the lattice, not intersecting any other curve diagram,

Curve diagrams must start and end at anyons, meaning they must start and end with
outgoing and incoming central curvepieces respectively.

"""
const CurveDiagram = Vector{CurvepieceRef}

"""
We identify each edge of a tile in a lattice by storing its tile and its edge number within that tile.
"""
struct TileEdgeRef
    tile_id::Int
    edge::Int
end

###############################################################################
# LATTICE
###############################################################################

"""
A `Lattice` is a collection of `Tile`s connected by sharing edges. Curve diagrams snake through
the `Tile`s on the lattice. A lattice must be defined on a closed, compact manifold, e.g. a sphere
or a torus. The fields of this struct should not be directly modified by the user.

`_tiles[tile_id]` gives the `Tile` with id `tile_id`
`_adjacency[tile_id][edge]` gives a `TileEdgeRef` for the corresponding edge in the neighboring tile
`_curvediagrams[curve_id]` gives the `CurveDiagram` with id `curve_id`

`_curvediagrams` is stored as an array which has a uniform eltype of `CurveDiagram` - this means that
unlike the case of `_curvepieces` in `Tile`, we don't need to store `nothing` but can just use empty
vectors for deleted curve diagrams, meaning our array is homogeneously typed. Furthermore, we assume
that we have a reasonable upper bound on the number of curve diagrams created, meaning the array size
has a maximum, and it can't be more than the number of simulated tiles, which is not going to be more
than a few hundred, meaning worst case we have a few hundred pointers to empty lists, which is not
extraordinarily memory intensive.

The `Lattice` constructor accepts `adjacency` and creates the necessary `Tile`s and other internal
datastructures from it. `adjacency` should use tuples of `tile_id`, `edge` rather than `TileEdgeRef`
structs, and the conversion is done internally. `edge` should be assigned in clockwise order
going around each tile starting from 1. Two tiles sharing multiple edges with each other is unsupported.

Each lattice mutator function in the public API returns an 'action', a ... TODO
"""
struct Lattice
    _tiles::Vector{Tile}
    _adjacency::Vector{Vector{TileEdgeRef}}
    _curvediagrams::Vector{CurveDiagram}
    function Lattice(adjacency::Vector{Vector{Tuple{Int,Int}}})
        adjacency = [[TileEdgeRef(edge_dat...) for edge_dat in tile_dat] for tile_dat in adjacency]
        tiles = Tile[]
        for tile_id in eachindex(adjacency)
            for edge in eachindex(adjacency[tile_id])
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
        curvediagrams = CurveDiagram[]
        new(tiles, adjacency, curvediagrams)
    end
end
