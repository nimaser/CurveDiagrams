"""
Returns the `CurvepieceRef` for the curvepiece which precedes `cref` in its curve diagram.

For an edge-to-edge curvepiece: returns the `CurvepieceRef` for the corresponding curvepiece
across the edge hosting `endpoint1` (the `IN` endpoint). This is the curvepiece that comes
*before* `cref` in curve diagram traversal order.

If `cref` is an edge-to-anyon curvepiece, it will do the above or return the other
edge-to-anyon curvepiece in the same tile, depending on whether `cref` refers to the
first or second such curvepiece in the tile.

Returns `nothing` if `endpoint1` is an `AnyonEndpoint` (the curvepiece is at
the start of its curve).
"""
function prev_curvepiece(l::Lattice, cref::CurvepieceRef)
    t = get_tile(l, cref.tile_id)
    cp = curvepiece(t, cref.cp_id)
    if cp.endpoints[1] isa AnyonEndpoint
        partner = other_central_curvepiece_id(t, cref.cp_id)
        partner === nothing && return nothing
        return CurvepieceRef(cref.tile_id, partner)
    end
    neighbor_tile_id, neighbor_eref = sibling_eref(l, cref.tile_id, EndpointRef(cref.cp_id, 1))
    CurvepieceRef(neighbor_tile_id, neighbor_eref.cp_id)
end

"""
Returns the `CurvepieceRef` for the curvepiece which follows `cref` in its curve diagram.

For an edge-to-edge curvepiece: returns the `CurvepieceRef` for the corresponding curvepiece
across the edge hosting `endpoint2` (the `OUT` endpoint). This is the curvepiece that comes
*after* `cref` in curve diagram traversal order.

If `cref` is an edge-to-anyon curvepiece, it will do the above or return the other
edge-to-anyon curvepiece in the same tile, depending on whether `cref` refers to the
first or second such curvepiece in the tile.

Returns `nothing` if `endpoint2` is an `AnyonEndpoint` (the curvepiece is at
the end of its curve).
"""
function next_curvepiece(l::Lattice, cref::CurvepieceRef)
    t = get_tile(l, cref.tile_id)
    cp = curvepiece(t, cref.cp_id)
    if cp.endpoints[2] isa AnyonEndpoint
        partner = other_central_curvepiece_id(t, cref.cp_id)
        partner === nothing && return nothing
        return CurvepieceRef(cref.tile_id, partner)
    end
    neighbor_tile_id, neighbor_eref = sibling_eref(l, cref.tile_id, EndpointRef(cref.cp_id, 2))
    CurvepieceRef(neighbor_tile_id, neighbor_eref.cp_id)
end

"""
Return the distances, measured in edge crossings, to the first and last anyons in the `Curve`
containing `tile_id`'s anyon, traversing along the path of the `Curve`.

Implemented by walking the curve diagram using `next_curvepiece` and `prev_curvepiece`.
"""
function extremity_distances(l::Lattice, tile_id::Int)
    # curve existence check
    t = get_tile(l, tile_id)
    cid = curve_id(t)
    isnothing(cid) && throw(ArgumentError("tile $tile_id's anyon is not part of any Curves"))
    # get traversal startpoints
    incoming_id, _, outgoing_id, _ = ordered_central_curvepieces(t)
    # traverse backwards
    prev_dist = 0
    last = CurvepieceRef(tile_id, incoming_id)
    while true
        curr = prev_curvepiece(l, last)
        isnothing(curr) && break
        if last.tile_id != curr.tile_id
            prev_dist += 1
        end
        last = curr
    end
    # traverse forwards
    next_dist = 0
    last = CurvepieceRef(tile_id, outgoing_id)
    while true
        curr = next_curvepiece(l, last)
        isnothing(curr) && break
        if last.tile_id != curr.tile_id
            next_dist += 1
        end
        last = curr
    end
    # donesies
    prev_dist, next_dist
end
