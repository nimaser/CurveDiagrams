### U-TURNS ###

"""
Remove the specified u-turn. A u-turn is a sequence of curvepieces in a curve
diagram which enters and then immediately exits a tile via the same edge.

In particular, a u-turn is a sequence of three curvepieces P, U, and N, where
U (identified by `cref`) is an edge-to-edge curvepiece whose two endpoints are
on the same edge E of a tile T1, and P and N are the previous and next
curvepieces in U's curve diagram. Given this, P and N must be in the same tile
T2 as each other, where T2 is a neighbor of T1.

A u-turn's removal is topologically trivial (i.e. valid) if U's endpoints are
adjacent to each other on E. This is because U can then be 'pulled into' T2
across E without intersecting any other curvepieces, so that the trajectory of
the PUN sequence is entirely contained in T2. This trajectory, not intersecting
any curvepieces, is itself just a curvepiece in T2.

Therefore, the result of the u-turn removal operation is that U is deleted and
P and N are merged into a single curvepiece C in T2, whose endpoints are P's
first endpoint and N's second endpoint.

 **Important**: this function **does not** check that `cref` is a valid U-turn
 curvepiece, or that its endpoints are adjacent and thus removing it is valid.
 It bypasses the curvepiece insertion intersection check when creating C. This
 option was only turned on, for speed purposes, once the function's correctness
 was sanity-checked.

 Returns `nothing`.
"""
function _remove_u_turn!(l::Lattice, cref::CurvepieceRef)
    t1 = get_tile(l, cref.tile_id)
    curve_id = curvepiece(t1, cref.cp_id).curve_id
    # P and N are both in T2 (the neighbor whose shared edge holds U's endpoints)
    p_cref = prev_curvepiece(l, cref)
    n_cref = next_curvepiece(l, cref)
    t2 = get_tile(l, p_cref.tile_id)
    # look up T2's erefs for the shared-edge endpoints of P and N before any mutation
    _, eref_p = sibling_eref(l, cref.tile_id, EndpointRef(cref.cp_id, 1))
    _, eref_n = sibling_eref(l, cref.tile_id, EndpointRef(cref.cp_id, 2))
    # position of U in the curve diagram (P is at pos_u-1, N at pos_u+1)
    pos_u = find_cref_index(l, curve_id, cref)
    # remove U from T1
    remove_curvepiece!(t1, cref.cp_id)
    # merge P and N in T2; returns the new cp_id for C
    new_cp_id = edge_merge!(t2, eref_p, eref_n; allow_intersections=false)
    # replace the three consecutive crefs (P, U, N) with one cref for C
    _remove_cref!(l, curve_id, pos_u + 1)  # remove N (highest index first)
    _remove_cref!(l, curve_id, pos_u)      # remove U
    _remove_cref!(l, curve_id, pos_u - 1)  # remove P
    _insert_cref!(l, curve_id, pos_u - 1, CurvepieceRef(p_cref.tile_id, new_cp_id))
    nothing
end

"""
Remove all removable u-turns from a tile. A removable u-turn curvepiece is one
whose endpoints are adjacent on the same edge E. See `u_turn_cp_ids` and
`_remove_u_turn!` for more information.

We first get the list of all u-turn curvepieces in the tile, and then iterate
through them to determine which ones have adjacent endpoints. We remove those.
If u-turns are nested, this may result in newly-removable u-turns, so we pass
through the updated list repeatedly until there are none with adjacent endpoints.

Just as a note, the approach of calculating nesting numbers upfront and then using
them to remove u-turns in increasing nesting number order breaks down because it
is not true that any curvepiece with a nesting number of 1 must have adjacent
endpoints, because edge-to-anyon curvepieces exist. Taking this approach further
by noting that removing u-turns is order-independent, and trying to just identify
u-turns and then remove them in any order, also fails because of the same reason.

Returns a set containing the ids of any tiles whose internal states were modified
by this operation. The input tile is included in this set anytime any u-turn was
removed, as that necessarily leads to the modificaton of the input tile.
"""
function _remove_u_turns!(l::Lattice, tile_id::Int)
    t = get_tile(l, tile_id)
    modified = Set{Int}()
    while true
        u_turns = u_turn_curvepiece_ids(t)
        adjacent = [cp_id for cp_id in u_turns if let
            cp = curvepiece(t, cp_id)
            ep1 = cp.endpoints[1]::EdgeEndpoint
            ep2 = cp.endpoints[2]::EdgeEndpoint
            abs(ep1.pos - ep2.pos) == 1
        end]
        isempty(adjacent) && break
        push!(modified, tile_id)
        for cp_id in adjacent
            cref = CurvepieceRef(tile_id, cp_id)
            prev = prev_curvepiece(l, cref)
            prev !== nothing && push!(modified, prev.tile_id)
            _remove_u_turn!(l, cref)
        end
    end
    modified
end

### U-BENDS ###

