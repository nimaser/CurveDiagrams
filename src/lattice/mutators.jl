"""
Create a new curve diagram between the anyons of two neighboring tiles, directed
from `tile_id1` to `tile_id2`. In particular, an anyon-to-edge and edge-to-anyon
curvepiece are inserted into the first and second tiles respectively, such that
their endpoints on the shared edge between the tiles are siblings, and the
associated `CurvepieceRef`s and other curve diagram bookkeeping structures are created.

For this operation to succeed:
- neither tile's anyon can already be on a curve diagram
- `tile_id1` and `tile_id2` must share exactly one edge

These guarantee that any curvepieces in the two affected tiles are always able to be
deformed to be out of the way of the two new curvepieces. Throws an error if either
condition is violated.

`pos` is the 1-based position in tile 1 at which the shared endpoint is inserted on
the shared edge, and defaults to 1. The corresponding position for the sibling
endpoint in tile 2 is calculated automatically. Throws an error if `pos` is invalid.

Assumes that the lattice is in a valid state to start with, in particular that every edge
endpoint for a curvepiece has a sibling. Violation of this assumption results in
undefined behavior.

Returns `(curve_id, action)` where `action = [0, curve_id, tile_id1, tile_id2]`. `action`
is used by callers to record actions taken by the simulation.
"""
function create_pair!(l::Lattice, tile_id1::Int, tile_id2::Int, pos::Int=1)
    # get references to tiles and edges
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    shared = shared_edge(l, tile_id1, tile_id2)
    shared != nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    e1, e2 = shared
    # check that anyons aren't part of curve diagrams already
    anyon_curve_id(t1) === nothing ||
        throw(ArgumentError("tile $tile_id1 already has an anyon on a curve diagram"))
    anyon_curve_id(t2) === nothing ||
        throw(ArgumentError("tile $tile_id2 already has an anyon on a curve diagram"))
    # check that insertion position is valid; assumes valid lattice state
    N = num_edge_erefs(t1, e1)
    1 <= pos <= N+1 || throw(ArgumentError("pos $pos not in range 1 to $(N+1)"))
    # curve diagram and position setup before curvepiece insertion
    curve_id = _allocate_curve_id!(l)
    anyon_count = 1
    sibling_pos = (N+1) - pos + 1 # see sibling_insert_pos() and sibling_location() for explanation
    # insert curvepieces
    cp_id1 = insert_curvepiece!(t1, curve_id, anyon_count, e1, pos, OUT)
    cp_id2 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_pos, IN)
    # register both curvepieces in the curve diagram
    _insert_cref!(l, curve_id, 1, CurvepieceRef(tile_id1, cp_id1))
    _insert_cref!(l, curve_id, 2, CurvepieceRef(tile_id2, cp_id2))
    # assemble and return the action
    action = [0, curve_id, tile_id1, tile_id2]
    curve_id, action
end

###############################################################################
# CURVE DIAGRAM SIMPLIFICATION
###############################################################################

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
 This validation is left to the caller, and calling this function on an invalid
 `cref` will result in undefined behavior.

 Removing a u-turn in one tile may create a u-turn in another tile if
"""
function _remove_u_turn(l::Lattice, cref::CurvepieceRef)
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
    new_cp_id = merge_curvepieces!(t2, eref_p, eref_n)
    # replace the three consecutive crefs (P, U, N) with one cref for C
    _remove_cref!(l, curve_id, pos_u + 1)  # remove N (highest index first)
    _remove_cref!(l, curve_id, pos_u)      # remove U
    _remove_cref!(l, curve_id, pos_u - 1)  # remove P
    _insert_cref!(l, curve_id, pos_u - 1, CurvepieceRef(p_cref.tile_id, new_cp_id))
end

"""
Remove all removable u-turns from a tile. A removable u-turn curvepiece is one
whose endpoints are adjacent on the same edge E. See `u_turn_cp_ids` and
`_remove_u_turn` for more information.

Any curvepiece with a nesting number of 1 must have adjacent endpoints (see
`calculate_nesting_hierarchy` for more information on nesting numbers). Any
u-turn curvepiece has both endpoints on the same edge. Thus any u-turn curvepiece
with a nesting number of 1 is immediately removable.

