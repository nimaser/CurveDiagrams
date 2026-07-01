################################################################################
# EDGE EREF STEP
################################################################################

"""
    next_eref(t::Tile, edge::Int, pos::Int)

Return the `EndpointRef` next encountered while traversing edge `edge` of `t`
***clockwise*** starting at position `pos`; return `nothing` if there is no
further `EndpointRef` on that edge.

Out of bounds `pos` values are allowed and automatically clamped.
"""
@inline function next_eref(t::Tile, edge::Int, pos::Int)
    !has_edge_erefs(t, edge) && return nothing
    pos < 1 && return edge_eref(t, edge, 1)
    pos < num_edge_erefs(t, edge) ? edge_eref(t, edge, pos + 1) : nothing
end

"""
Return the `EndpointRef` next encountered while traversing edge `edge` of `t`
***counterclockwise*** starting at position `pos`; return `nothing` if there
is no further `EndpointRef` on that edge.

Out of bounds `pos` values are allowed and automatically clamped.
"""
@inline function prev_eref(t::Tile, edge::Int, pos::Int)
    !has_edge_erefs(t, edge) && return nothing
    pos > num_edge_erefs(t, edge) && return edge_eref(t, edge, num_edge_erefs(t, edge))
    pos > 1 ? edge_eref(t, edge, pos - 1) : nothing
end

################################################################################
# EDGE EREF STEP WRAP
################################################################################

"""
    next_eref_wrap(t::Tile, edge::Int, pos::Int)

Return the `EndpointRef` next encountered when traversing `t`s edges ***clockwise***
starting at location `(edge, pos)`. Out of bounds `pos` values are allowed and
automatically clamped.

If there is only one `EndpointRef` on the edges of `t` (for example, in the case
where there is just one central curvepiece), and it is at the starting location,
it will be returned.

Return `nothing` if there are no `EndpointRef`s on the edges of `t`.
"""
function next_eref_wrap(t::Tile, edge::Int, pos::Int)
    # return next eref on the same edge, if it exists
    next = next_eref(t, edge, pos)
    !isnothing(next) && return next
    # traverse the remaining edges, returning the first eref on the first nonempty one found
    e = next_edge(t, edge)
    while e != edge
        has_edge_erefs(t, e) && return edge_eref(t, e, 1)
        e = next_edge(t, e)
    end
    # wrapped around, return first eref if it exists
    has_edge_erefs(t, e) ? edge_eref(t, e, 1) : nothing
end

"""
    prev_eref_wrap(t::Tile, edge::Int, pos::Int)

Return the `EndpointRef` next encountered when traversing `t`s edges ***counterclockwise***
starting at location `(edge, pos)`. Out of bounds `pos` values are allowed and
automatically clamped.

If there is only one `EndpointRef` on the edges of `t` (for example, in the case
where there is just one central curvepiece), and it is at the starting location,
it will be returned.

Return `nothing` if there are no `EndpointRef`s on the edges of `t`.
"""
function prev_eref_wrap(t::Tile, edge::Int, pos::Int)
    # return prev eref on the same edge, if it exists
    prev = prev_eref(t, edge, pos)
    !isnothing(prev) && return prev
    # traverse the remaining edges, returning the first eref on the first nonempty one found
    e = prev_edge(t, edge)
    while e != edge
        has_edge_erefs(t, e) && return edge_eref(t, e, num_edge_erefs(t, e))
        e = prev_edge(t, e)
    end
    # wrapped around, return last eref if it exists
    has_edge_erefs(t, e) ? edge_eref(t, e, num_edge_erefs(t, e)) : nothing
end

################################################################################
# EDGE EREF TRAVERSAL
################################################################################

"""
    edge_eref_clockwise_sort(t::tile, erefs::Set{EndpointRef}, edge::Int, pos::Int)

Return the contents of `erefs` ordered according to the order they are encountered
when traversing `t`s edges clockwise starting at location `(edge, pos)`.

Throw an error if any element of `erefs` does not refer to an `EdgeEndpoint` in `t`.

Out of bounds `pos` values are allowed and automatically clamped.
"""
function edge_eref_clockwise_sort(t::Tile, erefs::Set{EndpointRef}, edge::Int, pos::Int)
    sorted = EndpointRef[]
    isempty(erefs) && return sorted
    # get first eref to start traversal at
    start = has_edge_eref(t, edge, pos) ? edge_eref(t, edge, pos) : next_eref_wrap(t, edge, pos)
    start == nothing && throw(ArgumentError("tile has no endpoints, but erefs nonempty"))
    # iterate through endpoints, adding to sorted as they are encountered
    current = start
    while true
        current ∈ erefs && push!(sorted, current)
        length(sorted) == length(erefs) && break
        epc = endpoint(t, current)::EdgeEndpoint
        current = next_eref_wrap(t, epc.edge, epc.pos)
        current == start && break
    end
    length(sorted) == length(erefs) || throw(ArgumentError("not all endpoints found in tile"))
    sorted
end

"""
edge_eref_clockwise_arc(t::Tile, edge1::int, pos1::Int, edge2::Int, pos2::Int)

Return a clockwise-ordered iterator over all `EndpointRef`s in the arc from
`(edge1, pos1)` (inclusive) to `(edge2, pos2)` (inclusive) on the edges of `t`.
Return an empty iterator if there are no erefs in the provided range.

Out of bounds `pos1` and `pos2` values are allowed and automatically clamped.
"""
function edge_eref_clockwise_arc(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    # clamp to valid values
    pos1c = max(pos1, 1)
    pos2c = min(pos2, num_edge_erefs(t, edge2))
    # if the arc is entirely contained within an edge
    if edge1 == edge2 && pos1 <= pos2
        return @view t._edge_erefs[edge1][pos1c:pos2c] # direct access to use view
    end
    # get erefs on the remainder of edge1
    subsequences = [@view(t._edge_erefs[edge1][pos1c:end])]
    # get all erefs on intervening edges between edge1 and edge2
    e = next_edge(t, edge1)
    while e != edge2
        push!(subsequences, @view(t._edge_erefs[e][1:end]))
        e = next_edge(t, e)
    end
    # get erefs on the first part of edge2
    push!(subsequences, @view(t._edge_erefs[edge2][1:pos2c]))
    Iterators.flatten(subsequences)
end
