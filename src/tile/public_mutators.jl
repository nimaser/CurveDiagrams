###############################################################################
# INTERSECTION VALIDATION HELPERS
###############################################################################

"""
Collects all `EndpointRef`s in the clockwise arc from `(edge1, pos1)` (inclusive)
to `(edge2, pos2)` (exclusive) on the boundary of `t`. Assumes that there is an
eref at `(edge1, pos1)`.
"""
function _erefs_between(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    arc = EndpointRef[]
    # if the arc is entirely contained within an edge
    if edge1 == edge2 && pos1 <= pos2
        for p in pos1:(pos2 - 1)
            push!(arc, edge_eref(t, edge1, p))
        end
    else
        # get endpoints on the remainder of edge1
        for p in pos1:num_edge_erefs(t, edge1)
            push!(arc, edge_eref(t, edge1, p))
        end
        # get all endpoints on intervening edges between edge1 and edge2
        e = next_edge(t, edge1)
        while e != edge2
            for p in 1:num_edge_erefs(t, e)
                push!(arc, edge_eref(t, e, p))
            end
            e = next_edge(t, e)
        end
        # get endpoints on the first part of edge2
        for p in 1:(pos2 - 1)
            push!(arc, edge_eref(t, edge2, p))
        end
    end
    arc
end

"""
Return a list of all `EndpointRef`s in `erefs` whose tile partners in `t`, if
they exist, are not in `erefs`.

Each element of `erefs` must refer to an `EdgeEndpoint`.
"""
function _erefs_with_external_tile_partner(t::Tile, erefs::Set{EndpointRef})
    externaltilepartner = Set()::Set{EndpointRef}
    for e in erefs
        tp = tile_partner(t, e, EdgeEndpoint)
        if tp !== nothing && tp ∉ erefs
            push!(externaltilepartner, e)
        end
    end
    externaltilepartner
end

"""
Return the set of partitions in `t` which would be violated if a new partition
with endpoints at `(edge1, pos1)` and `(edge2, pos2)` was created. Partitions
formed using an eref in `exclude` are not considered, meaning they will not be
in the output even if they are violated by the new partition. `exclude` must
only contain erefs to `EdgeEndpoint`s.

A partition P in a tile is a pair of edge endpoints which are tile partners. Let
- P1 and P2 be the two endpoints respectively
- PA1 be the set of endpoints contained in the clockwise walk from P1 to P2
- PA2 be the set of endpoints contained in the counterclockwise walk from P1 to P2
- PC be the set of curvepieces which contain P1 and/or P2

Because tile partners are unique, P can be defined by either P1 or P2 alone.

PA1 and PA2 are the 'clockwise arc' and 'counterclockwise arc' of the partition
respectively. The sets PA1, PA2, and {A, B} partition the set of edge erefs in
the tile, hence the name.

If P1 and P2 are on the same boundary curvepiece, PC will just contain it. If they
are not, then by virtue of being tile partners, they must be on the two central
curvepieces in the tile, which will both be in PC. In either case, the curvepieces
in PC split the area of the tile into two parts.

A partition P is violated by another partition Q if the endpoints Q1 and Q2 of Q
are in different arcs of P. This is equivalent to saying that the curvepieces in
PC intersect the curvepieces in QC, which can be verified easily by drawing.

Therefore, this function detects, given the prospective endpoint locations of
either a boundary curvepiece or a pair of central curvepieces, whether inserting
those curvepieces will cause any curvepiece intersections with curvepieces already
in the tile.

Returns a set of erefs which each define one existing partition which would be
violated by the proposed new partition.
"""
function _violated_partitions(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int; exclude=Set()::Set{EndpointRef})
    arc = _erefs_between(t, edge1, pos1, edge2, pos2)
    full_exclude = copy(exclude)
    for e in exclude
        tp = tile_partner(t, e, EdgeEndpoint)
        if tp !== nothing push!(full_exclude, tp) end
    end
    filter!(eref -> eref ∉ full_exclude, arc)
    _erefs_with_external_tile_partner(t, arc)
end

###############################################################################
# ONE-CURVEPIECE OPERATIONS: INSERT, MOVE, REMOVE
###############################################################################

"""
Insert a boundary curvepiece into `t`. `(edge1, pos1)` is where the IN endpoint
is inserted and `(edge2, pos2)` is where the OUT endpoint is inserted. `pos2` is
relative to the state of the tile *after* the IN endpoint has been inserted at
`pos1`. Callers must account for this when both endpoints share an edge: for
example, `pos1 = 1, pos2 = 1` gives OUT-then-IN (OUT is inserted at pos 1 after
IN has already occupied pos 1, pushing IN to pos 2), while `pos1 = 1, pos2 = 2`
gives IN-then-OUT. For cross-edge insertions, `pos2` is equivalent to the pre-
insertion position since inserting on `edge1` does not affect erefs on `edge2`.

This function validates attempted insertions against the current state of the
tile to ensure that no insertion leads to intersecting curve pieces. This
validation can be omitted by passing in `allow_intersections=true`.

Returns the `cp_id` of the created curvepiece.
"""
function insert_curvepiece!(t::Tile, curve_id::Int, anyon_count::Int,
    edge1::Int, pos1::Int,
    edge2::Int, pos2::Int;
    allow_intersections::Bool=false
)
    # validation
    if !allow_intersections
        # pos2 is in post-pos1-insertion coordinates; convert to pre-insertion for validation
        pos2_pre = (edge1 == edge2 && pos2 > pos1) ? pos2 - 1 : pos2
        vp = _violated_partitions(t, edge1, pos1, edge2, pos2_pre)
        isempty(vp) || throw(ArgumentError("curvepiece insertion at ($edge1,$pos1)→($edge2,$pos2) violates partitions $vp"))
    end
    # insert curvepiece
    cp_id = _allocate_cp_id!(t)
    cp = Curvepiece(curve_id, anyon_count, EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2))
    t._curvepieces[cp_id] = cp
    _insert_edge_eref!(t, EndpointRef(cp_id, 1), edge1, pos1)
    _insert_edge_eref!(t, EndpointRef(cp_id, 2), edge2, pos2)
    cp_id
