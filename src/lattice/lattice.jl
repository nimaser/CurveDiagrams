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

"""A curve diagram is a list of sequential curvepieces."""
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
    function Lattice(adjacency::Vector{Vector{Tuple{Int, Int}}})
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

"""Returns the next curve_id to be assigned."""
function _allocate_curve_id!(l::Lattice)
    push!(l._curvediagrams, CurvepieceRef[])
    length(l._curvediagrams)
end

"""Inserts `ref` at position `pos` in the curve diagram with id `curve_id`."""
function _insert_cref!(l::Lattice, curve_id::Int, pos::Int, ref::CurvepieceRef)
    insert!(l._curvediagrams[curve_id], pos, ref)
end

"""Removes the entry at position `pos` from the curve diagram with id `curve_id`."""
function _remove_cref!(l::Lattice, curve_id::Int, pos::Int)
    deleteat!(l._curvediagrams[curve_id], pos)
end

"""
For every entry in the curve diagram at list-position >= `from_pos`, calls
`set_curvepiece_metadata!` on its tile to add `delta` to `anyon_count`.
Call with `delta=+1` after inserting an anyon, `delta=-1` after removing one.
"""
function _shift_anyon_count!(l::Lattice, curve_id::Int, from_pos::Int, delta::Int)
    diagram = l._curvediagrams[curve_id]
    for pos in from_pos:length(diagram)
        ref = diagram[pos]
        t = l._tiles[ref.tile_id]
        cp = curvepiece(t, ref.cp_id)
        set_curvepiece_metadata!(t, ref.cp_id, cp.curve_id, cp.anyon_count + delta)
    end
end

"""
Empties `l._curvediagrams[curve_id]`, permanently retiring the id. All `CurvepieceRef`s in the
diagram must have been removed from their tiles before calling this.
"""
function _delete_curvediagram!(l::Lattice, curve_id::Int)
    isempty(l._curvediagrams[curve_id]) || throw(ArgumentError("curvediagram $curve_id not empty"))
    empty!(l._curvediagrams[curve_id])
end

"""
Updates the `curve_id` field on every `Curvepiece` in every tile that currently has `old_curve_id`,
replacing it with `new_curve_id`. Used in `merge!` after the two `CurveDiagram` vectors have been
concatenated into the surviving curve. Does not delete `old_curve_id`; call `_delete_curvediagram!`
separately.
"""
function _relabel_curve!(l::Lattice, old_curve_id::Int, new_curve_id::Int)
    for ref in l._curvediagrams[new_curve_id]
        t = l._tiles[ref.tile_id]
        cp = curvepiece(t, ref.cp_id)
        cp.curve_id == old_curve_id || continue
        set_curvepiece_metadata!(t, ref.cp_id, new_curve_id, cp.anyon_count)
    end
end