If we remove all of the u-turn curvepieces with a nesting number of 1, the
u-turn curvepieces of nesting number 2 will now have nesting number 1 and will
thus be removable. Generalization via induction:
- Any u-turn curvepiece with a nesting number of N has both endpoints on an edge
E, and therefore has the property that all curvepieces which it encloses (which
have nesting numbers in 1...N-1) must also in turn have both of their endpoints
on E. Therefore these enclosed curvepieces must be u-turn curvepieces themselves.
- So if we remove all u-turn curvepieces of nesting numbers 1 through N-1, the
u-turn curvepiece with nesting number N will no longer enclose any curvepieces,
and its endpoints will be adjacent, making it removable.

Therefore, if we remove the u-turn curvepieces in order of increasing nesting order,
starting at 1, all of our removals will be valid.
"""
function _remove_u_turns(l::Lattice, tile_id::Int)
    t = get_tile(l, tile_id)
    modified = Set{Int}([tile_id])
    nesting = calculate_nesting_hierarchy(t)
    u_turns = u_turn_cp_ids(t)
    sort!(u_turns, by = cp_id -> nesting[cp_id][1])
    for cp_id in u_turns
        cref = CurvepieceRef(tile_id, cp_id)
        push!(modified, prev_curvepiece(l, cref).tile_id)
        _remove_u_turn(l, cref)
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
"""
function _remove_u_bend(l::Lattice, cref::CurvepieceRef)
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
    new_cp_id = merge_curvepieces!(o, eref_p_out, eref_n_in)
    # replace the four consecutive crefs (P, U, V, N) with one cref for C
    _remove_cref!(l, curve_id, pos_p + 3)  # remove N
    _remove_cref!(l, curve_id, pos_p + 2)  # remove V
    _remove_cref!(l, curve_id, pos_p + 1)  # remove U
    _remove_cref!(l, curve_id, pos_p)      # remove P
    _insert_cref!(l, curve_id, pos_p, CurvepieceRef(cref.tile_id, new_cp_id))
end

"""
Remove all removable u-bends from a tile.
"""
function _remove_u_bends(l::Lattice, cref1::CurvepieceRef, cref2::CurvepieceRef)

end

"""
Identifies all u-bends in a tile `tile_id` by checking each corner of the tile
against the u-bend criteria. See `_remove_u_bend` for a description of u-bends.

Iterate clockwise through the corners A i.e. adjacent edges (E1, E2) of the tile,
and for each one check if there is a curvepiece endpoint at the last position on
E1. If so, determine if the sibling curvepiece U in T1 hugs A. If so, determine
if the sibling curvepiece V in T2 of U hugs A. If so, the curvepiece the original
curvepiece endpoint on E1 belongs to is the start of a u-bend.
"""
function _find_u_bends(l::Lattice, tile_id::Int)
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
        t2_id, v_eref = sibling_eref(l, t1_id, cp_partner(u_eref))
        t2 = get_tile(l, t2_id)
        hugs_corner(t2, v_eref.cp_id) || continue
        push!(result, CurvepieceRef(tile_id, last_eref.cp_id))
    end
    result
end

"""
Removes all U-turns and trivial bends from all curve diagrams, running to fixed point.

A U-turn is a curvepiece whose two edge endpoints are on the same edge of a tile (a "cup"
or "cap"). A trivial bend is a pair of curvepieces crossing the same shared edge in opposite
directions with no topological content between them.

Runs iteratively until no further simplifications are possible, since removing one U-turn
may expose another.
"""
function simplify!(l::Lattice)
    # TODO
end

###############################################################################
# ANYON REORDERING
###############################################################################