end

"""
Insert a central curvepiece into `t`. `(edge, pos)` is where the edge endpoint
will be located. `direction` will apply to both endpoints and will control the
direction of the inserted curvepiece. An error will be thrown if an insertion
would lead to either of the following:
- more than two central curvepieces in `t`
- more than one incoming or outgoing central curvepiece in `t`

This function validates attempted insertions against the current state of the
tile to ensure that no insertion leads to intersecting curve pieces. This
validation can be omitted by passing in `allow_intersections=true`.

Returns the `cp_id` of the created curvepiece.
"""
function insert_curvepiece!(t::Tile, curve_id::Int, anyon_count::Int,
    edge::Int, pos::Int, direction::EndpointDirection;
    allow_intersections::Bool=false
)
    # validation
    if num_anyon_erefs(t) == 2
        throw(ArgumentError("cannot have more than two central curvepieces in a tile"))
    end
    if num_anyon_erefs(t) == 1 && !allow_intersections
        existing_edge_ep = endpoint(t, curvepiece_partner(only(anyon_erefs(t))))
        vp = _violated_partitions(t, edge, pos, existing_edge_ep.edge, existing_edge_ep.pos)
        isempty(vp) throw(ArgumentError("curvepiece insertion at ($edge,$pos)→anyon violates partitions $vp"))
    end
    cp_id = _allocate_cp_id!(t)
    # correct ordering occurs on construction
    cp = Curvepiece(curve_id, anyon_count, EdgeEndpoint(direction, edge, pos), AnyonEndpoint(direction))
    t._curvepieces[cp_id] = cp
    # extract ordering from cp, then use it to construct endpointrefs
    edge_which = cp.endpoints[1] isa EdgeEndpoint ? 1 : 2
    anyon_which = 3 - edge_which
    _insert_edge_eref!(t, EndpointRef(cp_id, edge_which), edge, pos)
    _push_anyon_eref!(t, EndpointRef(cp_id, anyon_which))
    cp_id
end