"""
Remove the specified u-bend. A u-bend is a sequence of curvepieces in a curve
diagram which, starting in a tile O, exits O via an edge E1, passes through
two intermediate tiles, then reenters O via an edge E2 which is adjacent to E1.

To clarify the geometry, let
- T1 be the tile neighboring O via E1
- T2 be the tile neighboring O via E2

Note that because E1 and E2 are adjacent, T1 and T2 must be neighbors via some
edge E. Let A be the lattice vertex shared between E1, E2, and E, or in other
words the vertex where tiles O, T1, and T2 meet.

The u-bend goes from O -> T1 -> T2 -> O by crossing E1, E, and E2, in that order.
Put differently, the u-bend exits O, circles around A by passing through T1 and T2,
then reenters O.

In terms of curvepieces: a u-bend is a sequence of four curvepieces P, U, V, and N,
where P (identified by `cref`) and N live in O, while U and V are both edge-to-edge
curvepieces living in T1 and T2 respectively. Endpoint locations:
- P's second and U's first are on E1
- U's second and V's first are on E
- V's second and N's first are on E2

A u-bend's removal is topologically trivial (i.e. valid) if it 'tightly' circles A,
meaning that there are no curvepieces between the u-bends' and A. That is, P's, U's,
and V's second endpoint must be right next to A on E1, E, and E2 respectively. This
is because U and V can then be 'pulled into' O across A without intersecting other
curvepieces, so that the trajectory of the PUVN sequence is entirely contained in O.
This trajectory, not intersecting any curvepieces, is itself just a curvepiece in O.

Therefore, the result of the u-bend removal operation is that U and V are deleted
and P and N are merged into a single curvepiece C in O, whose endpoints are P's
first endpoint and N's second endpoint.

 **Important**: this function **does not** check that `cref` starts a valid u-bend,
 or that removing it is valid. This validation is left to the caller, and calling
 this function on an invalid `cref` will result in undefined behavior.

 Returns `nothing`.
"""
function _remove_u_bend!(l::Lattice, cref::CurvepieceRef)
    o = get_tile(l, cref.tile_id)
    curve_id = curvepiece(o, cref.cp_id).curve_id
    # U, V, N follow P sequentially in the curve diagram
    u_cref = next_curvepiece(l, cref)
    v_cref = next_curvepiece(l, u_cref)
    n_cref = next_curvepiece(l, v_cref)
    t1 = get_tile(l, u_cref.tile_id)
    t2 = get_tile(l, v_cref.tile_id)
    # erefs in O to consume: P's OUT (endpoint2) and N's IN (endpoint1)
    eref_p_out = EndpointRef(cref.cp_id, 2)
    eref_n_in  = EndpointRef(n_cref.cp_id, 1)
    # position of P in the curve diagram (U at pos+1, V at pos+2, N at pos+3)
    pos_p = find_cref_index(l, curve_id, cref)
    # remove U and V from their tiles
    remove_curvepiece!(t1, u_cref.cp_id)
    remove_curvepiece!(t2, v_cref.cp_id)
    # merge P and N in O; returns the new cp_id for C
    new_cp_id = edge_merge!(o, eref_p_out, eref_n_in)
    # replace the four consecutive crefs (P, U, V, N) with one cref for C
    _remove_cref!(l, curve_id, pos_p + 3)  # remove N
    _remove_cref!(l, curve_id, pos_p + 2)  # remove V
    _remove_cref!(l, curve_id, pos_p + 1)  # remove U
    _remove_cref!(l, curve_id, pos_p)      # remove P
    _insert_cref!(l, curve_id, pos_p, CurvepieceRef(cref.tile_id, new_cp_id))
    nothing
end

"""
Identifies all immediately removable u-bends in a tile `tile_id` by checking
each corner of the tile against the u-bend criteria. See `_remove_u_bend!` for
a description of u-bends.

Iterate clockwise through the corners A i.e. adjacent edges (E1, E2) of the tile,
and for each one check if there is a curvepiece endpoint at the last position on
E1. If so, determine if the sibling curvepiece U in T1 hugs A. If so, determine
if the sibling curvepiece V in T2 of U hugs A. If so, the curvepiece the original
curvepiece endpoint on E1 belongs to is the start of an immediately removable u-bend.

This function is relatively efficient, requiring `O(N)` curvepiece lookup operations
where `N` is the number of corners in the tile.

Returns a list of `CurvepieceRef`s which start removable u-bends, each of which can
be passed to `_remove_u_bend!` as the "P" curvepiece.
"""
function _find_removable_u_bends(l::Lattice, tile_id::Int)
    t = get_tile(l, tile_id)
    result = CurvepieceRef[]
    for e1 in 1:num_edges(t)
        has_edge_erefs(t, e1) || continue
        # last endpoint on E1 belongs to P; its sibling in T1 is U's endpoint on E1'
        last_eref = edge_eref(t, e1, num_edge_erefs(t, e1))
        t1_id, u_eref = sibling_eref(l, tile_id, last_eref)
        t1 = get_tile(l, t1_id)
        hugs_corner(t1, u_eref.cp_id) || continue
        # U's other endpoint gives V's sibling in T2
        t2_id, v_eref = sibling_eref(l, t1_id, curvepiece_partner(u_eref))
        t2 = get_tile(l, t2_id)
        hugs_corner(t2, v_eref.cp_id) || continue
        push!(result, CurvepieceRef(tile_id, last_eref.cp_id))
    end
    result