"""
Swap two sequential anyons on the same curve diagram which are in neighboring tiles. The
anyons must be 'directly connected', meaning that between them are exactly two edge-to-anyon
curvepieces, one in `tile_id1` and one in `tile_id2`, which connect to each other at the
shared edge. The value of `dir` indicates whether the new curve diagram should be a (+1)
'counterclockwise' or (-1) 'clockwise' swap.

The swap can be visualized as first identifying the two curvepieces which directly connect
the two anyons and reversing their directions, then disconnecting the other (up to) two
curvepieces which connect those anyons to the rest of the curvediagram from the anyons.
Then stretch the disconnected ends either clockwise or counterclockwise around the two
anyons to connect to the anyon they were not connected to originally. This will require
stretching them across the shared edge between the tiles, and thus each single edge-to-anyon
curvepiece will become an edge-to-edge curvepiece chained to an edge-to-anyon curvepiece.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge
- both tiles have anyons on the same curve diagram
- no other anyon lies between them along the curve
- `dir` is `+1` or `-1`

Returns `action = [3, curve_id, seg, dir]`, where `seg` is the segment index between the
two anyons before the swap.
"""
function swap!(l::Lattice, tile_id1::Int, tile_id2::Int, dir::Int)
    # # validation
    # t1 = get_tile(l, tile_id1)
    # t2 = get_tile(l, tile_id2)
    # shared = shared_edge(l, tile_id1, tile_id2)
    # shared != nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    # e1, e2 = shared
    # cid1 = anyon_curve_id(t1)
    # cid2 = anyon_curve_id(t2)
    # cid1 != nothing || throw(ArgumentError("tile $tile_id1's anyon not on a curve diagram"))
    # cid2 != nothing || throw(ArgumentError("tile $tile_id2's anyon not on a curve diagram"))
    # cid1 == cid2 || throw(ArgumentError("tile $tile_id1 and $tile_id2's anyons on differing curve diagrams $cid1 and $cid2"))
    # curve_id = cid1
    # p_anyon_tile = prev_anyon(l, tile_id1)
    # n_anyon_tile = next_anyon(l, tile_id1)
    # p_anyon_tile == tile_id2 || n_anyon_tile == tile_id2 ||
    #     throw(ArgumentError("tile $tile_id1 and $tile_id2's anyons not sequential on their curve diagram"))
    # # reorder so tile_id1's anyon comes before tile_id2's in the diagram
    # if p_anyon_tile == tile_id2
    #     tile_id1, tile_id2 = tile_id2, tile_id1
    #     t1, t2 = t2, t1
    #     e1, e2 = e2, e1
    # end
    # # identify the two curvepieces that go between the two anyons
    # cp_ids1 = anyon_cp_ids(t1)
    # cp_ids2 = anyon_cp_ids(t2)
    # cp1 = cp_ids1[argmax(cp_id -> curvepiece(t1, cp_id).anyon_count, cp_ids1)]
    # cp2 = cp_ids2[argmin(cp_id -> curvepiece(t2, cp_id).anyon_count, cp_ids2)]
    # anyon_count = curvepiece(t1, cp1).anyon_count
    # # check that the two curvepieces are siblings
    # cp1_edge_eref = cp_partner(anyon_eref(t1, cp1))
    # _, sib_eref = sibling_eref(l, tile_id1, cp1_edge_eref)
    # sib_eref.cp_id == cp2 || throw(ArgumentError("tiles $tile_id1 and $tile_id2 anyons are not directly connected"))
    # # get the other edge-to-anyon in each tile which doesn't connect the two anyons
    # cp1_other = partner_cp_id(t1, cp1)  # nothing if cp1 is the only anyon cp in t1
    # cp2_other = partner_cp_id(t2, cp2)  # nothing if cp2 is the only anyon cp in t2
    # # flip the direction of the connecting segment
    # flip_direction!(t1, cp1)
    # flip_direction!(t2, cp2)
    # # remove the nonconnecting edge-to-anyon curvepieces in the tiles, saving their edge endpoints first
    # if cp1_other !== nothing
    #     cp1_other_edge_eref = cp_partner(anyon_eref(t1, cp1_other))
    #     cp1_other_ep = endpoint(t1, cp1_other_edge_eref)::EdgeEndpoint
    #     remove_curvepiece!(t1, cp1_other)
    # end
    # if cp2_other !== nothing
    #     cp2_other_edge_eref = cp_partner(anyon_eref(t2, cp2_other))
    #     cp2_other_ep = endpoint(t2, cp2_other_edge_eref)::EdgeEndpoint
    #     remove_curvepiece!(t2, cp2_other)
    # end
    # # get positions of connecting curvepieces and edge-to-edge curvepiece insertion points
    # p1 = (endpoint(t1, cp_partner(anyon_eref(t1, cp1)))::EdgeEndpoint).pos
    # p2 = (endpoint(t2, cp_partner(anyon_eref(t2, cp2)))::EdgeEndpoint).pos
    # e1_insert_ee = p1 + (dir == 1 ? 1 : 0)
    # e2_insert_ee = p2 + (dir == 1 ? 1 : 0)
    # _, _, e2_insert_ae = sibling_location(t1, e1, e1_insert_ee)
    # _, _, e1_insert_ae = sibling_location(t2, e2, e2_insert_ee)
    # # insert edge-to-edge curvepieces to replace removed curvepieces, with endpoints either clockwise
    # # or counterclockwise of the edge endpoint of cp1/2 depending on dir
    # new_cp1_other = nothing
    # new_cp2_other = nothing
    # if cp1_other !== nothing
    #     new_cp1_other = insert_curvepiece!(t1, curve_id, anyon_count - 1,
    #         cp1_other_ep.edge, cp1_other_ep.pos, e1, e1_insert_ee)
    # end
    # if cp2_other !== nothing
    #     new_cp2_other = insert_curvepiece!(t2, curve_id, anyon_count + 1,
    #         e2, e2_insert_ee, cp2_other_ep.edge, cp2_other_ep.pos)
    # end
    # insert edge-to-anyon curvepieces to connect the edge-to-edge curvepieces just added
    # in each tile to the anyon in the other tile
    # claude TODO

    # --- Edge positions ---
    # p1 = position of connectingline1's edge endpoint on e1
    # p2 = sibling_location(l, tile_id1, e1, p1).pos  (= N_e1 - p1 + 1)
    # s1 = direction of connectingline1's edge endpoint on e1 (should be OUT)

    # --- Step 1: flip direction of the connecting segment on both sides ---
    # connectingline1's edge endpoint: direction flips (OUT → IN or IN → OUT)
    # connectingline2's edge endpoint: direction flips (opposite of connectingline1's flip)
    # In Julia this requires removing and re-inserting both cps with flipped edge directions.

    # --- Step 2: handle a1 (the other anyon cp in t1), if present ---
    # a1_cp is currently anyon-to-ek in t1 (some edge ek ≠ e1).
    # It gets detached from t1's anyon and re-routed so its edge-side now crosses e1 too.
    # A new anyon-to-e2 cp (newlabel_2) is created in t2.
    #
    # Concretely:
    #   ek_ep = a1_cp's EdgeEndpoint (on edge ek, position ek_pos)
    #   remove a1_cp from t1 (removes both the anyon endpoint and ek edge endpoint)
    #   re-insert a1_cp as edge-to-edge in t1: (ek, ek_pos) ↔ (e1, new_e1_pos)
    #     dir == +1 (CCW): new_e1_pos = p1 + 1   (a1 passes UNDER connectingline1)
    #     dir == -1 (CW):  new_e1_pos = p1        (a1 passes OVER, then p1 increments to p1+1)
    #   insert newlabel_2_cp in t2 as anyon-to-e2:
    #     dir == +1 (CCW): e2 position = p2        (before connectingline2, before sign flip)
    #     dir == -1 (CW):  e2 position = p2 + 1   (after connectingline2)
    #   newlabel_2_cp gets anyon_count = seg - 1
    #   t2's anyon list becomes [newlabel_2_cp, connectingline2_cp]
    #   (if a1 absent: t2's anyon list = just connectingline2_cp)

    # --- Step 3: handle a2 (the other anyon cp in t2), if present ---
    # Symmetric to step 2: a2_cp detaches from t2's anyon, re-routed to also cross e2.
    # A new anyon-to-e1 cp (newlabel_1) is created in t1.
    #
    #   ek2_ep = a2_cp's EdgeEndpoint (on edge ek2, position ek2_pos)
    #   remove a2_cp from t2
    #   re-insert a2_cp as edge-to-edge in t2: (ek2, ek2_pos) ↔ (e2, new_e2_pos)
    #     dir == +1 (CCW): new_e2_pos = p2 + 1  (after connectingline2; p2 may have shifted)
    #     dir == -1 (CW):  new_e2_pos = p2 - 1  (before connectingline2; p2 may have shifted)
    #   insert newlabel_1_cp in t1 as anyon-to-e1:
    #     dir == +1 (CCW): e1 position = p1 - 1  (before connectingline1; p1 may have shifted)
    #     dir == -1 (CW):  e1 position = p1 + 1  (after connectingline1)
    #   newlabel_1_cp gets anyon_count = seg + 1
    #   t1's anyon list becomes [connectingline1_cp, newlabel_1_cp]
    #   (if a2 absent: t1's anyon list = just connectingline1_cp)

    # --- Step 4: update the curve diagram ---
    # The path segment [i1 .. i2] is replaced (same for BOTH dir values):
    #   [ (tile_id1, a1_cp),         if a1 present
    #     (tile_id2, newlabel_2_cp), if a1 present
    #     (tile_id2, connectingline2_cp),
    #     (tile_id1, connectingline1_cp),
    #     (tile_id1, newlabel_1_cp), if a2 present
    #     (tile_id2, a2_cp) ]        if a2 present
    # The dir difference is purely in the edge positions (steps 2-3), not the path order.
    # In Julia: remove CurvepieceRefs at positions i1..i2, insert the above list at i1.

    # return [3, curve_id, seg, dir]
