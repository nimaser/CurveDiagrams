###############################################################################
# TILE GEOMETRY
###############################################################################

"""Return the number of edges in the tile `t`."""
@inline num_edges(t::Tile) = length(t._edge_erefs)

"""Return the next edge number after edge `edge` in the tile `t`, wrapping around."""
@inline next_edge(t::Tile, edge::Int) = mod1(edge + 1, num_edges(t))

"""Return the prev edge number after edge `edge` in the tile `t`, wrapping around."""
@inline prev_edge(t::Tile, edge::Int) = mod1(edge - 1, num_edges(t))

###############################################################################
# EREF GETTERS
###############################################################################

"""Returns a clockwise-ordered list of all `EndpointRef`s located on the edges of tile `t`."""
@inline all_edge_erefs(t::Tile) = collect(Iterators.flatten(t._edge_erefs))


"""The number of endpoints present on edge `edge` in `t`."""
@inline num_edge_erefs(t::Tile, edge::Int) = length(t._edge_erefs[edge])

"""Whether the edge `edge` in tile `t` has any endpoints on it."""
@inline has_edge_erefs(t::Tile, edge::Int) = !isempty(t._edge_erefs[edge])

"""Returns a clockwise-ordered list of all `EndpointRef`s located on edge `edge` of tile `t`."""
@inline edge_erefs(t::Tile, edge::Int) = collect(t._edge_erefs[edge])


"""Whether the edge `edge` in tile `t` has any `EndpointRef` at position `pos`."""
@inline has_edge_eref(t::Tile, edge::Int, pos::Int) = 1 <= pos <= num_edge_erefs(t, edge)

"""Returns the `EndpointRef` at position `pos` on edge `edge` in tile `t`."""
@inline edge_eref(t::Tile, edge::Int, pos::Int) = t._edge_erefs[edge][pos]


"""Return the number of `EndpointRef`s at tile `t`'s anyon."""
@inline num_anyon_erefs(t::Tile) = length(t._anyon_erefs)

"""Whether there are any `EndpointRef`s at tile `t`'s anyon."""
@inline has_anyon_erefs(t::Tile) = !isempty(t._anyon_erefs)

"""Return a list of all `EndpointRef`s at tile `t`'s anyon."""
@inline anyon_erefs(t::Tile) = collect(t._anyon_erefs)


"""Return curvepiece `cp_id`s `EndpointRef`, if it exists, at `t`s anyon. Otherwise return `nothing`."""
@inline function anyon_eref(t::Tile, cp_id::Int)
    for eref in t._anyon_erefs # direct access to avoid allocations during collect() in anyon_erefs(t)
        eref.cp_id == cp_id && return eref
    end
    nothing
end

###############################################################################
# EREF TRAVERSAL
###############################################################################

"""
Returns the `EndpointRef` next encountered while traversing edge `edge` of `t`
***clockwise*** starting at position `pos`; returns `nothing` if there is no
further `EndpointRef` on that edge. Out of bounds `pos` values are allowed.
"""
function next_eref(t::Tile, edge::Int, pos::Int)
    if !has_edge_erefs(t, edge) return nothing end
    if pos < 1 return edge_eref(t, edge, 1) end
    pos < num_edge_erefs(t, edge) ? edge_eref(t, edge, pos+1) : nothing
end

"""
Returns the `EndpointRef` next encountered while traversing edge `edge` of `t`
***counterclockwise*** starting at position `pos`; returns `nothing` if there
is no further `EndpointRef` on that edge. Out of bounds `pos` values are allowed.
"""
function prev_eref(t::Tile, edge::Int, pos::Int)
    if !has_edge_erefs(t, edge) return nothing end
    if pos > num_edge_erefs(t, edge) return edge_eref(t, edge, num_edge_erefs(t, edge)) end
    pos > 1 ? edge_eref(t, edge, pos-1) : nothing
end

