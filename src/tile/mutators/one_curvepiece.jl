################################################################################
# HELPERS
################################################################################

"""
Return the set of `EndpointRef`s which reference `EdgeEndpoint`s on a `Curvepiece`
in `cp_ids`.
"""
function _edge_erefs_from_cp_ids(t::Tile, cp_ids::Set{Int})
    erefs = Set{EndpointRef}()
    foreach(cp_id -> push!(erefs, EndpointRef(cp_id, 1), EndpointRef(cp_id, 2)), cp_ids)
    setdiff(erefs, anyon_erefs(t))
end

################################################################################
# SET CURVEPIECE METADATA
################################################################################

"""
    set_curvepiece_metadata!(t::Tile, cp_id::Int, curve_id::Int, anyon_count::Int)

Set the `curve_id` and `anyon_count` of curvepiece `cp_id` in `t`.
"""
function set_curvepiece_metadata!(t::Tile, cp_id::Int, curve_id::Int, anyon_count::Int)
    cp = curvepiece(t, cp_id)
    t._curvepieces[cp_id] = Curvepiece(curve_id, anyon_count, cp.endpoints...)
    nothing
end

################################################################################
# REVERSE
################################################################################

"""
    reverse_curvepiece!(t::Tile, cp_id::Int)

Reverse the traversal direction of curvepiece `cp_id` in `t` by inverting both
of its endpoints' `EndpointDirection`s.

This always results in the endpoints of the `Curvepiece` being stored in the
opposite order compared to their original ordering, which requires updating both
`EndpointRef`s for the `Curvepiece` accordingly.

Does not modify `curve_id` or `anyon_count` of the curvepiece.
"""
function reverse_curvepiece!(t::Tile, cp_id::Int)
    # reverse Curvepiece struct
    cp = curvepiece(t, cp_id)
    t._curvepieces[cp_id] = reverse(cp)
    # swap erefs
    for (idx, ep) in enumerate(cp.endpoints)
        old_eref = EndpointRef(cp_id, idx)
        new_eref = curvepiece_partner(old_eref)
        if ep isa EdgeEndpoint
            t._edge_erefs[ep.edge][ep.pos] = new_eref
        else
            _remove_anyon_eref!(t, old_eref)
            _insert_anyon_eref!(t, new_eref)
        end
    end
    nothing
end

################################################################################
# BOUNDARY INSERT
################################################################################

"""
Insert a boundary `Curvepiece` with provided `curve_id` and `anyon_count` into
`t`. The curvepiece's two endpoints, A, and B, have directions `directionA` and
`directionB` respectively.

Endpoint A is inserted first, at `(edgeA, posA)`, after which endpoint B is
inserted at `(edgeB, posB)`. **IMPORTANT**: the location of endpoint B should be
provided relative to the state of the tile **after** endpoint A is inserted. In
practice this means that
- if A and B are on different edges, they end up at the locations provided
- if A and B are on the same edge, the insertion of one endpoint with a lower
position than the other will shift the latter endpoint/its insertion position

Return the `cp_id` of the created curvepiece.

Throw an error if
- the proposed curvepiece is invalid.
- the proposed insertion would lead to intersecting curvepieces -- omit this
check entirely by passing `check_intersections=false`, or exempt a specific
curvepiece from this check by including its id in `ignore_ids`.
"""
function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    directionA::EndpointDirection, edgeA::Int, posA::Int,
    directionB::EndpointDirection, edgeB::Int, posB::Int;
    check_intersections::Bool=true,
    ignore_ids::Set{Int}=Set{Int}(),
)
    if check_intersections
        # convert posB to pre-posA-insertion coordinates for validation
        posB_pre = (edgeA == edgeB && posB > posA) ? posB - 1 : posB
        vp = violated_partitions(t, edgeA, posA, edgeB, posB_pre; exclude=_edge_erefs_from_cp_ids(t, ignore_ids))
        isempty(vp) || throw(ArgumentError("boundary curvepiece insertion at ($edgeA,$posA)→($edgeB,$posB) violates partitions $vp"))
    end
    # make curvepiece, validation and correct endpoint ordering occurs on construction
    epA = EdgeEndpoint(directionA, edgeA, posA)
    epB = EdgeEndpoint(directionB, edgeB, posB)
    cp = Curvepiece(curve_id, anyon_count, epA, epB)
    # insert curvepiece
    cp_id = _allocate_cp_id!(t)
    t._curvepieces[cp_id] = cp
    _insert_edge_eref!(t, EndpointRef(cp_id, endpoint_idx(cp, epA)), edgeA, posA)
    _insert_edge_eref!(t, EndpointRef(cp_id, endpoint_idx(cp, epB)), edgeB, posB) # if epA shifted updated here
    cp_id
