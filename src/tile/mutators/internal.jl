"""
    _allocate_cp_id!(t::Tile)

Return the next cp_id to be assigned.
"""
@inline function _allocate_cp_id!(t::Tile)
    id = t._next_cp_id[]
    t._next_cp_id[] += 1
    id
end

"""
    _update_endpoint_location!(t::Tile, edge::Int, pos::Int)

Update the stored location in the `EdgeEndpoint` referenced by the eref at
`(edge, pos)`.
"""
function _update_endpoint_location!(t::Tile, edge::Int, pos::Int)
    eref = t._edge_erefs[edge][pos]
    cp = t._curvepieces[eref.cp_id]
    t._curvepieces[eref.cp_id] = change_endpoint_location(cp, eref.endpoint_idx, edge, pos)
    nothing
end

"""
Insert `eref` at location `(edge, pos)` in `t`, shifting subsequent endpoint
locations up.

Return `nothing`.
"""
function _insert_edge_eref!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    insert!(t._edge_erefs[edge], pos, eref)
    # erefs now above pos have been shifted upwards by one index, so we need to
    # update the pos of the corresponding CurvepieceEndpoints to match
    for erefpos in pos+1:length(t._edge_erefs[edge])
        _update_endpoint_location!(t, edge, erefpos)
    end
    nothing
end

"""
Remove `EndpointRef` at location `(edge, pos)` in `t`, shifting subsequent endpoint
locations down.

Return `nothing`.
"""
function _remove_edge_eref!(t::Tile, edge::Int, pos::Int)
    deleteat!(t._edge_erefs[edge], pos)
    # erefs now at and above pos have been shifted downwards by one index, so we
    # need to update the pos of the corresponding CurvepieceEndpoints to match
    for erefpos in pos:length(t._edge_erefs[edge])
        _update_endpoint_location!(t, edge, erefpos)
    end
    nothing
end

"""
Insert `eref` into `t`'s anyon. Errors if this would result in more than two
`AnyonEndpoint`s on the anyon.

Return `nothing`.
"""
@inline function _insert_anyon_eref!(t::Tile, eref::EndpointRef)
    length(t._anyon_erefs) < 2 || throw(ArgumentError("cannot add another EndpointRef to the anyon"))
    push!(t._anyon_erefs, eref)
    nothing
end

"""
Remove `eref` from `t`'s anyon.

Return `nothing`.
"""
@inline function _remove_anyon_eref!(t::Tile, eref::EndpointRef)
    delete!(t._anyon_erefs, eref)
    nothing
end