"""
Returns the `EndpointRef` next encountered when traversing `t`s edges ***clockwise***
starting at position `pos` on edge `edge`. Out of bounds `pos` values are allowed.

If there is only one `EndpointRef` on the edges of `t` (for example, in the case
where there is just one central curvepiece), the `EndpointRef` returned will be
the one at (`edge`, `pos`), i.e. the one at the starting position.

If there are no `EndpointRef`s on the edges of `t`, returns `nothing`.
"""
function next_eref_wrap(t::Tile, edge::Int, pos::Int)
    # return next eref on the same edge, if it exists
    next = next_eref(t, edge, pos)
    if next !== nothing return next end
    # traverse the remaining edges, returning the first eref on the first nonempty one found
    e = next_edge(t, edge)
    while e != edge
        if has_edge_erefs(t, e) return edge_eref(t, e, 1) end
        e = next_edge(t, e)
    end
    # wrapped around, return first eref if it exists
    has_edge_erefs(t, e) ? edge_eref(t, e, 1) : nothing
end

"""
Returns the `EndpointRef` next encountered when traversing `t`s edges ***counterclockwise***
starting at position `pos` on edge `edge`. Out of bounds `pos` values are allowed.

If there is only one `EndpointRef` on the edges of `t` (for example, in the case
where there is just one central curvepiece), the `EndpointRef` returned will be
the one at (`edge`, `pos`), i.e. the one at the starting position.

If there are no `EndpointRef`s on the edges of `t`, returns `nothing`.
"""
function prev_eref_wrap(t::Tile, edge::Int, pos::Int)
    # return prev eref on the same edge, if it exists
    prev = prev_eref(t, edge, pos)
    if prev !== nothing return prev end
    # traverse the remaining edges, returning the first eref on the first nonempty one found
    e = prev_edge(t, edge)
    while e != edge
        if has_edge_erefs(t, e) return edge_eref(t, e, num_edge_erefs(t, e)) end
        e = prev_edge(t, e)
    end
    # wrapped around, return last eref if it exists
    has_edge_erefs(t, e) ? edge_eref(t, e, num_edge_erefs(t, e)) : nothing
end

"""
Orders the contents of `erefs` according to the order they are encountered when
traversing the `Tile`s edges clockwise starting at `pos` on `edge` in `t`.
Out of bounds `pos` values are allowed.

Throws an error if any element of `erefs` is not in `t`.
"""
function clockwise_sort(t::Tile, erefs::Set{EndpointRef}, edge::Int, pos::Int)
    sorted = EndpointRef[]
    isempty(erefs) && return sorted
    # get first eref to start traversal at
    start = has_edge_eref(t, edge, pos) ? edge_eref(t, edge, pos) : next_eref_wrap(t, edge, pos)
    start == nothing && throw(ArgumentError("tile has no endpoints"))
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

###############################################################################
# ENDPOINTS
###############################################################################

"""Returns the `Endpoint` in `t` pointed to by `eref`."""
@inline endpoint(t::Tile, eref::EndpointRef) = t._curvepieces[eref.cp_id].endpoints[eref.endpoint_idx]

"""Returns the type (`EdgeEndpoint` or `AnyonEndpoint`) of the curvepiece partner of `eref` in tile `t`."""
@inline curvepiece_partner_type(t::Tile, eref::EndpointRef) = typeof(endpoint(t, curvepiece_partner(eref)))

"""
Returns the 'tile partner' of `eref`, an edge endpoint in tile `t`. Returns
`nothing` if `eref` doesn't have a tile partner. A tile partner for an ***edge***
endpoint is informally the other edge endpoint that can be reached by traversing
curvepieces only in that tile, where two curvepieces 'connect' if they both have
an endpoint on the anyon. Formally:

If `eref` is on a boundary curvepiece, its tile partner is the same as its curvepiece
partner, i.e. the other endpoint on the curvepiece.

If `eref` is on a central curvepiece `cp1`:
- if there is only one endpoint on `t`'s anyon, its tile partner is `nothing`
- if there are two endpoints on `t`'s anyon, call the other curvepiece with an
endpoint on the anyon `cp2`; the tile partner of `eref` is the edge endpoint of
`cp2`

Throws an error if `eref` does not reference an `EdgeEndpoint`.
"""
function tile_partner(t::Tile, eref::EndpointRef, ::Type{EdgeEndpoint})
    endpoint(t, eref)::EdgeEndpoint
    curvepiece_partner_type(t, eref) === EdgeEndpoint && return curvepiece_partner(eref)
    other_cp_id = other_central_curvepiece_id(t, eref.cp_id)
    other_cp_id === nothing && return nothing
    curvepiece_partner(anyon_eref(t, other_cp_id))