end

"""
Insert a boundary `Curvepiece` with provided `curve_id` and `anyon_count` into
`t`. The curvepiece's two endpoints, A, and B, have directions `directionA` and
`directionB` respectively.

Endpoint A is inserted first, followed by endpoint B. Endpoint insertions are
relative, meaning each endpoint is inserted either directly counterclockwise or
clockwise of reference erefs `ref_erefA`/`ref_erefB`. The relative direction can
be chosen with the `offsetA`/`offsetB` parameters, which can take values of `:ccw`
and `:cw`. **IMPORTANT** the insertion location of endpoint B will be relative to
the location of `ref_erefB` **after** endpoint A has been inserted.

Return the `cp_id` of the created curvepiece.

Throw an error if
- the proposed curvepiece is invalid.
- the proposed insertion would lead to intersecting curvepieces -- omit this
check entirely by passing `check_intersections=false`, or exempt a specific
curvepiece from this check by including its id in `ignore_ids`.
- the offset parameters are not one of `(:ccw, :cw)`.
- the reference erefs do not reference `EdgeEndpoint`s.
"""
function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    directionA::EndpointDirection, offsetA::Symbol, ref_erefA::EndpointRef,
    directionB::EndpointDirection, offsetB::Symbol, ref_erefB::EndpointRef;
    check_intersections::Bool=true,
    ignore_ids::Set{Int}=Set{Int}(),
)
    # convert offset symbols to numbers
    offsetA ∈ (:ccw, :cw) || throw(ArgumentError("offsetA must be :ccw or :cw, got $offsetA"))
    offsetB ∈ (:ccw, :cw) || throw(ArgumentError("offsetB must be :ccw or :cw, got $offsetB"))
    pos_offsetA = offsetA == :ccw ? 0 : 1
    pos_offsetB = offsetB == :ccw ? 0 : 1
    # get endpoint locations from reference endpoint and offset
    ref_epA = endpoint(t, ref_erefA)::EdgeEndpoint
    ref_epB = endpoint(t, ref_erefB)::EdgeEndpoint
    edgeA = ref_epA.edge
    edgeB = ref_epB.edge
    posA = ref_epA.pos + pos_offsetA
    posB = ref_epB.pos + pos_offsetB
    # calculate potential shift to insertion position for B
    posB = (edgeA == edgeB && posB > posA) ? posB + 1 : posB
    # dispatch to position-based insertion method
    insert_curvepiece!(
        t, curve_id, anyon_count,
        directionA, edgeA, posA,
        directionB, edgeB, posB;
        check_intersections=check_intersections,
        ignore_ids=ignore_ids,
    )
end

################################################################################
# CENTRAL INSERT
################################################################################

