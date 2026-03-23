### INTERNAL VALIDATION HELPERS ###

"""
Collects all `EndpointRef`s in the clockwise arc from `(edge1, pos1)` (inclusive) to
`(edge2, pos2)` (exclusive) on the boundary of `t`.
"""
function _EndpointRefs_between(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    arc = EndpointRef[]
    # if the arc is entirely contained within an edge
    if edge1 == edge2 && pos1 <= pos2
        for p in pos1:(pos2 - 1)
            push!(arc, get_edge_EndpointRef(t, edge1, p))
        end
    else
        # get endpoints on the remainder of edge1
        for p in pos1:num_endpoints(t, edge1)
            push!(arc, get_edge_EndpointRef(t, edge1, p))
        end
        # get all endpoints on intervening edges between edge1 and edge2
        e = next_edge(t, edge1)
        while e != edge2
            for p in 1:num_endpoints(t, e)
                push!(arc, get_edge_EndpointRef(t, e, p))
            end
            e = next_edge(t, e)
        end
        # get endpoints on the first part of edge2
        for p in 1:(pos2 - 1)
            push!(arc, get_edge_EndpointRef(t, edge2, p))
        end
    end
    arc
end

"""Returns all `EndpointRef`s in `arc` whose partners are NOT also in `arc`."""
function _unpaired_EndpointRefs(arc::Vector{EndpointRef})
    arc_set = Set(arc)
    [eref for eref in arc if get_partner_EndpointRef(eref) ∉ arc_set]
end

"""
Validates that the clockwise arc `(edge1, pos1) → (edge2, pos2)` is a valid edge-to-edge
partition: no existing curvepiece is split by it. Throws `ArgumentError` if:
- any edge-to-edge curvepiece has exactly one endpoint in the arc, or
- there are two anyon curvepieces and exactly one of their edge endpoints lies in the arc.

`exclude` optionally removes one `EndpointRef` from the arc before checking. This is useful
for the case when an eref is being moved to a new location and its old location shouldn't
affect the validity of the move.
"""
function _validate_edge_partition(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int;
                                   exclude::Union{EndpointRef, Nothing}=nothing)
    arc = _EndpointRefs_between(t, edge1, pos1, edge2, pos2)
    exclude !== nothing && filter!(r -> r != exclude, arc)
    unpaired = _unpaired_EndpointRefs(arc)
    unpaired_edge  = [r for r in unpaired if has_edge_partner(t, r)]
    unpaired_anyon = [r for r in unpaired if has_anyon_partner(t, r)]
    if !isempty(unpaired_edge)
        throw(ArgumentError(
            "partition ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "$(length(unpaired_edge)) unpaired edge endpoint(s) in arc"))
    end
    # 0 or 2 unpaired anyon endpoints: valid. Exactly 1 with 2 anyon cps present: invalid
    if length(unpaired_anyon) == 1 && num_anyon_curvepieces(t) == 2
        throw(ArgumentError(
            "partition ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "arc crosses exactly one of two anyon-curvepiece boundary points"))
    end
end

"""
Validates that the clockwise arc `(edge1, pos1) → (edge2, pos2)` is a valid anyon partition:
no edge-to-edge curvepiece is split by it. Throws `ArgumentError` if any unpaired endpoints
are found in the arc.

`exclude` optionally removes one `EndpointRef` from the arc before checking. This is useful
for the case when an eref is being moved to a new location and its old location shouldn't
affect the validity of the move.
"""
function _validate_anyon_partition(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int;
                                    exclude::Union{EndpointRef, Nothing}=nothing)
    arc = _EndpointRefs_between(t, edge1, pos1, edge2, pos2)
    exclude !== nothing && filter!(r -> r != exclude, arc)
    unpaired = _unpaired_EndpointRefs(arc)
    if !isempty(unpaired)
        throw(ArgumentError(
            "anyon partition ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "$(length(unpaired)) unpaired endpoint(s) in arc"))
    end
end

"""Validation wrapper for edge-to-edge curvepiece insertion."""
function _validate_edge_to_edge_insertion(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    _validate_edge_partition(t, edge1, pos1, edge2, pos2)
end

"""Validation wrapper for edge-to-anyon curvepiece insertion."""
function _validate_edge_to_anyon_insertion(t::Tile, edge::Int, pos::Int)
    n = num_anyon_curvepieces(t)
    n == 0 && return
    n == 2 && throw(ArgumentError("tile already has two anyon curvepieces; cannot insert a third"))
    # n == 1: check no edge-to-edge cp crosses the partition formed by the two anyon cps
    anyon_eref = only(get_anyon_EndpointRefs(t))
    edge_ep = get_endpoint(t, get_partner_EndpointRef(anyon_eref))::EdgeEndpoint
    _validate_anyon_partition(t, edge, pos, edge_ep.edge, edge_ep.pos)
end

"""Validation wrapper for moving an edge endpoint."""
function _validate_move(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    partner_ep = get_endpoint(t, get_partner_EndpointRef(eref))
    if partner_ep isa EdgeEndpoint
        _validate_edge_partition(t, edge, pos, partner_ep.edge, partner_ep.pos; exclude=eref)
    else
        # a partition only forms when two anyon curvepieces are present
        num_anyon_curvepieces(t) == 1 && return
        other_anyon_eref = only(r for r in get_anyon_EndpointRefs(t) if r.cp_id != eref.cp_id)
        other_edge_ep = get_endpoint(t, get_partner_EndpointRef(other_anyon_eref))::EdgeEndpoint
        _validate_anyon_partition(t, edge, pos, other_edge_ep.edge, other_edge_ep.pos; exclude=eref)
    end
end

### PUBLIC MUTATORS ###

"""
Insert an edge-to-edge curvepiece. `edge1`, `pos1` is the IN endpoint, while `edge2`, `pos2` is the
OUT endpoint. Both positions are relative to the internal state at the time of the function call,
meaning that the caller should not 'adjust' for the fact that inserting one endpoint wil shift the
locations of endpoints. That is, if the two endpoints are on the same edge, `pos2 == pos1 + 1` would
lead to two endpoints, while `pos2 == pos1 + 2` would lead to endpoints separated by one intervening
endpoint.

This function validates attempted insertions against the current state of the tile to ensure that no
insertion leads to intersecting curve pieces. Note that each edge-to-edge curvepiece partitions the
tile into two parts. Note also that a pair of edge-to-anyon curvepieces also partitions the tile into
two parts. An insertion is only valid if, for any pair of parts formed by partitioning the tile in the
above ways, the insertion points of the new curvepiece both lie in the same part.

This validation can be done by checking the endpoints located between the two proposed insertion points;
note that an endpoint is 'unpaired' if it is between the insertion points but its partner is not:
- if there are no intervening unpaired endpoints, the insertion is valid
- if there are any intervening unpaired endpoints whose partners are on an edge, the insertion is invalid
- if there is one intervening unpaired endpoint whose partner is on the anyon, and there is only one
  curvepiece with an endpoint on the anyon in the tile, the insertion is valid
- if there is one intervening unpaired endpoint whose partner is on the anyon, and there are two
  curvepieces with endpoints on the anyon, the insertion is invalid
- if there are two intervening unpaired endpoints whose partners are on the anyon, the insertion is valid

Returns the `cp_id` of the created curvepiece.
"""
function insert_curvepiece!(t::Tile, curve_id::Int, anyon_count::Int,
    edge1::Int, pos1::Int,
    edge2::Int, pos2::Int,
)
    _validate_edge_to_edge_insertion(t, edge1, pos1, edge2, pos2)
    cp_id = _allocate_cp_id!(t)
    # if both endpoints are on the same edge, inserting the first one shifts pos2
    pos2 = (edge1 == edge2 && pos1 <= pos2) ? pos2 + 1 : pos2
    cp = Curvepiece(curve_id, anyon_count,
        EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2))
    t._curvepieces[cp_id] = cp
    _insert_edge_EndpointRef!(t, EndpointRef(cp_id, 1), edge1, pos1)
    _insert_edge_EndpointRef!(t, EndpointRef(cp_id, 2), edge2, pos2)
    cp_id
end

"""
Insert an edge-to-anyon curvepiece. The provided direction will apply to both endpoints. It
is an error to have more than two edge-to-anyon curvepieces in the same tile, so any insertions
which would lead to that will throw an error.

This function also validates attempted insertions against the current state of the tile to
ensure that no insertion leads to intersecting curve pieces. Note that a pair of anyon-to-edge
curvepieces partitions the tile into two parts. An insertion is invalid when it causes an existing
edge-to-edge curvepiece to have its endpoints in different parts of the resulting partition. This
means that an insertion of the first edge-to-anyon curvepiece in a tile will never be invalid, as
having only one edge-to-anyon curvepiece does not result in a tile partition.

Algorithmically, this condition can be checked by sweeping one part of the partition caused by
the proposed insertion and verifying that there are no unpaired endpoints, i.e. endpoints whose
partners are in the other part of the partition, for the edge-to-edge curvepieces.

Finally, this function ensures that both curvepieces connected to an anyon have the same `curve_id`.

Returns the `cp_id` of the created curvepiece.
"""
function insert_curvepiece!(t::Tile, edge::Int, pos::Int, direction::EndpointDirection,
                            curve_id::Int, anyon_count::Int)
    if num_anyon_curvepieces(t) == 1
        existing = anyon_curve_id(t)
        existing != curve_id && throw(ArgumentError(
            "both anyon curvepieces must belong to the same curve; " *
            "existing curve_id=$existing, new curve_id=$curve_id"))
    end
    _validate_edge_to_anyon_insertion(t, edge, pos)
    cp_id = _allocate_cp_id!(t)
    # correct ordering occurs on construction
    cp = Curvepiece(curve_id, anyon_count,
        EdgeEndpoint(direction, edge, pos), AnyonEndpoint(direction))
    t._curvepieces[cp_id] = cp
    # extract ordering from cp, then use it to construct endpointrefs
    edge_which  = cp.endpoint1 isa EdgeEndpoint ? 1 : 2
    anyon_which = 3 - edge_which
    _insert_edge_EndpointRef!(t, EndpointRef(cp_id, edge_which), edge, pos)
    _push_anyon_EndpointRef!(t, EndpointRef(cp_id, anyon_which))
    cp_id
end

"""Remove the curvepiece with id `cp_id` from `t`, along with its `EndpointRef`s."""
function remove_curvepiece!(t::Tile, cp_id::Int)
    cp = get_curvepiece(t, cp_id)
    for (idx, ep) in enumerate((cp.endpoint1, cp.endpoint2))
        eref = EndpointRef(cp_id, idx)
        if ep isa EdgeEndpoint
            _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
        else
            _remove_anyon_EndpointRef!(t, eref)
        end
    end
    delete!(t._curvepieces, cp_id)
    nothing
end

"""
Move an `EdgeEndpoint` to a new location. `new_pos` is relative to the internal state
at the time of the function call, meaning the caller should not 'adjust' for the fact that
locations will shift after removing the existing `EndpointRef` from the internal datastructures.

Validates attempted moves against the current internal state of the tile to ensure that no
movement leads to crossed curvepieces. Similarly to the validation described in the
`insert_curvepiece!` methods, moving a curvepiece endpoint results in moving a partition of
the tile.

For moving an edge-to-edge curvepiece:
We have to check that the new partition of the tile does not split the two endpoints
of any other edge-to-edge curvepiece into different parts of the partition, and that if there
are two anyon-to-edge curvepieces, both of their edge endpoints are inside the same partition.

For moving an anyon-to-edge curvepiece:
We have to check that the new partition of the tile does not split the two endpoints of any edge-
to-edge curvepiece into different parts of the partition.
"""
function move_endpoint!(t::Tile, eref::EndpointRef, new_edge::Int, new_pos::Int)
    ep::EdgeEndpoint = get_endpoint(t, eref)
    _validate_move(t, eref, new_edge, new_pos)
    _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
    # if moving to somewhere on the same edge, removing the original EndpointRef changes the insertion position
    new_pos = (new_edge == ep.edge && new_pos > ep.pos) ? new_pos - 1 : new_pos
    _insert_edge_EndpointRef!(t, eref, new_edge, new_pos)
    _set_endpoint_location!(t, eref, new_edge, new_pos)
    nothing
end

"""Update the curve-related metadata for a curvepiece after e.g. a merge or grow operation."""
function set_curvepiece_metadata!(t::Tile, cp_id::Int, curve_id::Int, anyon_count::Int)
    cp = get_curvepiece(t, cp_id)
    t._curvepieces[cp_id] = Curvepiece(curve_id, anyon_count, cp.endpoint1, cp.endpoint2)
    nothing
end