"""
Moves `eref` to a new location, `(edge, pos)`, without changing the direction or
any other curvepiece data. `pos` is relative to the internal state at the time
of the function call, meaning the caller should not 'adjust' for the fact that
locations may shift while modifying the internal datastructures.

If either `edge` or `pos` are nothing, the `eref` is moved to the anyon.

This function validates attempted insertions against the current state of the
tile to ensure that no move leads to intersecting curve pieces. This validation
can be omitted by passing in `allow_intersections=true`.

There are 6 total cases which can be characterized according to the types (A for
AnyonEndpoint and E for EdgeEndpoint) of the (staying, moving -> target) endpoints:
1. E, E -> E
2. E, A -> E
3. E, E -> A
4. A, E -> E
5. E, A -> A
6. A, E -> A

Cases 1 and 2 result in a boundary curvepiece, while the others result in central
curvepieces. Cases 3 and 4 result in a new central curvepiece, while case 5 is
always a no-op, and case 6 is always illegal. We only do validation of the first
four cases, and let cases 5 and 6 fall through to, and be handled in, `_move_eref!`.

Returns `nothing`.
"""
function move_curvepiece!(t::Tile, eref::EndpointRef, edge::Int, pos::Int; allow_intersections::Bool=false)
    # validation
    if !allow_intersections
        ep_moving = endpoint(t, eref)
        ep_staying = endpoint(t, curvepiece_partner(eref))
        target = edge === nothing || pos === nothing ? AnyonEndpoint : EdgeEndpoint
        vp = Set::Set{EndpointRef}
        # cases 1 and 2
        if ep_staying isa EdgeEndpoint && target == EdgeEndpoint
            excludeset = ep_moving isa EdgeEndpoint ? Set(eref) : Set()
            vp = _violated_partitions(t, ep_staying.edge, ep_staying.pos, edge, pos; exclude=excludeset)
        # case 3
        elseif ep_staying isa EdgeEndpoint && ep_moving isa EdgeEndpoint
            if num_anyon_erefs(t) == 2 throw(ArgumentError("cannot have more than two anyon erefs")) end
            if has_anyon_erefs(t)
                other_ep = endpoint(t, curvepiece_partner(only(anyon_erefs(t))))
                vp = _violated_partitions(t, ep_staying.edge, ep_staying.pos, other_ep.edge, other_ep.pos)
            end
        # case 4
        elseif ep_staying isa AnyonEndpoint && target == EdgeEndpoint
            if num_anyon_erefs(t) == 2
                other_ep = endpoint(t, tile_partner(t, eref))
                vp = _violated_partitions(t, other_ep.edge, other_ep.pos, edge, pos)
            end
        end
        # if intersections exist
        isempty(vp) || throw(ArgumentError("curvepiece move violates partitions $vp"))
    end
    _move_eref!(t, eref, edge, pos)
end

"""Remove the curvepiece with id `cp_id` from `t`, along with its `EndpointRef`s."""
function remove_curvepiece!(t::Tile, cp_id::Int)
    cp = curvepiece(t, cp_id)
    for (idx, ep) in enumerate((cp.endpoint1, cp.endpoint2))
        eref = EndpointRef(cp_id, idx)
        if ep isa EdgeEndpoint
            _remove_edge_eref!(t, ep.edge, ep.pos)
        else
            _remove_anyon_eref!(t, eref)
        end
    end
    delete!(t._curvepieces, cp_id)
    nothing
end

###############################################################################
# TWO-CURVEPIECE OPERATIONS; MERGE, SPLIT
###############################################################################

