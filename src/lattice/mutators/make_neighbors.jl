################################################################################
# CREATE PAIR
################################################################################

"""
Create a new `Curve` between the anyons of two neighboring tiles, directed from
`tile_id1` to `tile_id2`. In particular, an outgoing and incoming central
curvepiece are inserted into the first and second tiles respectively, such that
their endpoints on the shared edge between the tiles are siblings.

Throw an error if
- either tile's anyon is already on a `Curve`
- `tile_id1` and `tile_id2` are not neighbors

These conditions guarantee that any curvepieces in the two affected tiles are able
to be deformed out of the way of the two new curvepieces.

`pos` is the 1-based position in tile 1 at which the shared endpoint is inserted on
the shared edge, and defaults to 1. The corresponding position for the sibling
endpoint in tile 2 is calculated automatically. Throws an error if `pos` is invalid.

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
    curve_id(t1) === nothing ||
        throw(ArgumentError("tile $tile_id1 already has an anyon on a curve diagram"))
    curve_id(t2) === nothing ||
        throw(ArgumentError("tile $tile_id2 already has an anyon on a curve diagram"))
    # check that insertion position is valid; assumes valid lattice state
    N = num_edge_erefs(t1, e1)
    1 <= pos <= N + 1 || throw(ArgumentError("pos $pos not in range 1 to $(N+1)"))
    # curve diagram and position setup before curvepiece insertion
    cid = _allocate_curve_id!(l)
    acount = 1
    sibling_pos = (N + 1) - pos + 1 # see sibling_location() for explanation
    # insert curvepieces
    cp_id1 = insert_curvepiece!(t1, cid, acount, e1, pos, OUT)
    cp_id2 = insert_curvepiece!(t2, cid, acount, e2, sibling_pos, IN)
    # register both curvepieces in the curve diagram
    _insert_cref!(l, cid, 1, CurvepieceRef(tile_id1, cp_id1))
    _insert_cref!(l, cid, 2, CurvepieceRef(tile_id2, cp_id2))
    # assemble and return the action
    action = [0, cid, tile_id1, tile_id2]
    cid, action
end

################################################################################
# GROW!
################################################################################

"""
'Stretches' curvepiece `cref` into neighboring `tile_id2` to form a u-turn; see
`_create_u_turn!` for specific details on the configuration of u-turns. If there
are any 'shielding' curvepieces in the way, they are stretched into `tile_id2`
first.

Let E be the edge shared between `cref`'s tile and `tile_id2`, and the position
on E through which `cp_id` is pulled into `tile_id2` be the insertion position.
A shielding curvepiece is one which partitions the tile into two parts, one of
which contains the insertion position, and the other of which contains `cref`.
If it is not moved out of the way (by creating a u-turn in it, and thus creating
a 'clear path' to the insertion position), trying to create a u-turn in `cref`
will lead to curvepiece intersections.

Shielding curvepieces need to be dealt with in order from the innermost outwards,
because if there are multiple, the inner ones will also shield the outer ones.

The insertion position is chosen automatically to minimize the number of shielding
curvepieces, and the processing order is determined in the same pass. See
`_minimal_shielding_position` for details on how this is done. The endpoint
arguments to that function are chosen as one edge endpoint of `cref` along with
its tile partner. In the case where the tile partner doesn't exist, that (sole)
edge endpoint is used for both endpoint arguments.

All curve diagrams containing affected curvepieces are automatically updated.
Return a `CurvepieceRef` to the first curvepiece created from `cref` (the P of the
three curvepieces, P, U, and N, created when creating a u-turn).
"""
function _stretch!(l::Lattice, cref::CurvepieceRef, tile_id2::Int)
    t1 = get_tile(l, cref.tile_id)
    cp = curvepiece(t1, cref.cp_id)
    e1, _ = shared_edge(l, cref.tile_id, tile_id2)

    # Get one edge endpoint of cref and its tile partner (or itself if no partner)
    eref1 = EndpointRef(cref.cp_id, cp.endpoints[1] isa EdgeEndpoint ? 1 : 2)
    tp = tile_partner(t1, eref1, EdgeEndpoint)
    eref2 = tp !== nothing ? tp : eref1

    # Find optimal insertion position and ordered shielding list (innermost last)
    best_pos, shield_list = _minimal_shielding_position(l, TileEdgeRef(cref.tile_id, e1), eref1, eref2)
    n = length(shield_list)

    # Stretch shields innermost-first; each shifts best_pos up by 1
    for cp_id in reverse(shield_list)
        _stretch!(l, CurvepieceRef(cref.tile_id, cp_id), tile_id2)
    end

    _create_u_turn!(l, cref, e1, best_pos + n)
end

"""
Extend an existing curve diagram which has an anyon in `tile_id1` by adding a
new anyon in `tile_id2`; `tile_id2` must be a neighbor of `tile_id1` whose anyon is
not already on a curve diagram.