end

"""
Returns the 'tile partner' of `eref`, an anyon endpoint in tile `t`. Returns
`nothing` if `eref` doesn't have a tile partner. A tile partner for an ***anyon***
endpoint is the other anyon endpoint on `t`'s anyon.

Throws an error if `eref` does not reference an `AnyonEndpoint`.
"""
function tile_partner(t::Tile, eref::EndpointRef, ::Type{AnyonEndpoint})
    endpoint(t, eref)::AnyonEndpoint
    other_cp_id = other_central_curvepiece_id(t, eref.cp_id)
    other_cp_id === nothing && return nothing
    anyon_eref(t, other_cp_id)
end

###############################################################################
# CURVEPIECES
###############################################################################

"""Returns an iterator over all curvepiece ids present in `t`."""
@inline curvepiece_ids(t::Tile) = keys(t._curvepieces)

"""Returns the `Curvepiece` with id `cp_id` inside of `t`."""
@inline curvepiece(t::Tile, cp_id::Int) = t._curvepieces[cp_id]

"""Returns `cp_id`s for all central curvepieces in `t`."""
@inline central_curvepiece_ids(t::Tile) = [eref.cp_id for eref in t._anyon_erefs]

"""Whether curvepiece `cp_id` in `t` has an `AnyonEndpoint`."""
@inline is_central_curvepiece(t::Tile, cp_id::Int) = anyon_eref(t, cp_id) !== nothing

"""
Given a central curvepiece `cp_id` in tile `t`, returns the `cp_id` of the other
central curvepiece in `t`, which is on the same curve, or `nothing` if no such
curvepiece exists. Throws an error if `cp_id` is not an anyon curvepiece.
"""
function other_central_curvepiece_id(t::Tile, cp_id::Int)
    is_central_curvepiece(t, cp_id) ||
        throw(ArgumentError("curvepiece $cp_id is not a central curvepiece"))
    for eref in t._anyon_erefs # direct access avoids an allocation from collect()
        eref.cp_id != cp_id && return eref.cp_id
    end
    nothing
end

"""
Return the `curve_id` of the tile's central curvepieces, and `nothing` if there
are no such curvepieces. If there are two curvepieces with endpoints on the anyon,
they must have the same `curve_id`.
"""
function curve_id(t::Tile)
    cp_ids = central_curvepiece_ids(t)
    isempty(cp_ids) && return nothing
    cp = curvepiece(t, first(cp_ids))
    cp.curve_id
end

"""
Return the `anyon_count` of the anyon in this tile, if it has one, or `nothing`
otherwise. That is, if there are any curvepieces with endpoints on the anyon,
they are are part of a curve diagram, and this function returning `n` means that
this anyon is the `nth` encountered on that curve diagram. """
function anyon_count(t::Tile)
    # get central curvepieces
    cp_ids = central_curvepiece_ids(t)
    isempty(cp_ids) && return nothing
    curvepieces = [curvepiece(t, id) for id in cp_ids]
    # try to find an outgoing central curvepiece, and return its anyon_count if found
    outgoing_id = findfirst(cp -> cp.endpoints[1] isa AnyonEndpoint, curvepieces)
    if outgoing_id !== nothing
        return curvepieces[outgoing_id].anyon_count
    else
        # only an incoming central curvepiece present, so we need to increase by 1
        return only(curvepieces).anyon_count + 1
    end
end