"""
Merge two curvepieces in `t` at the specified edge endpoints `eref1` and `eref2`.
Return the curvepiece id of the resulting merged curvepiece.

This operation is effectively the inverse of `split_curvepiece!`

By 'merge' we mean:
- suppose `eref1` belongs to `curvepiece1`, whose other endpoint is `erefA`
- suppose `eref2` belongs to `curvepiece2`, whose other endpoint is `erefB`
- the result of the merge will be that `curvepiece1` and `curvepiece2` will
be deleted, along with their endpoints, and a new curvepiece will be created
whose endpoints are identical to `erefA` and `erefB`

The validation performed when a new curvepiece is created can be omitted via the
`allow_intersections` flag.

`eref1` and `eref2` must be edge endpoints with different directions located
on different curvepieces. These curvepieces must be on the same curve diagram.
All of these conditions are required to result in a valid curvepiece, and
violating them will result in an error.

This function is intended for use as a subroutine when removing U-turns and
trivial bends in lattices.
"""
function edge_merge!(t::Tile, eref1::EndpointRef, eref2::EndpointRef;
                            allow_intersections::Bool=false)
    cp1 = curvepiece(t, eref1.cp_id)
    cp2 = curvepiece(t, eref2.cp_id)
    # validate
    eref1.cp_id != eref2.cp_id || throw(ArgumentError("eref1 and eref2 must be on different curvepieces"))
    ep1::EdgeEndpoint = endpoint(cp1, eref1)
    ep2::EdgeEndpoint = endpoint(cp2, eref2)
    ep1.direction != ep2.direction || throw(ArgumentError("eref1 and eref2 must have different directions"))
    cp1.curve_id == cp2.curve_id || throw(ArgumentError("eref1 and eref2 must be on the same curve diagram"))
    cp1.anyon_count == cp2.anyon_count || throw(ArgumentError("eref1 and eref2 must have the same anyon_count"))
    # identify surviving endpoints erefA (partner of eref1) and erefB (partner of eref2)
    erefA = cp_partner(eref1)
    erefB = cp_partner(eref2)
    epA = endpoint(cp1, erefA)
    epB = endpoint(cp2, erefB)
    if epA isa EdgeEndpoint && epB isa EdgeEndpoint
        # determine which surviving endpoint (of erefA and erefB) is IN and which is OUT
        in_eref,  in_ep  = epA.direction == IN  ? (erefA, epA) : (erefB, epB)
        out_eref, out_ep = epA.direction == OUT ? (erefA, epA) : (erefB, epB)
        # insertion will insert the IN endpoint first, then the OUT endpoint in shifted coordinates.
        # therefore, we record the position of the OUT endpoint, remove that curvepiece, then
        # record the position of the IN endpoint, so that position shifts work out correctly
        # when erefA and erefB are on the same edge; on different edges, the order doesn't matter
        pos_out = out_ep.pos
        remove_curvepiece!(t, out_eref.cp_id)
        pos_in = (endpoint(t, in_eref)::EdgeEndpoint).pos
        remove_curvepiece!(t, in_eref.cp_id)
        insert_curvepiece!(t, cp1.curve_id, cp1.anyon_count,
            in_ep.edge, pos_in, out_ep.edge, pos_out; allow_intersections)
    else
        # determine which surviving endpoint (of erefA and erefB) is an anyon endpoint
        edge_ep,  edge_ref  = epA isa EdgeEndpoint  ? (epA, erefA) : (epB, erefB)
        anyon_ep, anyon_ref = epA isa AnyonEndpoint ? (epA, erefA) : (epB, erefB)
        # for similar reasons as above, remove the anyon piece first, then re-read edge pos
        remove_curvepiece!(t, anyon_ref.cp_id)
        pos_edge = (endpoint(t, edge_ref)::EdgeEndpoint).pos
        remove_curvepiece!(t, edge_ref.cp_id)
        insert_curvepiece!(t, cp1.curve_id, cp1.anyon_count,
            edge_ep.edge, pos_edge, anyon_ep.direction; allow_intersections)
    end
end

