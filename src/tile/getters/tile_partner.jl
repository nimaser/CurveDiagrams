"""
Return the 'tile partner' of `eref`, which refers to an `EdgeEndpoint` in `t`.
Return `nothing` if `eref` doesn't have a tile partner.

A tile partner for an ***edge*** endpoint is informally the other edge endpoint
that can be reached by traversing curvepieces only in that tile, where two
curvepieces 'connect' if they both have an endpoint on the anyon. Formally:

If `eref` is on a boundary curvepiece, its tile partner is the same as its curvepiece
partner, i.e. the other endpoint on the curvepiece.

If `eref` is on a central curvepiece `cp1`:
- if there is only one endpoint on `t`'s anyon, its tile partner is `nothing`
- if there are two endpoints on `t`'s anyon, call the other curvepiece with an
endpoint on the anyon `cp2`; the tile partner of `eref` is the `EdgeEndpoint` of
`cp2`

Throw an error if `eref` does not reference an `EdgeEndpoint`.
"""
function tile_partner(t::Tile, eref::EndpointRef, ::Type{EdgeEndpoint})
    endpoint(t, eref)::EdgeEndpoint
    curvepiece_partner_type(t, eref) === EdgeEndpoint && return curvepiece_partner(eref)
    other_cp_id = other_central_curvepiece_id(t, eref.cp_id)
    other_cp_id === nothing && return nothing
    curvepiece_partner(anyon_eref(t, other_cp_id))
end

"""
Return the 'tile partner' of `eref`, which refers to an `AnyonEndpoint` in `t`.
Return `nothing` if `eref` doesn't have a tile partner.

A tile partner for an ***anyon*** endpoint is the other anyon endpoint on `t`'s
anyon.

Throw an error if `eref` does not reference an `AnyonEndpoint`.
"""
function tile_partner(t::Tile, eref::EndpointRef, ::Type{AnyonEndpoint})
    endpoint(t, eref)::AnyonEndpoint
    other_cp_id = other_central_curvepiece_id(t, eref.cp_id)
    other_cp_id === nothing && return nothing
    anyon_eref(t, other_cp_id)
end
