"""
Return the id of the central curvepiece in `t` other than curvepiece `cp_id`.
Return `nothing` if no such curvepiece exists.

Throw an error if `cp_id` is not an anyon curvepiece.
"""
function other_central_curvepiece_id(t::Tile, cp_id::Int)
    is_central_curvepiece(t, cp_id) ||
        throw(ArgumentError("curvepiece $cp_id is not a central curvepiece"))
    for eref in anyon_erefs(t)
        eref.cp_id != cp_id && return eref.cp_id
    end
    nothing
end

"""
Return a tuple with the:
- incoming central curvepiece id
- incoming central curvepiece
- outgoing central curvepiece id
- outgoing central curvepiece

with `nothing` as an element if the corresponding curvepiece doesn't exist.
"""
@inline function ordered_central_curvepieces(t::Tile)
    cp_ids = collect(central_curvepiece_ids(t))
    curvepieces = [curvepiece(t, id) for id in cp_ids]
    incoming_id = findfirst(cp -> last(cp) isa AnyonEndpoint, curvepieces)
    outgoing_id = findfirst(cp -> first(cp) isa AnyonEndpoint, curvepieces)
    incoming = incoming_id === nothing ? (nothing, nothing) : (cp_ids[incoming_id], curvepieces[incoming_id])
    outgoing = outgoing_id === nothing ? (nothing, nothing) : (cp_ids[outgoing_id], curvepieces[outgoing_id])
    incoming..., outgoing...
end

"""
Return the `curve_id` of the tile's central curvepieces, and `nothing` if there
are no such curvepieces. If there are two central curvepieces, they must be on
the same `Curve`.
"""
@inline function curve_id(t::Tile)
    cp_ids = central_curvepiece_ids(t)
    isempty(cp_ids) && return nothing
    cp = curvepiece(t, first(cp_ids))
    cp.curve_id
end

"""
Return the `anyon_count` of the anyon in this tile, if it has one, or `nothing`
otherwise. That is, if there are any central curvepieces, they are are part of
a `Curve`, and this function returning `n` means that this anyon is the `nth`
encountered when traversing that `Curve`."""
function anyon_count(t::Tile)
    _, incoming, _, outgoing = ordered_central_curvepieces(t)
    # try to find an outgoing central curvepiece, and return its anyon_count if found
    isnothing(outgoing) || return outgoing.anyon_count
    # only an incoming central curvepiece present, so we need to increase by 1
    isnothing(incoming) || return incoming.anyon_count + 1
    # the tile has no central curvepieces and thus no anyon_count
    nothing
end