"""
Split the curvepiece specified by `cp_id` into two at position `pos` on edge
`edge` in `t`. Return the curvepiece ids of the resulting two curvepieces.

This operation is effectively the inverse of `merge_curvepieces!`

By 'split' we mean that if the curvepiece has (in traversal order) two endpoints
`erefA` and `erefB`:
- the original curvepiece is removed
- two new edge endpoints, `eref1` and `eref2`, are created
- two new curvepieces are created, going from `erefA` to `eref1` and `erefB` to
`eref2`

`eref1` will be located at `pos` or `pos+1` on `edge`, with `eref2` at the other
location. There are two ways to do this assignment. In this case that  `cp_id`
is the only anyon-to-edge curvepiece in `t`, either assignment will be valid, so
we can arbitrarily choose the one where `pos` contains the outgoing eref. In all
other cases, only one of the assignments will be valid.

To determine which is valid, suppose `cp_id` is:
- an edge-to-edge curvepiece. Then let e1 and e2 be `erefA` and `erefB`.
- one of two anyon-to-edge curvepieces in the tile. Then let e1 and e2 be (in
traversal order) their collective two edge endpoints (they have one each).

If a clockwise traversal of edge endpoints starting from `pos` on `edge` encounters
e1 before it encounters e2, then `erefA` should be at `pos+1`. Otherwise, it should
be at `pos`. This ensures that on a traversal of the endpoints, the encounter
order is e1, `erefA`, `erefB`, e2, which ensures that there are no intersections.
"""
function edge_split!(t::Tile, cp_id::Int, edge::Int, pos::Int)
    cp = curvepiece(t, cp_id)
    curve_id = cp.curve_id
    ac = cp.anyon_count
    epA = cp.endpoint1
    epB = cp.endpoint2

    # determine e1, e2 for the validity check
    needs_check = true
    e1_edge, e1_pos = 0, 0
    e2_edge, e2_pos = 0, 0
    if epA isa EdgeEndpoint && epB isa EdgeEndpoint
        e1_edge, e1_pos = epA.edge, epA.pos
        e2_edge, e2_pos = epB.edge, epB.pos
    elseif num_anyon_erefs(t) == 2
        if epA isa EdgeEndpoint
            e1_edge, e1_pos = epA.edge, epA.pos
            e2_ep = endpoint(t, tile_partner(t, EndpointRef(cp_id, 1), EdgeEndpoint))::EdgeEndpoint
            e2_edge, e2_pos = e2_ep.edge, e2_ep.pos
        else
            e2_edge, e2_pos = epB.edge, epB.pos
            e1_ep = endpoint(t, tile_partner(t, EndpointRef(cp_id, 2), EdgeEndpoint))::EdgeEndpoint
            e1_edge, e1_pos = e1_ep.edge, e1_ep.pos
        end
    else
        needs_check = false
    end

    # determine pos_A (erefA's new endpoint) and pos_B
    pos_A, pos_B = if !needs_check ||
                      EndpointRef(cp_id, 1) ∈ erefs_between(t, edge, pos, e2_edge, e2_pos)
        pos, pos + 1
    else
        pos + 1, pos
    end

    # adjust for position shifts caused by removing C
    for ep in (epA, epB)
        ep isa EdgeEndpoint || continue
        ep.edge == edge || continue
        ep.pos < pos_A && (pos_A -= 1)
        ep.pos < pos_B && (pos_B -= 1)
    end

    remove_curvepiece!(t, cp_id)

    cp_id1 = if epA isa EdgeEndpoint
        insert_curvepiece!(t, curve_id, ac, epA.edge, epA.pos, edge, pos_A; allow_intersections=true)
    else
        insert_curvepiece!(t, curve_id, ac, edge, pos_A, epA.direction; allow_intersections=true)
    end
    cp_id2 = if epB isa EdgeEndpoint
        insert_curvepiece!(t, curve_id, ac, edge, pos_B, epB.edge, epB.pos; allow_intersections=true)
    else
        insert_curvepiece!(t, curve_id, ac, edge, pos_B, epB.direction; allow_intersections=true)
    end
    cp_id1, cp_id2
end

"""
Insert an anyon into the middle of the specified edge-to-edge curvepiece `cp_id`
by splitting it into two anyon-to-edge curvepieces.

This operation is effectively the inverse of `remove_anyon!`

In particular, if `erefA` and `erefB` are the endpoints of `cp_id`, in traversal
order, then:
- `cp_id` will be removed
- an edge-to-anyon curvepiece C1 will be inserted from `erefA` to the anyon
- an anyon-to-edge curvepiece C2 will be inserted from the anyon to `erefB`

The `anyon_count` of C1 will match that of `cp_id`, while that of C2 will be one
greater than that.

An error will be thrown if `t` already has any anyon endpoints.

Returns the curvepiece ids of the two newly created curvepieces.
"""
function anyon_split!(t::Tile, cp_id::Int)
    num_anyon_erefs(t) == 0 || throw(ArgumentError("tile already has anyon endpoints"))
    cp          = curvepiece(t, cp_id)
    epA, epB    = cp.endpoint1::EdgeEndpoint, cp.endpoint2::EdgeEndpoint
    curve_id    = cp.curve_id
    anyon_count = cp.anyon_count
    # pos_A will be altered by epB's removal if epA is after it on the same edge
    pos_A = epA.pos - (epA.edge == epB.edge && epA.pos > epB.pos ? 1 : 0)
    # pos_B is expected in post-epA-insertion coords, so it doesn't need adjustment
    pos_B = epB.pos
    remove_curvepiece!(t, cp_id)
    c1_id = insert_curvepiece!(t, curve_id, anyon_count,   epA.edge, pos_A, IN)
    c2_id = insert_curvepiece!(t, curve_id, anyon_count+1, epB.edge, pos_B, OUT)
    c1_id, c2_id
