###############################################################################
# HELPERS
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
    externaltilepartner::Set{EndpointRef}=Set()
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
in the output even if they are violated by the new partition.

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
function _violated_partitions(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int;
    exclude::Set{EndpointRef}=Set{EndpointRef}()
)
    arc = Set(_erefs_between(t, edge1, pos1, edge2, pos2))
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
        isempty(vp) || throw(ArgumentError("curvepiece insertion at ($edge,$pos)→anyon violates partitions $vp"))
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
locations may shift while modifying the internal datastructures. There is one
subtlety to be noted, which is that with endpoints A, B, C on an edge, moving A
to pos 1 will do nothing, but moving A to pos 2 will also do nothing, because A
will be inserted **before** B, not after it.

If either `edge` or `pos` are nothing, the `eref` is moved to the anyon.

This function validates attempted insertions against the current state of the
tile to ensure that no move leads to intersecting curve pieces. This validation
can be omitted by passing in `allow_intersections=true`.

See `change_endpoint_location` for a breakdown of the 6 cases.

Returns `nothing`.
"""
function move_endpoint!(t::Tile, eref::EndpointRef, edge::Int, pos::Int;
    allow_intersections::Bool=false, ignore_ids::Set{Int}=Set{Int}()
)
    old_cp = t._curvepieces[eref.cp_id]
    # get curvepiece with updated endpoint for moved eref; case 6 errors here
    new_cp = change_endpoint_location(old_cp, eref.endpoint_idx, edge, pos)
    # catch case 5 and any other effective no-ops (moving eref to its own location)
    if old_cp == new_cp return end
    # validation
    if !allow_intersections
        ep_staying = old_cp.endpoints[curvepiece_partner(eref).endpoint_idx]
        ep_moving = old_cp.endpoints[eref.endpoint_idx]
        ep_target = new_cp.endpoints[eref.endpoint_idx]
        vp = Set{EndpointRef}()
        # erefs to exclude from validation
        exclude_erefs = Set{EndpointRef}()
        for cp_id in ignore_ids
            push!(exclude_erefs, EndpointRef(cp_id, 1), EndpointRef(cp_id, 2))
        end
        # cases 1 and 2
        if ep_staying isa EdgeEndpoint && ep_target isa EdgeEndpoint
            if ep_moving isa EdgeEndpoint push!(exclude_erefs, eref) end
            vp = _violated_partitions(t, ep_staying.edge, ep_staying.pos, edge, pos; exclude=exclude_erefs)
        # case 3
        elseif ep_staying isa EdgeEndpoint && ep_moving isa EdgeEndpoint
            if num_anyon_erefs(t) == 2 throw(ArgumentError("cannot have more than two anyon erefs")) end
            if has_anyon_erefs(t)
                other_ep = endpoint(t, curvepiece_partner(only(anyon_erefs(t))))
                vp = _violated_partitions(t, ep_staying.edge, ep_staying.pos, other_ep.edge, other_ep.pos)
            end
        # case 4
        elseif ep_staying isa AnyonEndpoint && ep_target isa EdgeEndpoint
            if num_anyon_erefs(t) == 2
                other_ep = endpoint(t, tile_partner(t, eref))
                vp = _violated_partitions(t, other_ep.edge, other_ep.pos, edge, pos)
            end
        end
        # if intersections exist
        isempty(vp) || throw(ArgumentError("curvepiece move violates partitions $vp"))
    end
    # track the position of the moving endpoint
    removal_pos = ep_moving.pos
    # insert new eref first (to throw any errors before mutating)
    if new_cp.endpoints[eref.endpoint_idx] isa EdgeEndpoint
        _insert_edge_eref!(t, eref, edge, pos)
        # insertion of new eref before old eref on the same edge will shift the old eref's position
        if edge == ep_moving.edge && pos <= ep_moving.pos removal_pos += 1 end
    else
        _push_anyon_eref!(t, eref)
    end
    # swap in new curvepiece so that removals update its endpoints rather than the old cp's endpoints
    t._curvepieces[eref.cp_id] = new_cp
    # remove old eref
    if old_cp.endpoints[eref.endpoint_idx] isa EdgeEndpoint
        _remove_edge_eref!(t, ep_moving.edge, removal_pos)
    else
        _remove_anyon_eref!(t, eref)
    end
    nothing
end

"""Remove the curvepiece with id `cp_id` from `t`, along with its `EndpointRef`s."""
function remove_curvepiece!(t::Tile, cp_id::Int)
    cp = curvepiece(t, cp_id)
    for (idx, ep) in enumerate(cp.endpoints)
        eref = EndpointRef(cp_id, idx)
        if ep isa EdgeEndpoint
            # re-read pos from live curvepiece: earlier removal could have shifted this
            # endpoint's position if both endpoints were on the same edge
            live_pos = (endpoint(t, eref)::EdgeEndpoint).pos
            _remove_edge_eref!(t, ep.edge, live_pos)
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

This operation is effectively the inverse of `edge_split!`

By 'merge' we mean:
- suppose `eref1` belongs to `curvepiece1`, whose other endpoint is `erefA`
- suppose `eref2` belongs to `curvepiece2`, whose other endpoint is `erefB`
- the result of the merge will be that `curvepiece1` and `curvepiece2` will
be deleted, along with their endpoints, and a new curvepiece will be created
whose endpoints are identical to `erefA` and `erefB`

Intersection validation is performed automatically, and can be omitted via the
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
    ep1::EdgeEndpoint = endpoint(t, eref1)
    ep2::EdgeEndpoint = endpoint(t, eref2)
    ep1.direction != ep2.direction || throw(ArgumentError("eref1 and eref2 must have different directions"))
    cp1.curve_id == cp2.curve_id || throw(ArgumentError("eref1 and eref2 must be on the same curve diagram"))
    cp1.anyon_count == cp2.anyon_count || throw(ArgumentError("eref1 and eref2 must have the same anyon_count"))
    # identify surviving endpoints erefA (partner of eref1) and erefB (partner of eref2)
    erefA = curvepiece_partner(eref1)
    erefB = curvepiece_partner(eref2)
    epA = endpoint(t, erefA)
    epB = endpoint(t, erefB)

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
        # if pos_in > pos_out on the same edge, need to subtract one to account for position shift
        if in_ep.edge == out_ep.edge && pos_in > pos_out pos_in -= 1 end
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
    epA, epB = cp.endpoints

    # determine e1, e2 for the validity check
    needs_check = true
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

    # final positions (fp1, fp2) of the two new erefs, paired with epA's and epB's
    # sides respectively, in the frame where both have been inserted but epA/epB
    # have not yet been removed
    positions = [pos+1, pos]
    if !needs_check || (edge, pos) == (e2_edge, e2_pos) || EndpointRef(cp_id, 1) ∈ _erefs_between(t, e2_edge, e2_pos, edge, pos)
        reverse!(positions)
    end
    fp1, fp2 = positions

    # final positions of epA's and epB's continuations in that same frame
    fpA = if epA isa EdgeEndpoint
        epA.pos + (epA.edge == edge && epA.pos >= pos ? 2 : 0) -
            (epA.edge != edge && epB isa EdgeEndpoint && epB.edge == epA.edge && epB.pos < epA.pos ? 1 : 0)
    else
        0
    end
    fpB = if epB isa EdgeEndpoint
        epB.pos + (epB.edge == edge && epB.pos >= pos ? 2 : 0) -
            (epB.edge != edge && epA isa EdgeEndpoint && epA.edge == epB.edge && epA.pos < epB.pos ? 1 : 0)
    else
        0
    end

    remove_curvepiece!(t, cp_id)

    # convert final positions to sequential insertion-time positions: insertion
    # happens in the order A, 1, 2, B, so each item's insertion-time position is
    # its final position minus the number of later-inserted items on the same
    # edge with a smaller final position
    seqpos(fp, e, later) = fp - count(it -> it[1] == e && it[2] < fp, later)
    item1, item2 = (edge, fp1), (edge, fp2)
    itemB = epB isa EdgeEndpoint ? [(epB.edge, fpB)] : []
    pos_A = epA isa EdgeEndpoint ? seqpos(fpA, epA.edge, [item1, item2, itemB...]) : 0
    pos1 = seqpos(fp1, edge, [item2, itemB...])
    pos2 = seqpos(fp2, edge, itemB)
    pos_B = fpB

    # insertions
    cp_id1 = if epA isa EdgeEndpoint
        insert_curvepiece!(t, curve_id, ac, epA.edge, pos_A, edge, pos1)
    else
        insert_curvepiece!(t, curve_id, ac, edge, pos1, epA.direction)
    end
    cp_id2 = if epB isa EdgeEndpoint
        insert_curvepiece!(t, curve_id, ac, edge, pos2, epB.edge, pos_B)
    else
        insert_curvepiece!(t, curve_id, ac, edge, pos2, epB.direction)
    end
    cp_id1, cp_id2
end

"""
Insert an anyon into the middle of the specified edge-to-edge curvepiece `cp_id`
by splitting it into two anyon-to-edge curvepieces.

This operation is effectively the inverse of `anyon_merge!`

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
    epA, epB    = cp.endpoints
    curve_id    = cp.curve_id
    anyon_count = cp.anyon_count
    # pos_A will be altered by epB's removal if epA is after it on the same edge
    pos_A = epA.pos - (epA.edge == epB.edge && epA.pos > epB.pos ? 1 : 0)
    # pos_B is expected in post-epA-insertion coords, so it doesn't need adjustment
    pos_B = epB.pos
    @show t
    remove_curvepiece!(t, cp_id)
    c1_id = insert_curvepiece!(t, curve_id, anyon_count,   epA.edge, pos_A, IN)
    c2_id = insert_curvepiece!(t, curve_id, anyon_count+1, epB.edge, pos_B, OUT)
    c1_id, c2_id
end

"""
Merges the two anyon-to-edge curvepieces in a tile together at their anyon endpoints.

This operation is effectively the inverse of `anyon_split!`

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
    erefA = curvepiece_partner(in_anyon_eref)
    erefB = curvepiece_partner(out_anyon_eref)
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
    for (idx, ep) in enumerate(cp.endpoints)
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
