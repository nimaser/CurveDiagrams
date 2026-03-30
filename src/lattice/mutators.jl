"""
Creates a new curve diagram between the anyons of two neighboring tiles, directed
from `tile_id1` to `tile_id2`. In particular, two edge-to-anyon curvepieces are
inserted, one in each tile, such that their endpoints on the shared edge between
the tiles are siblings, and corresponding `CurvepieceRef`s are stored for each.

Preconditions:
- neither tile's anyon is already on a curve diagram
- `tile_id1` and `tile_id2` share exactly one edge
These guarantee that any curvepieces in the two affected tiles are always able to be
deformed to be out of the way of the two new curvepieces. Throws an error if either
is violated.

`pos` is the 1-based position at which the shared endpoint is inserted on the shared
edge of `tile_id1`, and defaults to 1. The corresponding position for the sibling
endpoint in `tile_id2` is calculated automatically. Throws an error if `pos` is invalid.

Returns `(curve_id, action)` where `action = [0, curve_id, tile_id1, tile_id2]`. `action`
is used by callers to record actions taken by the simulation.
"""
function create_pair!(l::Lattice, tile_id1::Int, tile_id2::Int, pos::Int=1)
    # check that anyons aren't part of curve diagrams already
    anyon_curve_id(l, tile_id1) === nothing ||
        throw(ArgumentError("tile $tile_id1 already has an anyon on a curve"))
    anyon_curve_id(l, tile_id2) === nothing ||
        throw(ArgumentError("tile $tile_id2 already has an anyon on a curve"))
    # get references to tiles and edges
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    shared = shared_edge(l, tile_id1, tile_id2)
    shared != nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    e1, e2 = shared
    # check that insertion position is valid
    N = num_endpoints(t1, e1)
    1 <= pos <= N+1 || throw(ArgumentError("pos $pos not in range 1 to $(N+1)"))
    # insert the first curvepiece in tile 1
    curve_id = _allocate_curve_id!(l)
    anyon_count = 1
    cp_id1 = insert_curvepiece!(t1, curve_id, anyon_count, e1, pos, OUT)
    # calculate the corresponding position in tile_id2
    sibling_pos = (N+1) - pos + 1
    cp_id2 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_pos, IN)
    # register both curvepieces in the curve diagram
    _insert_curvediagram_curvepiece!(l, curve_id, 1, CurvepieceRef(tile_id1, cp_id1))
    _insert_curvediagram_curvepiece!(l, curve_id, 2, CurvepieceRef(tile_id2, cp_id2))
    # assemble and return the action
    action = [0, curve_id, tile_id1, tile_id2]
    curve_id, action
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

In all cases, an error is thrown if the operation would lead to intersecting curvepieces. To
detect intersections, first call one edge endpoint of `cp_id` (or its only edge endpoint in case
2) Z. Collect all curvepieces which have one endpoint between Z and `e`, but not on `e`. If any
of those curvepieces have their other endpoint between Z and `e` going around 'the other way',
the stretch will cause an intersection.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge

Returns `(cp1, cp2, cp3)` so the caller can update the curve diagram (replacing `cp_id` with
`cp1`, `cp3`, `cp2` in traversal order).

Implementation:
1. a. First, if either endpoint of `cp_id` is on `e`, we do not need to do the intersection check.
Call one such endpoint `ep`, at position `p` on edge `e`. We directly add `cp1` at positions
`p+1` and `p+2`, then remove `cp_id` so that `cp1` 'slides into place' to align with the sibling
of `ep` in tile 2. We then add `cp2`'s `e` endpoint right after the endpoint inserted at position
`p+2` (and now at position `p+1`), and its other endpoint is wherever `cp_id`s other endpoint was.
Finally, we add `cp3` to connect `cp1` and `cp2`. Depending on the direction of `cp_id`, we have
to be careful to insert the curvepiece endpoints in the correct order so the resulting sequence
of curvepieces has the right direction overall. There is also some hairy index math due to the
'coordinate systems' of the edges in t1 and t2 becoming temporarily 'out of sync'.

   b. If neither endpoint is on `e`, we first do the intersection check mentioned above, then need to