end

"""
'Bends' curvepiece `cp_id` in `tile_id1` into neighboring `tile_id2`, with the piece in the
second tile making a U-turn shape. Let `e` be the edge shared between `tile_id1` and
`tile_id2`. There are two cases:

1. `cp_id` is an edge-to-edge curvepiece, in which case it is deleted and replaced with
two curvepieces `cp1` and `cp2` in `tile_id1` and a curvepiece `cp3` in `tile_id2`. Each of
`cp1` and `cp2` inherits one of `cp_id`s endpoints and has a new endpoint on `e`. These new
endpoints' siblings in `tile_id2` are the endpoints of `cp3`.

2. `cp_id` is an edge-to-anyon curvepiece, in which case it is replaced by an edge-to-anyon
curvepiece `cp1` and an edge-to-edge curvepiece `cp2` in `tile_id1`, and a curvepiece `cp3`
in `tile_id2`. Similarly to the first case, the original two endpoints of `cp_id` are inherited
by `cp1` and `cp2`, and they also each have one new endpoint whose sibling in `tile_id2` is
an endpoint of `cp3`.

Note that in both cases, there are two ways to match the two original endpoints of `cp_id`
with the two new endpoints on `e`, and in case 1, one of these will lead to crossing curvepieces
and one of them won't. In case 2, if there is only one edge-to-anyon curvepiece (`cp_id`), then
both will not cause crossing, but if there is another such curvepiece, only one is correct, and
which is correct depends on whether you encounter `cp_id`'s edge endpoint or the other edge-to-anyon
curvepiece's edge endpoint first when traversing clockwise from edge `e`.

In all cases, an error is thrown if the operation would lead to intersecting curvepieces.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge
- `cp_id` does not have any endpoints on the shared edge

Returns `(cp1, cp2, cp3)` so the caller can update the curve diagram (replacing `cp_id` with
`cp1`, `cp3`, `cp2` in traversal order).

Implementation:

"""
function stretch!(l::Lattice, tile_id1::Int, cp_id::Int, tile_id2::Int)
    # t1 = get_tile(l, tile_id1)
    # t2 = get_tile(l, tile_id2)
    # e1, e2 = shared_edge(l, tile_id1, tile_id2)
    # cp = curvepiece(t1, cp_id)
    # curve_id = cp.curve_id
    # anyon_count = cp.anyon_count

    # if !is_anyon_curvepiece(t1, cp_id)
    #     # case 1: edge-to-edge
    #     ep1 = cp.endpoint1::EdgeEndpoint  # IN endpoint
    #     ep2 = cp.endpoint2::EdgeEndpoint  # OUT endpoint
    #     # check that neither endpoint is on e1
    #     ep1.endpoint != e1 && ep2.endpoint != e1 || throw(ArgumentError("endpoint cannot be on shared edge"))
    #     # determine which endpoint is directly counterclockwise of e1
    #     ordered = ordered_erefs(t1, Set([EndpointRef(cp_id, 1), EndpointRef(cp_id, 2)]), e1, 1)
    #     ccw_eref = ordered[end]
    #     ccw_ep = endpoint(t1, ccw_eref)::EdgeEndpoint
    #     # walk clockwise from ccw endpoint onto e1, maintaining set of unpaired erefs
    #     unpaired_erefs = Set{EndpointRef}()
    #     insert_pos = nothing
    #     for eref in erefs_between(t1, ccw_ep.edge, ccw_ep.pos, e1, num_edge_erefs(t1,e1)+1)
    #         ep = endpoint(t1, eref)::EdgeEndpoint
    #         if ep.edge == e1 && isempty(unpaired_erefs)
    #             insert_pos = ep.pos
    #             break
    #         elseif eref ∈ unpaired_erefs
    #             delete!(unpaired_erefs, eref)
    #         else
    #             partner = tile_partner(t1, eref, EdgeEndpoint)
    #             partner !== nothing && push!(unpaired_erefs, partner)
    #         end
    #     end
    #     # tail case where on the last iteration we empty the set
    #     if insert_pos === nothing && isempty(unpaired_erefs)
    #         insert_pos = num_edge_erefs(t1, e1) + 1
    #     end
    #     insert_pos === nothing && throw(ArgumentError("stretch! could not find insertion point on e1"))
    #     # insertion
    #     _, _, sibling_pos = sibling_location(l, tile_id1, e1, insert_pos)
    #     remove_curvepiece!(t1, cp_id)
    #     cp1 = insert_curvepiece!(t1, curve_id, anyon_count, ep1.edge, ep1.pos, e1, insert_pos)
    #     if ccw_ep == ep1
    #         # the other e1 endpoint should be more clockwise
    #         cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, insert_pos + 1, ep2.edge, ep2.pos)
    #         cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_pos + 1, e2, sibling_pos + 1)
    #     else
    #         # the other e1 endpoint should be more counterclockwise
    #         cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, insert_pos - 1, ep2.edge, ep2.pos)
    #         cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_pos + 1, e2, sibling_pos + 2)
    #     end
    # else
    #     # # case 2: edge-to-anyon
    #     # anyon_eref = anyon_eref(t1, cp_id)
    #     # edge_eref  = cp_partner(anyon_eref)
    #     # edge_ep    = endpoint(t1, edge_eref)::EdgeEndpoint

    #     # # Sweep clockwise from e1 to find which sub-case we are in.
    #     # # If we encounter edge_ep before the other anyon curvepiece (or there is no other), sub-case a.
    #     # # If we encounter the other anyon curvepiece first, sub-case b.
    #     # other_anyon_cp = partner_cp_id(t1, cp_id)  # nothing if only one anyon cp
    #     # subcase_b = false
    #     # if other_anyon_cp !== nothing
    #     #     other_anyon_eref = anyon_eref(t1, other_anyon_cp)
    #     #     other_edge_eref  = cp_partner(other_anyon_eref)
    #     #     other_edge_ep    = endpoint(t1, other_edge_eref)::EdgeEndpoint
    #     #     # check which comes first in clockwise sweep from e1
    #     #     arc_to_edge  = _erefs_between(t1, e1, num_edge_erefs(t1, e1) + 1, edge_ep.edge, edge_ep.pos)
    #     #     arc_to_other = _erefs_between(t1, e1, num_edge_erefs(t1, e1) + 1, other_edge_ep.edge, other_edge_ep.pos)
    #     #     subcase_b = length(arc_to_other) < length(arc_to_edge)
    #     # end

    #     # N_e1 = num_edge_erefs(t1, e1)

    #     # if !subcase_b
    #     #     # Sub-case a: edge endpoint is on far side.
    #     #     # cp1 (edge-to-edge): inherits edge_ep, new endpoint on e1
    #     #     # cp2 (edge-to-anyon): inherits anyon endpoint, new endpoint on e1
    #     #     arc = _erefs_between(t1, edge_ep.edge, edge_ep.pos + 1, e1, N_e1 + 1)
    #     #     num = length(arc)
    #     #     x = N_e1 - num
    #     #     y = num

    #     #     remove_curvepiece!(t1, cp_id)

    #     #     cp1 = insert_curvepiece!(t1, curve_id, anyon_count, edge_ep.edge, edge_ep.pos, e1, x + 1)
    #     #     cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, x + 2, edge_ep.direction)
    #     #     cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, y + 1, e2, y + 2)
    #     # else
    #     #     # Sub-case b: edge endpoint is on near side (just before e1).
    #     #     # cp1 (edge-to-edge): inherits edge_ep, new endpoint on e1
    #     #     # cp2 (edge-to-anyon): inherits anyon endpoint, new endpoint on e1
    #     #     # The positions on e1 are ordered differently.
    #     #     x = findfirst(r -> r == edge_eref, t1._edge_endpoints[edge_ep.edge]) # pos of other anyon edge ep on e1? first approx
    #     #     y = N_e1 + 1 - x
    #     #     remove_curvepiece!(t1, cp_id)

    #     #     cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, x, edge_ep.direction)
    #     #     cp1 = insert_curvepiece!(t1, curve_id, anyon_count, edge_ep.edge, edge_ep.pos, e1, x + 1)
    #     #     cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, y, e2, y + 1)
    #     end
    # end
    # cp1, cp2, cp3
