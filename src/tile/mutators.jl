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
        # get endpoints on the first part of the edge2
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
Validates that inserting an edge-to-edge curvepiece at `(edge1, pos1) → (edge2, pos2)` does not
cause curve pieces to intersect. Throws `ArgumentError` if the insertion is invalid. See
insert_curvepiece! for more details.
"""
function _validate_edge_to_edge_insertion(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    arc      = _EndpointRefs_between(t, edge1, pos1, edge2, pos2)
    unpaired = _unpaired_EndpointRefs(arc)
    unpaired_edge_partners  = [eref for eref in unpaired if has_edge_partner(t, eref)]
    unpaired_anyon_partners = [eref for eref in unpaired if has_anyon_partner(t, eref)]

    if !isempty(unpaired_edge_partners)
        throw(ArgumentError(
            "insertion at ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "$(length(unpaired_edge_partners)) unpaired edge endpoint(s) in clockwise arc"))
    end
    n_anyon = length(unpaired_anyon_partners)
    if n_anyon == 1 && num_anyon_curvepieces(t) == 2
        throw(ArgumentError(
            "insertion at ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "arc crosses exactly one of two anyon-curvepiece boundary points"))
    end
    # n_anyon == 0: valid; n_anyon == 1 with 1 anyon cp: valid; n_anyon == 2: valid
end

"""
Validates that inserting an edge-to-anyon curvepiece at `(edge, pos)` does not cause curve pieces
to intersect. Throws `ArgumentError` if the tile already has two anyon curvepieces, or if the
insertion would cause an existing edge-to-edge curvepiece to cross the resulting partition. See
insert_curvepiece! for more details.
"""
function _validate_edge_to_anyon_insertion(t::Tile, edge::Int, pos::Int)
    n = num_anyon_curvepieces(t)
    n == 2 && throw(ArgumentError(
        "tile already has two anyon curvepieces; cannot insert a third"))
    n == 0 && return  # first anyon curvepiece never causes intersections

    # n == 1: verify no edge-to-edge curvepiece crosses the partition the two anyon cps will form
    existing_anyon_eref = first(get_anyon_EndpointRefs(t))
    existing_edge_eref  = get_partner_EndpointRef(existing_anyon_eref)
    existing_endpoint = get_endpoint(t, existing_edge_eref)::EdgeEndpoint

    arc     = _EndpointRefs_between(t, edge, pos, existing_endpoint.edge, existing_endpoint.pos)
    unpaired = _unpaired_EndpointRefs(arc)

    if !isempty(unpaired)
        throw(ArgumentError(
            "anyon curvepiece insertion at ($edge,$pos) would intersect curves: " *
            "$(length(unpaired)) edge-to-edge curvepiece(s) cross the resulting partition"))
    end
end

"""
Validates that moving the endpoint referenced by `eref` to `(edge, pos)` does not cause
curvepieces to intersect. Throws `ArgumentError` if the move is invalid.

Validation is performed against the current state of the tile (before `eref` has been
removed from its old location), and mirrors the logic in `_validate_edge_to_edge_insertion`
and `_validate_edge_to_anyon_insertion`. `eref` is excluded from the arc when its old
position falls within the new arc, so the check is not confused by the endpoint's current
location.

For an edge-to-edge curvepiece:
The new partition runs clockwise from `(edge, pos)` to the partner's current position.
The move is invalid if:
- any other edge-to-edge curvepiece has one endpoint inside the arc and one outside, or
- there are two anyon curvepieces and exactly one of their edge endpoints lies inside the arc
  (which would mean the anyon partition and the new partition cross).

For an anyon-to-edge curvepiece:
The partition is formed by the new position together with the other anyon curvepiece's edge
endpoint. No partition is formed when there is only one anyon curvepiece, so such a move is
always valid. When there are two anyon curvepieces, the move is invalid if any edge-to-edge
curvepiece has one endpoint inside the resulting arc and one outside.
"""
function _validate_move(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    partner_eref = get_partner_EndpointRef(eref)
    partner_ep   = get_endpoint(t, partner_eref)

    if partner_ep isa EdgeEndpoint
        # Moving an edge-to-edge curvepiece endpoint.
        arc = _EndpointRefs_between(t, edge, pos, partner_ep.edge, partner_ep.pos)
        filter!(r -> r != eref, arc)   # eref may appear at its old position inside the new arc
        unpaired = _unpaired_EndpointRefs(arc)
        unpaired_edge_partners  = [r for r in unpaired if has_edge_partner(t, r)]
        unpaired_anyon_partners = [r for r in unpaired if has_anyon_partner(t, r)]

        if !isempty(unpaired_edge_partners)
            throw(ArgumentError(
                "move to ($edge,$pos) would intersect curves: " *
                "$(length(unpaired_edge_partners)) unpaired edge endpoint(s) in clockwise arc"))
        end
        n_anyon = length(unpaired_anyon_partners)
        if n_anyon == 1 && num_anyon_curvepieces(t) == 2
            throw(ArgumentError(
                "move to ($edge,$pos) would intersect curves: " *
                "arc crosses exactly one of two anyon-curvepiece boundary points"))
        end
    else
        # Moving an anyon-to-edge curvepiece endpoint.
        # A partition only forms when two anyon curvepieces are present.
        num_anyon_curvepieces(t) == 1 && return

        other_anyon_eref = first(r for r in get_anyon_EndpointRefs(t) if r.cp_id != eref.cp_id)
        other_edge_eref  = get_partner_EndpointRef(other_anyon_eref)
        other_edge_ep    = get_endpoint(t, other_edge_eref)::EdgeEndpoint

        arc = _EndpointRefs_between(t, edge, pos, other_edge_ep.edge, other_edge_ep.pos)
        filter!(r -> r != eref, arc)
        unpaired = _unpaired_EndpointRefs(arc)

        if !isempty(unpaired)
            throw(ArgumentError(
                "anyon curvepiece move to ($edge,$pos) would intersect curves: " *
                "$(length(unpaired)) edge-to-edge curvepiece(s) cross the resulting partition"))
        end
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

"""Remove the curvepiece with id `cp_id` from `t`, along with its EndpointRefs."""
function remove_curvepiece!(t::Tile, cp_id::Int)
    cp = t._curvepieces[cp_id]
    for (idx, ep) in enumerate((cp.endpoint1, cp.endpoint2))
        eref = EndpointRef(cp_id, idx)
        if ep isa EdgeEndpoint
            _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
        else
            delete!(t._anyon_endpoints, eref)
        end
    end
    delete!(t._curvepieces, cp_id)
    nothing
end

"""
Move an EdgeEndpoint to a new location. `new_pos` is relative to the internal state
at the time of the function call, meaning the caller should not 'adjust' for the fact that
locations will shift after removing the existing EndpointRef from the internal datastructures.

Validates attempted moves against the current internal state of the tile to ensure that no
movement leads to crossed curvepieces. Similarly to the validation described in the
insert_curvepiece! methods, moving a curvepiece endpoint results in moving a partition of
the tile.

For moving an edge-to-edge curvpiece:
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