end

"""
Remove all removable u-bends from a tile. A u-bend is a part of a curve diagram
which exits a tile, wraps tightly around a lattice vertex, and then re-enters
the original tile. A u-bend is removable if all of its endpoints are directly
adjacent to the encircled lattice vertex. See `_remove_u_bend!` for more details.

Suppose several u-bends are nested inside of each other, and the innermost one
is removable. Removing it will lead to the endpoints of the second-innermost one
becoming adjacent to the vertex, making it the new innermost u-bend, and also
removable. In other words, removing a u-bend may make other u-bends removable.

Since `_find_removable_u_bends` only identifies the innermost u-bend on each corner
even if many are nested, we call that function repeatedly, iteratively removing
u-bends until there are none left.

Returns a set containing the ids of any tiles whose internal states were modified
by this operation. The input tile is included in this set anytime any u-bend was
removed, as that necessarily leads to the modificaton of the input tile.
"""
function _remove_u_bends!(l::Lattice, tile_id::Int)
    modified = Set{Int}()
    while true
        u_bends = _find_removable_u_bends(l, tile_id)
        isempty(u_bends) && break
        push!(modified, tile_id)
        for p_cref in u_bends
            u_cref = next_curvepiece(l, p_cref)
            v_cref = next_curvepiece(l, u_cref)
            push!(modified, u_cref.tile_id)
            push!(modified, v_cref.tile_id)
            _remove_u_bend!(l, p_cref)
        end
    end
    modified
end

### SIMPLIFY ###

"""
Simplify the lattice by removing all all u-bends and u-turns from `l`. See
`_remove_u_bend!` and `_remove_u_turn!` for descriptions of u-bends and u-turns, and
`_remove_u_bends!` and `_remove_u_turns!` for explanations of how to remove all of
the u-bends and u-turns in a tile, respectively.

Simplifies the lattice tile-by-tile. We maintain a workset of tiles which need to
be simplified, initialized to contain every tile in the lattice, and then repeatedly
<remove a tile from the workset and simplify it> until the workset is empty. Simplifying
a tile consists of removing its u-bends and u-turns. We keep track of what tiles were
modified by these operations, and these modified tiles are re-added to the workset.

Because a tile is itself modified if a u-bend or u-turn is removed from it, a tile
will continue to be re-added to the workset until the u-bend and u-turn removal
functions are idempotent on it, i.e. there are no u-bends or u-turns left in it.
Furthermore, simplifying an adjacent tile may cause a tile which has left the
workset to be re-added to it. Thus, the workset will only be empty once no
simplifications are possible across the entire lattice, i.e. the lattice is at a
fixed point of the u-bend and u-turn removal functions.

It is intuitive why this approach works for u-turns: given that a removable u-turn
is detected by looking at the curvepieces inside a tile, it is only possible to go
from a tile not having a removable u-turn to having a removable u-turn if the
arrangement of curvepieces inside the tile changes. So by adding tiles whose contents
were modified to the workset, and initializing the workset with all tiles, we guarantee
that there are never tiles with an immediately removable u-turn not in the workset.

For u-bends, the reasoning is slightly more subtle. Removable u-bends detectable
'at a tile' depend on the arrangement of curvepieces located in adjacent tiles. So
how do we know that modifying a tile will not cause a removable u-bend to become
detectable in an adjacent tile? In other words, how can we be sure that our scheme
to re-add tiles to the workset will never fail to add a tile with a u-bend removal
that became possible due to modifying an adjacent tile? The proof is too long and
I don't want to write it out, but by remembering that curvepieces can never cross,
you can work out all of the cases on paper pretty easily.

Since identifying u-bends is `O(number of tile corners)` while identifying u-turns is
`O(number of tile curvepieces)`, while simplifying a tile we remove the u-bends first,
to make removing the u-turns faster by reducing the number of curvepieces.

Partial lattice simplification is also possible. If `curve_id` is set, then only
the tiles containing curvepieces from that curve diagram will be added to the initial
workset. This does not mean that they will be the only tiles simplified, however.
"""
function simplify!(l::Lattice; curve_id::Union{Nothing,Int}=nothing)
    workset = curve_id === nothing ? Set{Int}(1:num_tiles(l)) : tiles_in(l, curve_id)
    while !isempty(workset)
        tile_id = pop!(workset)
        modified = _remove_u_bends!(l, tile_id) ∪ _remove_u_turns!(l, tile_id)
        delete!(modified, tile_id)
        union!(workset, modified)
    end
end
