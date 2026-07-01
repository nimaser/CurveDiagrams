"""
Return whether `t` is valid, meaning that
- there are 0, 1, or 2 anyon erefs
- if there are 2 anyon erefs:
    - both refer to central curvepieces with the same `curve_id`
    - the incoming central curvepiece has `anyon_count` one less than the outoing one
"""
function is_anyon_valid(t::Tile)
    num_anyon_erefs(t) ∈ (0, 1, 2) || return false
    _, incoming, _, outgoing = ordered_central_curvepieces(t)
    if num_anyon_erefs(t) == 2
        incoming.curve_id == outgoing.curve_id || return false
        incoming.anyon_count == outgoing.anyon_count - 1 || return false
    end
    true
end

"""
Return whether `t` is complete, meaning there is a 1-to-1 correspondence between
- `CurvepieceEndpoint`s in `Curvepiece`s in `t._curvepieces`
- `EndpointRef`s in `t._anyon_erefs` and in the elements of `t._edge_erefs`

In practice, this means checking that
- for every `CurvepieceEndpoint` `ep` there is a corresponding `EndpointRef` `eref`
    - in the correct location
    - that correctly refers to `ep`
- for every `EndpointRef` `eref` there is a corresponding `CurvepieceEndpoint` `ep`
that is unique in `t`
"""
function is_complete(t::Tile)
    for (cp_id, cp) in t._curvepieces
        for (endpoint_idx, ep) in enumerate(cp.endpoints)
            # check eref exists and has the correct information
            if ep isa AnyonEndpoint
                eref = anyon_eref(t, cp_id)
                eref !== nothing || return false
            else
                has_edge_eref(t, ep.edge, ep.pos) || return false
                eref = edge_eref(t, ep.edge, ep.pos)
            end
            (eref.cp_id == cp_id) && (eref.endpoint_idx == endpoint_idx) || return false
        end
    end
    # check that every eref is unique and has a corresponding CurvepieceEndpoint
    seen = EndpointRef[]
    for eref in anyon_erefs(t)
        eref ∈ seen && return false
        endpoint(t, eref) isa AnyonEndpoint || return false
    end
    for eref in all_edge_erefs(t)
        eref ∈ seen && return false
        endpoint(t, eref) isa EdgeEndpoint || return false
    end
    true
end