end

"""
Extends an existing curve diagram by adding a new anyon in `tile_id2`, which must be an
empty neighbor of `tile_id1`. `tile_id1`'s anyon must already be on a curve. `place=+1`
inserts the new anyon immediately after `tile_id1`'s in traversal order; `place=-1` inserts
it before.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge.
- `tile_id1`'s anyon is already on a curve (`anyon_curve_id(l, tile_id1) !== nothing`).
- `tile_id2` contains no anyon curvepiece.
- `place` is `+1` or `-1`.

Returns `action = [1, curve_id, pos, tile_id2]`, where `pos` is the 1-based index of the
new anyon in the curve.
"""
function grow!(l::Lattice, tile_id1::Int, tile_id2::Int, place::Int)
    # --- Validation ---
    # anyon_curve_id(l, tile_id2) !== nothing → error (t2 already has anyon)
    # anyon_curve_id(l, tile_id1) === nothing → error (t1 has no anyon)
    # place ∉ {-1,+1} → error

    # t1 = get_tile(l, tile_id1)
    # t2 = get_tile(l, tile_id2)
    # e1, e2 = shared_edge(l, tile_id1, tile_id2)

    # --- Step 1: clear shielding curvepieces ---
    # A curvepiece shields the anyon from e1 if it appears in the unpaired set of BOTH
    # the CW walk (e1 → anyon) and the CCW walk (e1 → anyon). Stretch each shielding
    # piece (outermost first) until none remain.
    # NOTE: makelist / shielding detection (two-directional walk + intersection) does not
    # yet have a Julia equivalent and needs to be implemented.
    # while any curvepiece in t1 shields the anyon from e1:
    #     stretch!(l, tile_id1, outermost_shielding_cp_id, tile_id2)

    # --- Identify a_cp: the relevant anyon curvepiece in t1 ---
    # place==+1 → the one with the highest anyon_count (last in traversal through the anyon)
    # place==-1 → the one with the lowest anyon_count (first in traversal through the anyon)
    # a_cp_id  = anyon cp in t1 with (place==+1 ? max : min) anyon_count
    # a_cp     = curvepiece(t1, a_cp_id)
    # curve_id = a_cp.curve_id
    # seg      = a_cp.anyon_count

    # --- Determine whether the curve has a segment on the 'place' side of a_cp ---
    # neighbor = (place == +1) ? next_curvepiece(l, tile_id1, a_cp_id)
    #                           : prev_curvepiece(l, tile_id1, a_cp_id)
    # neighbor = (neighbor_tile_id, neighbor_cp_id), or nothing if a_cp is a terminus
    # i1 = find_curve_position(l, curve_id, tile_id1, a_cp_id)

    # if neighbor !== nothing:
    #     neighbor_tile_id, neighbor_cp_id = neighbor
    #
    #     if neighbor_tile_id == tile_id2:
    #         # --- Case A1: the adjacent segment already crosses into t2 ---
    #         #
    #         # neighbor_cp (call it b) is an edge-to-edge curvepiece in t2 with one
    #         # endpoint on e2 (sibling of a_cp's edge endpoint). We split it at t2's
    #         # new anyon:
    #         #   b becomes:    EdgeEndpoint(other_edge) ↔ AnyonEndpoint
    #         #   new_cp gets:  EdgeEndpoint(e2, same pos) ↔ AnyonEndpoint
    #         #
    #         # Concretely:
    #         #   b_ep_e2     = the EdgeEndpoint of b on e2
    #         #   b_ep_other  = the other EdgeEndpoint of b (on some non-e2 edge)
    #         #   remove b from t2
    #         #   b_new    = insert_curvepiece!(t2, curve_id, seg,
    #         #                  b_ep_other.edge, b_ep_other.pos, ANYON)
    #         #   new_cp   = insert_curvepiece!(t2, curve_id, seg,
    #         #                  e2, <position on e2 matching b's old e2 endpoint>, ANYON)
    #         #   NOTE: anyon_count for b_new vs new_cp: both initially get seg; their
    #         #   order in t2's anyon list distinguishes them; _shift_anyon_count! at the
    #         #   end handles final renumbering.
    #         #   NOTE: position arithmetic on e2 after removing b needs careful handling
    #         #   (as in stretch!).
    #         #
    #         # Update curve diagram:
    #         #   replace CurvepieceRef(tile_id2, b_cp_id) with CurvepieceRef(tile_id2, b_new_id)
    #         #   insert  CurvepieceRef(tile_id2, new_cp_id) at position:
    #         #     place==+1 → i1+1   (new anyon is after a in the path)
    #         #     place==-1 → i1     (new anyon is before a in the path)
    #
    #     else:
    #         # --- Case A2: adjacent segment does NOT go to t2 ---
    #         #
    #         # Stretch a_cp into t2, creating a U-turn loop in t2 on e2.
    #         # cp1, cp2, cp3 = stretch!(l, tile_id1, a_cp_id, tile_id2)
    #         # cp3 is now an edge-to-edge loop in t2 (both endpoints on e2).
    #         # Split cp3 at the new anyon in t2, exactly as in case A1:
    #         #   cp3_in_ep  = the IN endpoint of cp3 on e2
    #         #   cp3_out_ep = the OUT endpoint of cp3 on e2
    #         #   remove cp3 from t2
    #         #   cp3a = insert_curvepiece!(t2, curve_id, seg, e2, cp3_in_ep.pos, ANYON)
    #         #   cp3b = insert_curvepiece!(t2, curve_id, seg, e2, cp3_out_ep.pos, ANYON)
    #         #   NOTE: position arithmetic on e2 after removing cp3 needs careful handling.
    #         #
    #         # Update curve diagram:
    #         #   replace CurvepieceRef(tile_id2, cp3) with CurvepieceRef(tile_id2, cp3a)
    #         #   insert  CurvepieceRef(tile_id2, cp3b) adjacent to it
    #         #   (ordering of cp3a vs cp3b in the diagram depends on place)
    #
    # else:
    #     # --- Case B: a_cp is at the terminus of the curve in the 'place' direction ---
    #     # No adjacent segment exists; must create entirely new curvepieces.
    #     #
    #     # Find insertion position on e1: walk CW from a_cp's edge endpoint around t1
    #     # to e1, counting unpaired erefs (same algorithm as in stretch!'s else branch).
    #     # NOTE: find_insertion_position_on_e1 could be extracted from stretch! into a
    #     # shared helper.
    #     # insert_pos = find_insertion_position_on_e1(t1, a_cp_id, e1)
    #     # _, _, sibling_pos = sibling_location(l, tile_id1, e1, insert_pos)
    #     #
    #     # direction = (place == +1) ? OUT : IN
    #     #   place==+1 → OUT on e1 (curve exits t1 after the anyon, heading to t2)
    #     #   place==-1 → IN  on e1 (curve enters t1 before the anyon, coming from t2)
    #     #
    #     # new_cp_t1 = insert_curvepiece!(t1, curve_id, seg, e1, insert_pos, direction)
    #     # new_cp_t2 = insert_curvepiece!(t2, curve_id, seg, e2, sibling_pos+1, opposite(direction))
    #     #
    #     # Extend the curve diagram at the terminus:
    #     # if place == +1:
    #     #     append CurvepieceRef(tile_id1, new_cp_t1) to diagram
    #     #     append CurvepieceRef(tile_id2, new_cp_t2) to diagram
    #     # else: # place == -1
    #     #     prepend CurvepieceRef(tile_id2, new_cp_t2) to diagram
    #     #     prepend CurvepieceRef(tile_id1, new_cp_t1) to diagram

    # --- Step 4: update anyon_count ---
    # From t2's new anyon cp onward in the curve, increment anyon_count by +1.
    # Equivalent to MATLAB's "update segment numbers" loop from istart to end.
    # new_t2_pos_in_diagram = position of t2's new anyon cp in curve diagram
    # _shift_anyon_count!(l, curve_id, new_t2_pos_in_diagram + 1, +1)

    # return [1, curve_id, seg + 1, tile_id2]