"""
Return the curvepiece ids for all u-turn curvepieces in `t`. A u-turn curvepiece
is a boundary curvepiece with both endpoints on the same edge.

This function is `O(N)` where `N` is the number of curvepieces in the tile.
"""
function u_turn_curvepiece_ids(t::Tile)
    u_turns = Int[]
    for (cp_id, cp) in t._curvepieces # access field directly for efficiency
        ep1, ep2 = cp.endpoints
        if ep1 isa EdgeEndpoint && ep2 isa EdgeEndpoint # is it a boundary curvepiece
            if ep1.edge == ep2.edge # are both on same edge
                push!(u_turns, cp_id)
            end
        end
    end
    u_turns
end

"""
Return whether the curvepiece hugs any corner in `t`.

If E1 and E2 are adjacent (going clockwise) edges in `t` which meet at a corner
A, then `cp_id` hugs A if its endpoints are the last on E1 and first on E2. In
other words, it hugs A if there are no endpoints between its endpoints and A.
"""
function hugs_corner(t::Tile, cp_id::Int)
    cp = curvepiece(t, cp_id)
    ep1, ep2 = cp.endpoints
    ep1 isa EdgeEndpoint && ep2 isa EdgeEndpoint || return false
    # clockwise and counterclockwise cases respectively
    if next_edge(t, ep1.edge) == ep2.edge
        ep1.pos == num_edge_erefs(t, ep1.edge) && ep2.pos == 1 && return true
    end
    if next_edge(t, ep2.edge) == ep1.edge
        ep2.pos == num_edge_erefs(t, ep2.edge) && ep1.pos == 1 && return true
    end
    false
end

"""
Return a list of all partitions in the tile.

"""
function partitions(t::Tile)
    # get all boundary curvepiece ids
    boundary_ids = setdiff(curvepiece_ids(t), central_curvepiece_ids(t))

end