`place=+1` inserts the new anyon immediately after `tile_id1`'s in traversal order,
while `place=-1` inserts it immediately before.

Implementation-wise, there are six cases, depending on where t1 is in the curve
and what the value of place is:
- t1 is the first anyon, place = -1: connect t2's anyon to t1's anyon with
curvepieces with anyon count 1, insert curvepiecerefs into the beginning of the
curvepiece, and update the anyon count values for all subsequent curvepieces in
the curve diagram - t1 is the last anyon, place = +1: connect t1's anyon to t2's
anyon with curvepieces with anyon count 1
- t1 is the first anyon, place = +1: stretch the curve diagram's first curvepiece
into t2, then anyon_split it to connect to t2's anyon, and update the curvepiecerefs
and curvepiece anyon counts accordingly
- t1 is the last anyon, place = -1: stretch the curve diagram's last curvepiece
into t2, then anyon_split it to connect to t2's anyon, and update the curvepiecerefs
and curvepiece anyon counts accordingly
- t1 is a middle anyon, place = -1, +1: stretch the preceding or following central
curvepiece respectively from t1's anyon into t2, and adjust curvepiecerefs and
curvepiece anyon counts appropriately

Returns `action = [1, curve_id, pos, tile_id2]`, where `pos` is the 1-based index of the
new anyon in the curve.
"""
function grow!(l::Lattice, tile_id1::Int, tile_id2::Int, place::Int)
    @show test
    shared = shared_edge(l, tile_id1, tile_id2)
    shared !== nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    e1, e2 = shared
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    curve_id(t1) !== nothing || throw(ArgumentError("tile $tile_id1 has no anyon on a curve diagram"))
    curve_id(t2) === nothing || throw(ArgumentError("tile $tile_id2 already has an anyon on a curve diagram"))
    place ∈ (-1, +1) || throw(ArgumentError("place must be -1 or +1"))

    cid = curve_id(t1)
    seg = anyon_count(t1)

    # Find the anyon cp on the 'place' side: OUT direction for +1, IN for -1
    wanted_dir = place == 1 ? OUT : IN
    a_cp_id = let ids = collect(central_curvepiece_ids(t1))
        idx = findfirst(id -> curvepiece(t1, id).endpoints[1].direction == wanted_dir, ids)
        idx === nothing ? nothing : ids[idx]
    end

    if a_cp_id !== nothing
        # Cases 3, 4, 5: a cp exists on the place side — stretch it into t2, then
        # anyon_split the resulting u-turn to attach t2's anyon.
        a_cref = CurvepieceRef(tile_id1, a_cp_id)
        p_cref = _stretch!(l, a_cref, tile_id2)
        pos_p = find_cref_index(l, cid, p_cref)
        u_cref = l._curves[cid][pos_p+1]

        c1_id, c2_id = anyon_split!(t2, u_cref.cp_id)

        # Replace U in diagram with [C1, C2]
        _remove_cref!(l, cid, pos_p + 1)
        _insert_cref!(l, cid, pos_p + 1, CurvepieceRef(tile_id2, c1_id))
        _insert_cref!(l, cid, pos_p + 2, CurvepieceRef(tile_id2, c2_id))

        # N (now at pos_p+3) and everything after need anyon_count +1
        _shift_anyon_count!(l, cid, pos_p + 3, +1)
    else
        # Cases 1, 2: terminus in the place direction — stretch the only existing
        # anyon cp to move shields, then remove the u-turn to recover a clear path.
        opp_cref = CurvepieceRef(tile_id1, only(central_curvepiece_ids(t1)))
        p_cref = _stretch!(l, opp_cref, tile_id2)
        pos_p = find_cref_index(l, cid, p_cref)
        u_cref = l._curves[cid][pos_p+1]
        n_cref = l._curves[cid][pos_p+2]

        # Record the e1 positions that will be vacated by u-turn removal
        p_pos_on_e1 = (curvepiece(t1, p_cref.cp_id).endpoints[2]::EdgeEndpoint).pos
        n_pos_on_e1 = (curvepiece(t1, n_cref.cp_id).endpoints[1]::EdgeEndpoint).pos
        insert_pos = min(p_pos_on_e1, n_pos_on_e1)

        _remove_u_turn!(l, u_cref)

        # e1 and e2 are back in sync; compute sibling position before inserting
        _, _, sibling_pos = sibling_location(l, tile_id1, e1, insert_pos)
        sibling_pos += 1

        if place == 1
            # Case 2: t1 is last — append new OUT cp in t1 and IN cp in t2
            new_t1_id = insert_curvepiece!(t1, cid, seg, e1, insert_pos, OUT)
            new_t2_id = insert_curvepiece!(t2, cid, seg, e2, sibling_pos, IN)
            n = length(l._curves[cid])
            _insert_cref!(l, cid, n + 1, CurvepieceRef(tile_id1, new_t1_id))
            _insert_cref!(l, cid, n + 2, CurvepieceRef(tile_id2, new_t2_id))
        else
            # Case 1: t1 is first — prepend new OUT cp in t2 and IN cp in t1
            new_t1_id = insert_curvepiece!(t1, cid, 1, e1, insert_pos, IN)
            new_t2_id = insert_curvepiece!(t2, cid, 1, e2, sibling_pos, OUT)
            _insert_cref!(l, cid, 1, CurvepieceRef(tile_id1, new_t1_id))
            _insert_cref!(l, cid, 1, CurvepieceRef(tile_id2, new_t2_id))
            # Original crefs are now at positions 3+; shift their anyon counts
            _shift_anyon_count!(l, cid, 3, +1)
        end
    end

    new_pos = place == 1 ? seg + 1 : seg
    [1, cid, new_pos, tile_id2]
end

"""
Merge two existing `Curve`s, which have anyons in `tile_id1` and `tile_id2`
respectively; `tile_id1` and `tile_id2` must be neighbors.