find the insertion point for the endpoints on `e`. This is accomplished by walking from whichever
endpoint of `cp_id` is immediately counterclockwise of `e` to and onto `e` in the clockwise
direction. While walking, we keep a set of `cp_id`s: if we encounter an endpoint whose `cp_id` is
new, we add it to the set, while if its already in the set, we remove it from the set. This means
that we only have unpaired `cp_id`s in the set: once we reach positions on `e`, if we ever have
an empty set, it means there are no curvepieces going 'over our heads' and blocking the path from
the original `cp_id` to the edge, and thus this is the insertion point.

2.
"""
function stretch!(l::Lattice, tile_id1::Int, cp_id::Int, tile_id2::Int)
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    e1, e2 = shared_edge(l, tile_id1, tile_id2)
    cp = get_curvepiece(t1, cp_id)
    curve_id = cp.curve_id
    anyon_count = cp.anyon_count

    if !is_anyon_curvepiece(t1, cp_id)
        # case 1: edge-to-edge
        ep1 = cp.endpoint1::EdgeEndpoint  # IN endpoint
        ep2 = cp.endpoint2::EdgeEndpoint  # OUT endpoint

        # if either endpoint is on the edge, we do not need to do an intersection check
        if ep1.edge == e1 || ep2.edge == e1
            ep_on_e1, ep_other = ep1.edge == e1 ? (ep1, ep2) : (ep2, ep1)
            p = ep_on_e1.pos
            _, _, sibling_p = sibling_location(l, tile_id1, e1, p)

            # add cp1 and cp2 and remove cp_id, in t1, then add cp3 in t2
            if ep_on_e1.direction == IN
                # curve ENTERS t1 at ep_on_e1
                # insert cp1's endpoints just after it, at positions p+1 and p+2, then delete cp_id,
                # shifting cp1's endpoints down so that the first IN endpoint is where ep_on_e1 was
                cp1 = insert_curvepiece!(t1, curve_id, anyon_count, e1, p + 1, e1, p + 2)
                remove_curvepiece!(t1, cp_id)
                # then insert cp2's IN endpoint at position p+2, right above cp1's OUT endpoint, and
                # put its OUT endpoint where cp_id's other endpoint was
                cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, p + 2, ep_other.edge, ep_other.pos)
                # insert cp3 to connect cp1 to cp2
                cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_p, e2, sibling_p)
            else
                # curve EXITS t1 at ep_on_e1
                # insert cp1's endpoints just after t1, at positions p+2 and p+1, analogously
                cp1 = insert_curvepiece!(t1, curve_id, anyon_count, e1, p + 1, e1, p + 1)
                remove_curvepiece!(t1, cp_id)
                cp2 = insert_curvepiece!(t1, curve_id, anyon_count, ep_other.edge, ep_other.pos, e1, p + 2)
                # insert cp3 to conect cp2 to cp1
                cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_p, e2, sibling_p + 1)
            end
            return cp1, cp2, cp3

        else
            # arbitrarily chose ep2 to be Z, and check for intersection
            # sweep clockwise from just after Z to just before pos 1 on e1 (excludes z and all e1 endpts)
            sweep1 = filter(r -> r.cp_id != cp_id,
                _EndpointRefs_between(t1, ep2.edge, ep2.pos + 1, e1, 1))
            # sweep clockwise from just past the last pos on e1 back to Z (excludes all e1 endpts and Z)
            N_e1 = num_endpoints(t1, e1)
            sweep2 = filter(r -> r.cp_id != cp_id,
                _EndpointRefs_between(t1, e1, N_e1 + 1, ep2.edge, ep2.pos))
            # a cp_id in both sweeps has one endpoint in each arc -> 'blocks' edge -> intersection
            ids1 = Set(r.cp_id for r in sweep1)
            ids2 = Set(r.cp_id for r in sweep2)
            isempty(ids1 ∩ ids2) || throw(ArgumentError(
                "stretch! of cp $cp_id in tile $tile_id1 toward $tile_id2 would cause intersecting curvepieces"))

            # insert for the no-endpoint-on-e1 case

        end

    else
        # Case 2: edge-to-anyon
        anyon_eref = get_anyon_EndpointRef(t1, cp_id)
        edge_eref  = get_partner_EndpointRef(anyon_eref)
        edge_ep    = get_endpoint(t1, edge_eref)::EdgeEndpoint

        # Sweep clockwise from e1 to find which sub-case we are in.
        # If we encounter edge_ep before the other anyon curvepiece (or there is no other), sub-case a.
        # If we encounter the other anyon curvepiece first, sub-case b.
        other_anyon_cp = get_partner_cp_id(t1, cp_id)  # nothing if only one anyon cp
        subcase_b = false
        if other_anyon_cp !== nothing
            other_anyon_eref = get_anyon_EndpointRef(t1, other_anyon_cp)
            other_edge_eref  = get_partner_EndpointRef(other_anyon_eref)
            other_edge_ep    = get_endpoint(t1, other_edge_eref)::EdgeEndpoint
            # check which comes first in clockwise sweep from e1
            arc_to_edge  = _EndpointRefs_between(t1, e1, num_endpoints(t1, e1) + 1, edge_ep.edge, edge_ep.pos)
            arc_to_other = _EndpointRefs_between(t1, e1, num_endpoints(t1, e1) + 1, other_edge_ep.edge, other_edge_ep.pos)
            subcase_b = length(arc_to_other) < length(arc_to_edge)
        end

        N_e1 = num_endpoints(t1, e1)

        if !subcase_b
            # Sub-case a: edge endpoint is on far side.
            # cp1 (edge-to-edge): inherits edge_ep, new endpoint on e1
            # cp2 (edge-to-anyon): inherits anyon endpoint, new endpoint on e1
            arc = _EndpointRefs_between(t1, edge_ep.edge, edge_ep.pos + 1, e1, N_e1 + 1)
            num = length(arc)
            x = N_e1 - num
            y = num

            remove_curvepiece!(t1, cp_id)

            cp1 = insert_curvepiece!(t1, curve_id, anyon_count, edge_ep.edge, edge_ep.pos, e1, x + 1)
            cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, x + 2, edge_ep.direction)
            cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, y + 1, e2, y + 2)
        else
            # Sub-case b: edge endpoint is on near side (just before e1).
            # cp1 (edge-to-edge): inherits edge_ep, new endpoint on e1
            # cp2 (edge-to-anyon): inherits anyon endpoint, new endpoint on e1
            # The positions on e1 are ordered differently.
            x = findfirst(r -> r == edge_eref, t1._edge_endpoints[edge_ep.edge]) # pos of other anyon edge ep on e1? first approx
            y = N_e1 + 1 - x
            remove_curvepiece!(t1, cp_id)

            cp2 = insert_curvepiece!(t1, curve_id, anyon_count, e1, x, edge_ep.direction)
            cp1 = insert_curvepiece!(t1, curve_id, anyon_count, edge_ep.edge, edge_ep.pos, e1, x + 1)
            cp3 = insert_curvepiece!(t2, curve_id, anyon_count, e2, y, e2, y + 1)
        end

        return cp1, cp2, cp3
    end
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
    # TODO
end

"""
Elementary braid swap of two directly-adjacent anyons on the same curve in neighboring tiles.
`dir=+1` is counterclockwise (CCW); `dir=-1` is clockwise (CW).

The two anyons must be directly connected — no other anyons may lie between them on the curve.
This corresponds to applying a braid group generator sigma_i or its inverse.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge.
- Both tiles have anyons on the same curve diagram.
- No other anyon lies between them along the curve.
- `dir` is `+1` or `-1`.

Returns `action = [3, curve_id, seg, dir]`, where `seg` is the segment index between the
two anyons before the swap.
"""
function swap!(l::Lattice, tile_id1::Int, tile_id2::Int, dir::Int)
    # TODO
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