end

"""
Merges two distinct curve diagrams by connecting `cp_id_in_t1` in `tile_id1` to
`cp_id_in_t2` in `tile_id2` across their shared edge. The two formerly separate curves
become one connected curve diagram. The surviving `curve_id` is the one with the lower id;
the absorbed curve's id is permanently retired via `_delete_curvediagram!`.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge.
- `cp_id_in_t1` has an endpoint on the shared edge.
- `cp_id_in_t2` has an endpoint on the same shared edge.
- The two curvepieces belong to different curve diagrams.

Returns `action = [2, surviving_curve_id, absorbed_curve_id, 0]`.
"""
function merge!(l::Lattice, tile_id1::Int, cp_id_in_t1::Int, tile_id2::Int, cp_id_in_t2::Int)
    # TODO
end

"""
The primary high-level operation. Drives a sequence of primitive operations until the
anyons in `tile_id1` and `tile_id2` are directly connected on the same curve diagram,
with `tile_id1`'s anyon coming before `tile_id2`'s in traversal order.

Handles four initial cases:
- Both tiles empty → `create_pair!`
- One tile empty → `grow!`
- Both on the same curve → repeated `swap!` / `stretch!` until adjacent
- Both on different curves → `merge!`, then bring adjacent

Returns an N×4 integer matrix where each row encodes one primitive operation in the MATLAB
convention:
- `[0, curve_id, t1, t2]` — pair created
- `[1, curve_id, pos, t2]` — grow
- `[2, curve_id1, curve_id2, 0]` — merge (curve_id1 survives)
- `[3, curve_id, seg, dir]` — swap
- `[-1, 0, 0, 0]` — decoding error (non-trivial loop)

Returns a 0×4 matrix if the anyons are already directly connected.
"""
function makeneighbors!(l::Lattice, tile_id1::Int, tile_id2::Int)
    # TODO
end
