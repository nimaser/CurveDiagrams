################################################################################
# CREATE
################################################################################

"""
Create a u-turn by pulling `cref` across position `pos` in edge `edge` of its tile.
This operation is the 'inverse' of `_remove_u_turn!`, which is used in `simplify!`.

In detail, suppose `cref` refers to a curvepiece C, with endpoints e1 and e2 (in
traversal order), in a tile T1. T1 borders another tile T2 across the edge `edge`.

After this operation, C will have been deleted and replaced in its curve diagram
with a sequence of three new curvepieces, P, U, and N. P and N will be located in
T1, and will each 'inherit' one of C's endpoints e1 and e2, while U will be a
u-turn curvepiece located in T2.
- P's first endpoint will be e1 while its second endpoint, p2, will be on `edge`
- N's first endpoint, n1, will be on `edge` while its second endpoint will be e2
- U's first and second endpoints will be the siblings of p2 and n1 respectively,
hence connecting P to N

Either p2 or n1 will be at position `pos`, with the other at position `pos+1`,
depending on the exact layout of curvepieces in T1. The ordering is selected so
that P and N do not intersect each other. See `split_curvepiece!` for more
information on how this assignment is done.

Return a `CurvepieceRef` to P, from which U and N can be quickly fetched via
`next_curvepiece`.
"""
function _create_u_turn!(l::Lattice, cref::CurvepieceRef, edge::Int, pos::Int)
    t1 = get_tile(l, cref.tile_id)
    cp = curvepiece(t1, cref.cp_id)
    curve_id = cp.curve_id
    ac = cp.anyon_count
    ter = corresponding_edge(l, cref.tile_id, edge)
    t2_id, t2_edge = ter.tile_id, ter.edge
    t2 = get_tile(l, t2_id)
    pos_c = find_cref_index(l, curve_id, cref)

    p_id, n_id = edge_split!(t1, cref.cp_id, edge, pos)
    _remove_cref!(l, curve_id, pos_c)
    _insert_cref!(l, curve_id, pos_c, CurvepieceRef(cref.tile_id, p_id))
    _insert_cref!(l, curve_id, pos_c + 1, CurvepieceRef(cref.tile_id, n_id))

    p_ep = curvepiece(t1, p_id).endpoints[2]::EdgeEndpoint
    n_ep = curvepiece(t1, n_id).endpoints[1]::EdgeEndpoint
    # sibling_location reflects T2's edge before any u-turn insertions; T1's edge
    # gained 2 endpoints via edge_split! without corresponding T2 insertions, so the
    # true final positions in T2 are each +2 higher.
    _, _, spos1 = sibling_location(l, cref.tile_id, p_ep.edge, p_ep.pos)
    _, _, spos2 = sibling_location(l, cref.tile_id, n_ep.edge, n_ep.pos)
    f1, f2 = spos1 + 2, spos2 + 2
    # convert final positions to sequential insertion coords: insert pos1 first, then pos2
    u_pos1 = f1 ≤ f2 ? f1 : f1 - 1
    u_pos2 = f2

    u_id = insert_curvepiece!(t2, curve_id, ac, t2_edge, u_pos1, t2_edge, u_pos2; check_intersections=false)
    _insert_cref!(l, curve_id, pos_c + 1, CurvepieceRef(t2_id, u_id))
    CurvepieceRef(cref.tile_id, p_id)
end

################################################################################
# REMOVE
################################################################################

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
    new_cp_id = edge_merge!(t2, eref_p, eref_n)
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
