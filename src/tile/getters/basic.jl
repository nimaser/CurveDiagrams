################################################################################
# TILE GEOMETRY
################################################################################

"""Return the number of edges in the tile `t`."""
num_edges(t::Tile) = length(t._edge_erefs)

"""Return the next edge number after edge `edge` in the tile `t`, wrapping around."""
next_edge(t::Tile, edge::Int) = mod1(edge + 1, num_edges(t))

"""Return the prev edge number after edge `edge` in the tile `t`, wrapping around."""
prev_edge(t::Tile, edge::Int) = mod1(edge - 1, num_edges(t))

################################################################################
# EREFS
################################################################################

"""
Return a clockwise-ordered iterator over all `EndpointRef`s on `t`'s edges,
starting at pos `1` on edge `1`."""
all_edge_erefs(t::Tile) = Iterators.flatten(t._edge_erefs)


"""Return the number of `EndpointRef`s present on `t`'s edge `edge`."""
num_edge_erefs(t::Tile, edge::Int) = length(t._edge_erefs[edge])

"""Return whether `t`'s edge `edge` has any endpoints on it."""
has_edge_erefs(t::Tile, edge::Int) = !isempty(t._edge_erefs[edge])

"""Return a clockwise-ordered iterator over all `EndpointRef`s on `t`'s edge `edge`."""
edge_erefs(t::Tile, edge::Int) = (eref for eref in t._edge_erefs[edge])


"""Return the number of `EndpointRef`s at `t`'s anyon."""
num_anyon_erefs(t::Tile) = length(t._anyon_erefs)

"""Return whether there are any `EndpointRef`s at `t`'s anyon."""
has_anyon_erefs(t::Tile) = !isempty(t._anyon_erefs)

"""Return an iterator over all `EndpointRef`s at `t`'s anyon."""
anyon_erefs(t::Tile) = (eref for eref in t._anyon_erefs)


"""Return whether location `(edge, pos)` in `t` has an `EndpointRef`."""
has_edge_eref(t::Tile, edge::Int, pos::Int) = 1 <= pos <= num_edge_erefs(t, edge)

"""Return the `EndpointRef` at location `(edge, pos)` in `t`.."""
edge_eref(t::Tile, edge::Int, pos::Int) = t._edge_erefs[edge][pos]


"""
Return curvepiece `cp_id`s `EndpointRef`, if it exists, at `t`s anyon.
Otherwise return `nothing`.
"""
@inline function anyon_eref(t::Tile, cp_id::Int)
    for eref in anyon_erefs(t)
        eref.cp_id == cp_id && return eref
    end
    nothing
end

################################################################################
# ENDPOINTS
################################################################################

"""Return the `Endpoint` in `t` pointed to by `eref`."""
endpoint(t::Tile, eref::EndpointRef) = t._curvepieces[eref.cp_id].endpoints[eref.endpoint_idx]

"""Return the type (`EdgeEndpoint` or `AnyonEndpoint`) of the curvepiece partner of `eref` in tile `t`."""
curvepiece_partner_type(t::Tile, eref::EndpointRef) = typeof(endpoint(t, curvepiece_partner(eref)))

################################################################################
# CURVEPIECES
################################################################################

"""Return an iterator over all curvepiece ids present in `t`."""
curvepiece_ids(t::Tile) = keys(t._curvepieces)

"""Return an iterator over the `cp_id`s for all central curvepieces in `t`."""
central_curvepiece_ids(t::Tile) = Iterators.map(eref -> eref.cp_id, anyon_erefs(t))

"""Return the `Curvepiece` with id `cp_id` inside of `t`."""
curvepiece(t::Tile, cp_id::Int) = t._curvepieces[cp_id]

"""Return whether curvepiece `cp_id` in `t` has an `AnyonEndpoint`."""
is_central_curvepiece(t::Tile, cp_id::Int) = !isnothing(anyon_eref(t, cp_id))