Throw an error if:
- input tiles are not neighbors
- input tiles' anyons are not on distinct `Curves`
- there are any shielding curvepieces blocking either anyon from the shared
edge between the two tiles

To implement this function, we need to attach the end of one `Curve` to the
start of the other. To avoid creating any intersections, we first extend one
`Curve` from its last anyon to its input tile's anyon, taking a path directly
parallel to the `Curve`. Likewise, we extend the other `Curve` by traversing
from its input tile to its first anyon, again travelling directly parallel to
it. In both cases, the extensions will traverse in the opposite direction from
the parts of the `Curve` they are adjacent/parallel to.

The choice of for which `Curve` to choose the first and for which to choose the
last anyon is arbitrary, so we make the choice that minimizes the total length
of the extensions, measured in tile edge crossings.

The extensions are then connected via the shared edge between the two tiles.
It is assumed that there are no shielding curvepieces that would block that
operation.

Return `action = [2, surviving_curve_id, absorbed_curve_id, 0]`.
"""
function merge!(l::Lattice, tile_id1::Int, tile_id2::Int)
    # calculate correct insertion position using _minimal_shielding_position

    # if num shielding curvepieces is not 0, throw error

    # calculate distance to both pairs of endpoints, find minimum distance choice

    # create extensions

    # connect extensions
end

"""
The primary high-level operation. Drives a sequence of primitive operations until the
anyons in `tile_id1` and `tile_id2` are directly connected on the same curve diagram,
with `tile_id1`'s anyon coming before `tile_id2`'s in traversal order.

Handles four initial cases:
- Both tiles empty → `create_pair!`
- One tile empty → `grow!`
- Both on the same curve → repeated `swap!` / `_stretch!` until adjacent
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
function make_neighbors!(l::Lattice, tile_id1::Int, tile_id2::Int)
    # TODO
end
