################################################################################
# HELPERS
################################################################################

"""
Return the set of `EndpointRef`s which reference `EdgeEndpoint`s on a `Curvepiece`
in `cp_ids`.
"""
function _edge_erefs_from_cp_ids(cp_ids::Set{Int})
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
Insert a boundary curvepiece into `t`. `(edge1, pos1)` and `(edge2, pos2)` are
the locations where the IN and OUT endpoints are inserted, respectively. `pos2`
is relative to the state of the tile *after* the IN endpoint has been inserted
at `pos1`. Callers must account for this when both endpoints share an edge: for
example, if `pos1 = 1, pos2 = 1`, then OUT is inserted at pos 1 after IN has
already occupied pos 1, pushing IN to pos 2, resulting in (clockwise) OUT, IN;
if `pos1 = 1, pos2 = 2`, then IN is inserted at pos 1, and OUT is inserted at
pos 2, resulting in (clockwise) IN, OUT. For cross-edge insertions, `pos2` is
equivalent to the pre-insertion position since inserting on `edge1` does not
affect erefs on `edge2`.

Return the `cp_id` of the created curvepiece.

Throw an error if the proposed insertion would lead to intersecting curvepieces.
Omit this validation by passing in `allow_intersections=true`.
"""
function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    edge1::Int, pos1::Int,
    edge2::Int, pos2::Int;
    check_intersections::Bool=true,
    ignore_ids::Set{Int}=Set{Int}()
)
    # validation
    if check_intersections
        # pos2 is in post-pos1-insertion coordinates; convert to pre-insertion for validation
        pos2_pre = (edge1 == edge2 && pos2 > pos1) ? pos2 - 1 : pos2
        vp = violated_partitions(t, edge1, pos1, edge2, pos2_pre; exclude=_edge_erefs_from_cp_ids(ignore_ids))
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

"""
function insert_curvepiece!(
    t::tile, curve_id::Int, anyon_count::Int,
    offset1::Symbol, ref_eref1::EndpointRef, direction1::EndpointDirection,
    offset2::Symbol, ref_eref2::EndpointRef, direction2::EndpointDirection;
    check_intersections::Bool=true,
    ignore_ids::Set{Int}=Set{Int}()
)
    # determine indexes of new endpoints 1 and 2 in new curvepiece
    direction1 != direction2 || throw(ArgumentError("boundary curvepiece directions cannot match"))
    endpoint1_idx = direction1 == IN ? 1 : 2
    endpoint2_idx = direction2 == IN ? 1 : 2
    # convert offsets to numbers
    offset1 ∈ (:ccw, :cw) && offset2 ∈ (:ccw, :cw) ||
        throw(ArgumentError("offset values must be :ccw or :cw"))
    pos_offset1 = offset1 == :ccw ? 0 : 1
    pos_offset2 = offset2 == :ccw ? 0 : 1
    # get endpoint1 location from reference endpoint and offset
    ref_ep1 = endpoint(t, ref_eref1)::EdgeEndpoint
    edge1 = ref_ep1.edge
    pos1 = ref_ep1.pos + pos_offset1
    # check that no partitions are violated
    if check_intersections
        # get endpoint2 pre-endpoint1-insertion location from reference endpoint and offset
        ref_ep2 = endpoint(t, ref_eref2)::EdgeEndpoint
        edge2 = ref_ep2.edge
        pos2 = ref_ep2.pos + pos_offset2
        vp = violated_partitions(t, edge1, pos1, edge2, pos2; exclude=_edge_erefs_from_cp_ids(ignore_ids))
        isempty(vp) || throw(ArgumentError("curvepiece insertion at ($edge1,$pos1)→($edge2,$pos2) violates partitions $vp"))
    end
    # insert first endpoint
    cp_id = _allocate_cp_id!(t)
    _insert_edge_eref!(t, EndpointRef(cp_id, endpoint1_idx), edge1, pos1)
    # refetch second reference endpoint in case it was shifted
    ref_ep2 = endpoint(t, ref_eref2)::EdgeEndpoint
    edge2 = ref_ep2.edge
    pos2 = ref_ep2.pos + pos_offset2
    # insert second endpoint
    _insert_edge_eref!(t, EndpointRef(cp_id, endpoint2_idx), edge2, pos2)
    # insert curvepiece
    cp = Curvepiece(curve_id, anyon_count, EdgeEndpoint(direction1, edge1, pos1), EdgeEndpoint(direction2, edge2, pos2))
    t._curvepieces[cp_id] = cp
    cp_id
end

################################################################################
# CENTRAL INSERT
################################################################################