"""
Insert a central `Curvepiece` with provided `curve_id` and `anyon_count` into
`t`. The curvepiece's `EdgeEndpoint` will have direction `direction`, which will
be shared with the `AnyonEndpoint` and thus determine the overall direction of
the curvepiece.

The `EdgeEndpoint` will be inserted at `(edge, pos)`.

Return the `cp_id` of the created curvepiece.

Throw an error if
- the proposed insertion would lead to intersecting curvepieces -- omit this
check entirely by passing `check_intersections=false`.
- the proposed insertion would lead to more than two central curvepieces in `t`
- the proposed insertion would lead to more than one incoming or outgoing
central curvepiece in `t`

Exempt a specific curvepiece from these checks by including its id in `ignore_ids`.
"""
function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    direction::EndpointDirection, edge::Int, pos::Int;
    check_intersections::Bool=true,
    ignore_ids::Set{Int}=Set{Int}(),
)
    # check for number of central curvepieces
    unignored_anyon_ids = filter(eref -> eref.cp_id ∉ ignore_ids, collect(anyon_erefs(t)))
    length(unignored_anyon_ids) == 2 && throw(ArgumentError("cannot insert another central curvepiece"))
    # check for intersections
    if check_intersections && length(unignored_anyon_ids) == 1
        existing_edge_ep = endpoint(t, curvepiece_partner(only(unignored_anyon_ids)))
        vp = violated_partitions(t, edge, pos, existing_edge_ep.edge, existing_edge_ep.pos; exclude=_edge_erefs_from_cp_ids(t, ignore_ids))
        isempty(vp) || throw(ArgumentError("central curvepiece insertion at ($edge,$pos) violates partitions $vp"))
    end
    # make curvepiece, validation and correct endpoint ordering occurs on construction
    epE = EdgeEndpoint(direction, edge, pos)
    epA = AnyonEndpoint(direction)
    cp = Curvepiece(curve_id, anyon_count, epE, epA)
    # insert curvepiece
    cp_id = _allocate_cp_id!(t)
    t._curvepieces[cp_id] = cp
    _insert_edge_eref!(t, EndpointRef(cp_id, endpoint_idx(cp, epE)), edge, pos)
    _insert_anyon_eref!(t, EndpointRef(cp_id, endpoint_idx(cp, epA)))
    cp_id
end

"""
Insert a central `Curvepiece` with provided `curve_id` and `anyon_count` into
`t`. The curvepiece's `EdgeEndpoint` will have direction `direction`, which will
be shared with the `AnyonEndpoint` and thus determine the overall direction of
the curvepiece.

The `EdgeEndpoint` will be inserted relative to `ref_eref`, either directly
counterclockwise or clockwise of it, depending on whether `offset` is `:ccw` or
`:cw` respectively.

Return the `cp_id` of the created curvepiece.

Throw an error if
- the proposed insertion would lead to intersecting curvepieces -- omit this
check entirely by passing `check_intersections=false`.
- the proposed insertion would lead to more than two central curvepieces in `t`
- the proposed insertion would lead to more than one incoming or outgoing
central curvepiece in `t`

Exempt a specific curvepiece from these checks by including its id in `ignore_ids`.

Throw an error if
- the offset parameter is not `(:ccw, :cw)`.
- the reference eref does not reference an `EdgeEndpoint`.
"""
function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    direction::EndpointDirection, offset::Symbol, ref_eref::EndpointRef;
    check_intersections::Bool=true,
    ignore_ids::Set{Int}=Set{Int}(),
)
    # convert offset symbol to number
    offset ∈ (:ccw, :cw) || throw(ArgumentError("offset must be :ccw or :cw, got $offset"))
    pos_offset = offset == :ccw ? 0 : 1
    # get endpoint location from reference endpoint and offset
    ref_ep = endpoint(t, ref_eref)::EdgeEndpoint
    edge = ref_ep.edge
    pos = ref_ep.pos + pos_offset
    # dispatch to position-based insertion method
    insert_curvepiece!(t, curve_id, anyon_count,
        direction, edge, pos;
        check_intersections=check_intersections,
        ignore_ids=ignore_ids,
    )
end

################################################################################
# REMOVE
################################################################################

"""
Remove the curvepiece with id `cp_id` from `t`, along with its `EndpointRef`s.
"""
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

################################################################################
# MOVE
################################################################################