"""
Return a `Dict{Int, Tuple{Int, Int}}` mapping curvepiece ids to a (nesting level,
max enclosing number) tuple for each curvepiece.

Boundary curvepieces in a tile may be nested inside each other, in the sense that
their endpoints may enclose both endpoints of another curvepiece. In other words,
each boundary curvepiece partitions the tile into two parts, and all other boundary
curvepieces will lay entirely inside one of those parts. The 'nesting level' of a
boundary curvepiece is the number of nested layers of boundary curvepieces enclosed
within it.

To be clear, the nesting level is not the total number of curvepieces enclosed
within a curvepiece. Consider two situations, each with three curvepieces A, B,
and C. First:
- C encloses nothing
- B encloses C's endpoints
- A encloses B's endpoints
In this case, C, B, and A have nesting numbers of 1, 2, and 3 respectively. Next:
- C encloses nothing
- B encloses nothing
- A encloses both B and C's endpoints
In this case, B and C are akin to 'siblings', both having nesting numbers of 1,
while A has a nesting number of 2. So nesting level counts nested layers, not
total enclosed curvpeieces.

Because the endpoints live on a circle, there are two ways to do the nesting level
assignment, depending on which partition part you consider "inside" vs "outside"
for any particular curvepiece's partition. In the extreme case, two endpoints
which are directly adjacent could either be said to enclose all other curvepieces,
or no other curvepieces.

We choose to assign nesting levels in a way that is globally self-consistent for
all curvepieces within a tile and, loosely speaking, minimizes the nesting levels
assigned across all curvepieces in the tile. To do this, we start by scanning the
tile's endpoints, assigning all curvepieces with adjacent endpoints a nesting level
of 1. We then do this scan again, ignoring the already assigned endpoints when
determining adjacency, and this time assign curvepieces with adjacent endpoints a
nesting level of 2. We continue scanning, increasing the assigned value each pass,
until all boundary curvepiece endpoints are assigned.

Because of this scheme, nesting levels tend to 'meet' in the 'middle' of the tile,
and the assignments may depend on which endpoint around the tile the adjacency
scans are started.

We also make the choice that no curvepiece is allowed to 'enclose' a central
curvepiece's edge endpoint, meaning if a boundary curvepiece has its endpoints on
either side of a central curvepiece's edge endpoint, it is considered to enclose
every other endpoint on the tile other than those three already mentioned. The
result of this is that nesting level assignment starts from the 'other side' of
the tile, ending at that boundary curvepiece.

The maximum enclosing number for a curvepiece is:
- the largest nesting level of any curvepiece which encloses it
- its own nesting level, if no curvepiece encloses it

The complexity of this function is as follows:
- in the worst case, with `n` edge endpoints, all curvepieces are nested, requiring
`n/2` passes through the outer loop to assign all `n/2` curvepieces
- the inner loop is `O(n)` on each pass, considering building `unassigned`, iterating
through 1:m, and iterating through the `between` loop are all `O(n)`
- therefore, it is `O(n^2)` in time complexity
- in terms of space complexity, `all_edge_erefs`, `assigned`, `nesting`, `max_enc`,
`ee_ids` are all `O(n)` persistent datastructures in the function
- `unassigned`, `consumed`, and `newly_assigned` are also all `O(n)` datastructures,
whose memory is reallocated at the beginning of each loop
- therefore, it is `O(n)` in space complexity
I'm not exactly sure how memory allocations play into things, but there may be
some significant effects there...hopefully not.
"""
function nesting_hierarchy(t::Tile)
    # get all boundary curvepiece ids
    boundary_ids = setdiff(curvepiece_ids(t), central_curvepiece_ids(t))

    # get ordered list of all erefs on the edges, including those belonging to central curvepieces
    tile_edge_erefs = all_edge_erefs(t)
    N = length(tile_edge_erefs)

    # mask for if endpoint has been assigned a nesting level
    # cp_id -> nesting level
    # cp_id -> max enclosing number, set to -1 by default
    assigned = falses(N)
    nesting  = Dict{Int,Int}()
    max_enc  = Dict{Int,Int}(id => -1 for id in boundary_ids)

    # keep track of the nesting level to assign during each scan
    nesting_level = 1
    while true
        # (idx, eref) tuples for boundary curvepiece erefs lacking an assigned
        # nesting level along with central curvepiece edge erefs, which act as
        # barriers during the adjacency check; this prevents two erefs on
        # opposite sides of a central curvepiece from being immediately assigned
        # nesting level 1
        unassigned = [(i, tile_edge_erefs[i]) for i in 1:N if !assigned[i]]
        length(nesting) == length(boundary_ids) && break # all boundary curvepieces assigned

        # walk through the initially unassigned erefs, assigning adjacent pairs
        M = length(unassigned)
        newly_assigned_mask = falses(M) # whether we assigned this initially unassigned eref during this scan
        newly_assigned      = Int[]     # erefs which were assigned this scan
        for m in 1:M
            # skip if we already assigned this or the next initially unassigned erefs
            newly_assigned_mask[m] && continue
            n = mod1(m + 1, M)
            newly_assigned_mask[n] && continue
            # if the two consecutive unassigned erefs are not on the same curvepiece, skip
            # idx_ indexes into tile_edge_erefs, while m and n index into unassigned
            idx_m, eref_m = unassigned[m]
            idx_n, eref_n = unassigned[n]
            eref_m.cp_id == eref_n.cp_id || continue
            # set the nesting level for this curvepiece
            nesting[eref_m.cp_id] = nesting_level
            # get indices between n and m going clockwise, with wraparound, and
            # update the max enclosing number for all of those enclosed curvepieces
            between = idx_m < idx_n ? ((idx_m + 1):(idx_n - 1)) : Iterators.flatten(((idx_m + 1):N, 1:(idx_n - 1)))
            for idx in between
                between_id = tile_edge_erefs[idx].cp_id
                if haskey(nesting, between_id) max_enc[between_id] = nesting_level end
            end
            # mark these two erefs as assigned
            newly_assigned_mask[m] = newly_assigned_mask[n] = true
            push!(newly_assigned, idx_m, idx_n)
        end

        for i in newly_assigned; assigned[i] = true; end
        nesting_level += 1
    end

    # update maximally enclosing curvepiece values from the -1 initial value
    max_enc = Dict(id => max_enc[id] == -1 ? nesting[id] : max_enc[id] for id in boundary_ids)

    # dictionary mapping curvepiece_id to nesting and max enclosing numbers
    Dict(id => (nesting[id], max_enc[id]) for id in boundary_ids)
end