"""
Insert a central curvepiece into `t`. `(edge, pos)` is where the edge endpoint
will be located. `direction` will apply to both endpoints and will control the
overall direction of the inserted curvepiece.

Return the `cp_id` of the created curvepiece.

Throw an error if the proposed insertion would lead to intersecting curvepieces.
Omit this validation by passing in `allow_intersections=true`.

Throw an error if an insertion would lead to either of the following:
- more than two central curvepieces in `t`
- more than one incoming or outgoing central curvepiece in `t`
"""
function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    edge::Int, pos::Int, direction::EndpointDirection;
    check_intersections::Bool=false,
    ignore_ids::Set{Int}=Set{Int}(),
)
    # validation
    unignored_anyon_ids = filter(eref -> eref.cp_id ∉ ignore_ids, collect(anyon_erefs(t)))
    length(unignored_anyon_ids) == 2
        throw(ArgumentError("cannot have more than two central curvepieces in a tile"))
    end
    if num_anyon_erefs(t) == 1 && check_intersections
        existing_edge_ep = endpoint(t, curvepiece_partner(only(anyon_erefs(t))))
        vp = violated_partitions(t, edge, pos, existing_edge_ep.edge, existing_edge_ep.pos; exclude=_edge_erefs_from_cp_ids(ignore_ids))
        isempty(vp) || throw(ArgumentError("curvepiece insertion at ($edge,$pos)→anyon violates partitions $vp"))
    end
    # insert curvepiece - correct endpoint ordering occurs on curvepiece construction
    cp_id = _allocate_cp_id!(t)
    cp = Curvepiece(curve_id, anyon_count, EdgeEndpoint(direction, edge, pos), AnyonEndpoint(direction))
    t._curvepieces[cp_id] = cp
    e_eref = EndpointRef(cp_id, direction == IN ? 1 : 2) # edge endpoint is 1st for incoming, 2nd for outgoing
    _insert_edge_eref!(t, e_eref, edge, pos)
    _insert_anyon_eref!(t, curvepiece_partner(e_eref))
    cp_id
end

function insert_curvepiece!(
    t::Tile, curve_id::Int, anyon_count::Int,
    offset::Symol, ref_eref::EndpointRef, direction::EndpointDirection;
    check_intersections::Bool=false,
    ignore_ids::Set{Int}=Set{Int}(),
)
    # convert offset to numbers
    offset ∈ (:ccw, :cw) ||
        throw(ArgumentError("offset values must be :ccw or :cw"))
    pos_offset = offset == :ccw ? 0 : 1
    # get endpoint location from reference endpoint and offset
    ref_ep = endpoint(t, ref_eref)::EdgeEndpoint
    edge = ref_ep.edge
    pos = ref_ep.pos + pos_offset
    insert_curvepiece!(t, curve_id, anyon_count,
        edge, pos, direction;
        check_intersections=check_intersections, ignore_ids=ignore_ids
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
this validation by passing in `allow_intersections=true`.

Throw an error if a move would lead to either of the following:
- more than two central curvepieces in `t`
- more than one incoming or outgoing central curvepiece in `t`

Curvepieces whose ids are in `ignore_ids` will not trigger errors.

See `change_endpoint_location` for a breakdown of the six possible move cases.

Returns `nothing`.
"""
function move_endpoint!(
    t::Tile, eref::EndpointRef, edge::Int, pos::Int;
    allow_intersections::Bool=false, ignore_ids::Set{Int}=Set{Int}(),
)
    old_cp = curvepiece(t, eref.cp_id)
    # get curvepiece with updated endpoint for moved eref; case 6 errors here
    new_cp = change_endpoint_location(old_cp, eref.endpoint_idx, edge, pos)
    # catch case 5 and any other effective no-ops (moving eref to its own location)
    old_cp == new_cp && return
    # validation
    if !allow_intersections
        ep_staying = old_cp.endpoints[curvepiece_partner(eref).endpoint_idx]
        ep_moving = old_cp.endpoints[eref.endpoint_idx]
        ep_target = new_cp.endpoints[eref.endpoint_idx]
        # partitions violated by this move, ignoring exclude_erefs
        vp = Set{EndpointRef}()
        # cases 1 and 2
        if ep_staying isa EdgeEndpoint && ep_target isa EdgeEndpoint
            ep_moving isa EdgeEndpint && push!(exclude_erefs, eref)
            vp = violated_partitions(t, ep_staying.edge, ep_staying.pos, edge, pos; exclude=_edge_erefs_from_cp_ids(ignore_ids))
            # case 3
        elseif ep_staying isa EdgeEndpoint && ep_moving isa EdgeEndpoint
            num_anyon_erefs(t) != 2 || throw(ArgumentError("cannot have more than two anyon erefs"))
            if has_anyon_erefs(t)
                other_ep = endpoint(t, curvepiece_partner(only(anyon_erefs(t))))
                vp = violated_partitions(t, ep_staying.edge, ep_staying.pos, other_ep.edge, other_ep.pos; exclude=_edge_erefs_from_cp_ids(ignore_ids))
            end
            # case 4
        elseif ep_staying isa AnyonEndpoint && ep_target isa EdgeEndpoint
            if num_anyon_erefs(t) == 2
                other_ep = endpoint(t, tile_partner(t, eref))
                vp = violated_partitions(t, other_ep.edge, other_ep.pos, edge, pos; exclude=_edge_erefs_from_cp_ids(ignore_ids))
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