"""
Move `eref` to a new location, `(edge, pos)`, without changing the direction or
any other curvepiece data. `pos` is relative to the internal state at the time
of the function call, meaning the caller should not 'adjust' for the fact that
locations may shift while modifying the internal datastructures.

One subtlety to be noted is that if there are endpoints A, B on an edge, then
moving A to pos 1 will do nothing, but moving A to pos 2 will *also* do nothing,
because A will be inserted **before** B at pos 2, not after it.

If either `edge` or `pos` are nothing, the `eref` is moved to the anyon.

Throw an error if the proposed move would lead to intersecting curvepieces. Omit
this validation by passing in `check_intersections=false`.

Throw an error if a move would lead to either of the following:
- more than two central curvepieces in `t`
- more than one incoming or outgoing central curvepiece in `t`

Curvepieces whose ids are in `ignore_ids` will not trigger errors.

See `change_endpoint_location` for a breakdown of the six possible move cases.

Returns `nothing`.
"""
function move_endpoint!(
    t::Tile, eref::EndpointRef, edge::Int, pos::Int;
    check_intersections::Bool=true, ignore_ids::Set{Int}=Set{Int}(),
)
    old_cp = curvepiece(t, eref.cp_id)
    # get curvepiece with updated endpoint for moved eref; case 6 errors here
    new_cp = change_endpoint_location(old_cp, eref.endpoint_idx, edge, pos)
    # catch case 5 and any other effective no-ops (moving eref to its own location)
    old_cp == new_cp && return
    # validation
    if check_intersections
        ep_staying = old_cp.endpoints[curvepiece_partner(eref).endpoint_idx]
        ep_moving = old_cp.endpoints[eref.endpoint_idx]
        ep_target = new_cp.endpoints[eref.endpoint_idx]
        # partitions violated by this move, ignoring exclude_erefs
        vp = Set{EndpointRef}()
        # cases 1 and 2
        if ep_staying isa EdgeEndpoint && ep_target isa EdgeEndpoint
            exclude_erefs = _edge_erefs_from_cp_ids(t, ignore_ids)
            ep_moving isa EdgeEndpoint && push!(exclude_erefs, eref)
            vp = violated_partitions(t, ep_staying.edge, ep_staying.pos, edge, pos; exclude=exclude_erefs)
            # case 3
        elseif ep_staying isa EdgeEndpoint && ep_moving isa EdgeEndpoint
            num_anyon_erefs(t) != 2 || throw(ArgumentError("cannot have more than two anyon erefs"))
            if has_anyon_erefs(t)
                other_ep = endpoint(t, curvepiece_partner(only(anyon_erefs(t))))
                vp = violated_partitions(t, ep_staying.edge, ep_staying.pos, other_ep.edge, other_ep.pos; exclude=_edge_erefs_from_cp_ids(t, ignore_ids))
            end
            # case 4
        elseif ep_staying isa AnyonEndpoint && ep_target isa EdgeEndpoint
            if num_anyon_erefs(t) == 2
                other_ep = endpoint(t, tile_partner(t, eref))
                vp = violated_partitions(t, other_ep.edge, other_ep.pos, edge, pos; exclude=_edge_erefs_from_cp_ids(t, ignore_ids))
            end
        end
        # if intersections exist
        isempty(vp) || throw(ArgumentError("curvepiece move violates partitions $vp"))
    end
    # track the position of the moving endpoint
    removal_pos = if ep_moving isa EdgeEndpoint
        ep_moving.pos
    end
    # insert new eref first (to throw any errors before mutating)
    if new_cp.endpoints[eref.endpoint_idx] isa EdgeEndpoint
        _insert_edge_eref!(t, eref, edge, pos)
        # insertion of new eref before old eref on the same edge will shift the old eref's position
        if ep_moving isa EdgeEndpoint
            if edge == ep_moving.edge && pos <= ep_moving.pos
                removal_pos += 1
            end
        end
    else
        _insert_anyon_eref!(t, eref)
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