end

"""
Merges the two anyon-to-edge curvepieces in a tile together at their anyon endpoints.

This operation is effectively the inverse of `remove_anyon!`

In particular, if `erefA` and `erefB` are the edge endpoints of the two anyon-to-edge
curvepieces in traversal order, and `eref1` and `eref2` are the two anyon endpoints,
then the result of this function will be:
- the two anyon-to-edge curvpieces are removed
- a new curvepiece from `erefA` to `erefB` is created, with an anyon count value equal
to the lower of the two original curvepieces' values

Returns the curvepiece id of the newly created curvepiece. Throws an error if there are
not two anyon-to-edge curvepieces in the tile.
"""
function anyon_merge!(t::Tile)
    num_anyon_erefs(t) == 2 || throw(ArgumentError("tile must have exactly two anyon-to-edge curvepieces"))
    arefs = anyon_erefs(t)
    # determine which curvepiece is first
    out_anyon_eref = endpoint(t, arefs[1]).direction == OUT ? arefs[1] : arefs[2]
    in_anyon_eref  = out_anyon_eref === arefs[1] ? arefs[2] : arefs[1]
    erefA = cp_partner(in_anyon_eref)
    erefB = cp_partner(out_anyon_eref)
    curve_id    = curvepiece(t, erefA.cp_id).curve_id
    anyon_count = curvepiece(t, erefA.cp_id).anyon_count
    epB = endpoint(t, erefB)::EdgeEndpoint
    pos_B = epB.pos
    remove_curvepiece!(t, erefB.cp_id)
    epA = endpoint(t, erefA)::EdgeEndpoint
    pos_in  = epA.pos
    remove_curvepiece!(t, erefA.cp_id)
    insert_curvepiece!(t, curve_id, anyon_count, epA.edge, pos_in, epB.edge, pos_B)
end

###############################################################################
# MISC
###############################################################################

"""
Update the curve-related metadata for a curvepiece after e.g. a merge or grow
operation.
"""
function set_curvepiece_metadata!(t::Tile, cp_id::Int, curve_id::Int, anyon_count::Int)
    cp = curvepiece(t, cp_id)
    t._curvepieces[cp_id] = Curvepiece(curve_id, anyon_count, cp.endpoints...)
    nothing
end

"""
Reverse the traversal direction of curvepiece `cp_id` in `t` by inverting both
endpoints' directions. Reversing always results in the endpoints of the curvepiece
being stored in the opposite order in the curvepiece, requiring updating both
`EndpointRef`s for this curvepiece accordingly.

Does not modify `curve_id` or `anyon_count` of the curvepiece.
"""
function reverse_curvepiece!(t::Tile, cp_id::Int)
    # flipper functions
    flip(ep::EdgeEndpoint)  = EdgeEndpoint(ep.direction == IN ? OUT : IN, ep.edge, ep.pos)
    flip(ep::AnyonEndpoint) = AnyonEndpoint(ep.direction == IN ? OUT : IN)
    # flip endpoint directions in the curvepiece, reordering happens automatically
    cp = curvepiece(t, cp_id)
    new_cp = Curvepiece(cp.curve_id, cp.anyon_count, flip(cp.endpoints[1]), flip(cp.endpoints[2]))
    t._curvepieces[cp_id] = new_cp
    # flip erefs
    for (idx, ep) in cp.endpoints
        old_eref = EndpointRef(cp_id, idx)
        new_eref = curvepiece_partner(old_eref)
        if ep isa EdgeEndpoint
            t._edge_erefs[ep.edge][ep.pos] = new_eref
        else
            _remove_anyon_eref!(t, old_eref)
            _push_anyon_eref!(t, new_eref)
        end
    end
    nothing
end
