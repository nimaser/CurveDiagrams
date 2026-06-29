################################################################################
# TILE GEOMETRY
################################################################################

"""Return the number of edges in the tile `t`."""
@inline num_edges(t::Tile) = length(t._edge_erefs)

"""Return the next edge number after edge `edge` in the tile `t`, wrapping around."""
@inline next_edge(t::Tile, edge::Int) = mod1(edge + 1, num_edges(t))

"""Return the prev edge number after edge `edge` in the tile `t`, wrapping around."""
@inline prev_edge(t::Tile, edge::Int) = mod1(edge - 1, num_edges(t))

################################################################################
# EREF GETTERS
################################################################################

"""
Return a clockwise-ordered iterator over all `EndpointRef`s on `t`'s edges,
starting at pos `1` on edge `1`."""
@inline all_edge_erefs(t::Tile) = Iterators.flatten(t._edge_erefs)


"""Return the number of `EndpointRef`s present on `t`'s edge `edge`."""
@inline num_edge_erefs(t::Tile, edge::Int) = length(t._edge_erefs[edge])

"""Return whether `t`'s edge `edge` has any endpoints on it."""
@inline has_edge_erefs(t::Tile, edge::Int) = !isempty(t._edge_erefs[edge])

"""Return a clockwise-ordered iterator over all `EndpointRef`s on `t`'s edge `edge`."""
@inline edge_erefs(t::Tile, edge::Int) = (eref for eref in t._edge_erefs[edge])


"""Return whether location `(edge, pos)` in `t` has an `EndpointRef`."""
@inline has_edge_eref(t::Tile, edge::Int, pos::Int) = 1 <= pos <= num_edge_erefs(t, edge)

"""Return the `EndpointRef` at location `(edge, pos)` in `t`.."""
@inline edge_eref(t::Tile, edge::Int, pos::Int) = t._edge_erefs[edge][pos]


"""Return the number of `EndpointRef`s at `t`'s anyon."""
@inline num_anyon_erefs(t::Tile) = length(t._anyon_erefs)

"""Return whether there are any `EndpointRef`s at `t`'s anyon."""
@inline has_anyon_erefs(t::Tile) = !isempty(t._anyon_erefs)

"""Return an iterator over all `EndpointRef`s at `t`'s anyon."""
@inline anyon_erefs(t::Tile) = (eref for eref in t._anyon_erefs)


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
# EREF TRAVERSAL
################################################################################

"""
Return the `EndpointRef` next encountered while traversing edge `edge` of `t`
***clockwise*** starting at position `pos`; return `nothing` if there is no
further `EndpointRef` on that edge. Out of bounds `pos` values are allowed
and automatically clamped.
"""
function next_eref(t::Tile, edge::Int, pos::Int)
    if !has_edge_erefs(t, edge) return nothing end
    if pos < 1 return edge_eref(t, edge, 1) end
    pos < num_edge_erefs(t, edge) ? edge_eref(t, edge, pos+1) : nothing
end

"""
Return the `EndpointRef` next encountered while traversing edge `edge` of `t`
***counterclockwise*** starting at position `pos`; return `nothing` if there
is no further `EndpointRef` on that edge. Out of bounds `pos` values are allowed
and automatically clamped.
"""
function prev_eref(t::Tile, edge::Int, pos::Int)
    if !has_edge_erefs(t, edge) return nothing end
    if pos > num_edge_erefs(t, edge) return edge_eref(t, edge, num_edge_erefs(t, edge)) end
    pos > 1 ? edge_eref(t, edge, pos-1) : nothing
end

"""
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
Return the contents of `erefs` ordered according to the order they are encountered
when traversing `t`s edges clockwise starting at location `(edge, pos)`. Out of
bounds `pos` values are allowed and automatically clamped.

Throw an error if any element of `erefs` does not refer to an `EdgeEndpoint` in `t`.
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
Return a clockwise-ordered iterator over all `EndpointRef`s in the arc from
`(edge1, pos1)` (inclusive) to `(edge2, pos2)` (inclusive) on the edges of `t`.
Out of bounds `pos1` and `pos2` values are allowed and automatically clamped.

Return an empty iterator if there are no erefs in the provided range.
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

################################################################################
# ENDPOINTS
################################################################################

"""Return the `Endpoint` in `t` pointed to by `eref`."""
@inline endpoint(t::Tile, eref::EndpointRef) = t._curvepieces[eref.cp_id].endpoints[eref.endpoint_idx]

"""Return the type (`EdgeEndpoint` or `AnyonEndpoint`) of the curvepiece partner of `eref` in tile `t`."""
@inline curvepiece_partner_type(t::Tile, eref::EndpointRef) = typeof(endpoint(t, curvepiece_partner(eref)))

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

################################################################################
# CURVEPIECES
################################################################################

"""Return an iterator over all curvepiece ids present in `t`."""
@inline curvepiece_ids(t::Tile) = keys(t._curvepieces)

"""Return the `Curvepiece` with id `cp_id` inside of `t`."""
@inline curvepiece(t::Tile, cp_id::Int) = t._curvepieces[cp_id]

"""Return an iterator over the `cp_id`s for all central curvepieces in `t`."""
@inline central_curvepiece_ids(t::Tile) = (eref.cp_id for eref in t._anyon_erefs)

"""Return whether curvepiece `cp_id` in `t` has an `AnyonEndpoint`."""
@inline is_central_curvepiece(t::Tile, cp_id::Int) = anyon_eref(t, cp_id) !== nothing

"""
Given a central curvepiece `cp_id` in tile `t`, return the `cp_id` of the other
central curvepiece in `t`, which must be on the same `Curve`, or `nothing` if no such
curvepiece exists.

Throw an error if `cp_id` is not an anyon curvepiece.
"""
@inline function other_central_curvepiece_id(t::Tile, cp_id::Int)
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

"""
Return the curvepiece ids for all u-turn curvepieces in `t`. A u-turn curvepiece
is a boundary curvepiece with both endpoints on the same edge.

This function is `O(N)` where `N` is the number of curvepieces in the tile.
"""
function u_turn_curvepiece_ids(t::Tile)
    u_turn_cp_ids = Int[]
    for (cp_id, cp) in t._curvepieces # access field directly for efficiency
        if first(cp) isa EdgeEndpoint && last(cp) isa EdgeEndpoint # is it a boundary curvepiece
            if first(cp).edge == last(cp).edge # are both on same edge
                push!(u_turn_cp_ids, cp_id)
            end
        end
    end
    u_turn_cp_ids
end

"""
Return whether the curvepiece hugs any corner in `t`.

If E1 and E2 are adjacent (going clockwise) edges in `t` which meet at a corner
A, then `cp_id` hugs A if its endpoints are the last on E1 and first on E2. In
other words, it hugs A if there are no endpoints between its endpoints and A.
"""
function hugs_corner(t::Tile, cp_id::Int)
    cp = curvepiece(t, cp_id)
    first(cp) isa EdgeEndpoint && last(cp) isa EdgeEndpoint || return false
    # clockwise and counterclockwise cases respectively
    if next_edge(t, first(cp).edge) == last(cp).edge
        first(cp).pos == num_edge_erefs(t, first(cp).edge) && last(cp).pos == 1 && return true
    end
    if next_edge(t, last(cp).edge) == first(cp).edge
        last(cp).pos == num_edge_erefs(t, last(cp).edge) && first(cp).pos == 1 && return true
    end
    false
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
    tile_edge_erefs = collect(all_edge_erefs(t))
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

################################################################################
# TILE VALIDATION
################################################################################

"""
Return a list of all `EndpointRef`s in `erefs` whose tile partners in `t`, if
they exist, are not in `erefs`.

Each element of `erefs` must refer to an `EdgeEndpoint`, otherwise the result
may be incorrect.
"""
function _erefs_with_external_tile_partner(t::Tile, erefs::Set{EndpointRef})
    externaltilepartner::Set{EndpointRef}=Set()
    for e in erefs
        tp = tile_partner(t, e, EdgeEndpoint)
        if tp !== nothing && tp ∉ erefs
            push!(externaltilepartner, e)
        end
    end
    externaltilepartner
end

"""
Return the set of partitions in `t` which would be violated if a new partition
with endpoints at `(edge1, pos1)` and `(edge2, pos2)` was created. Partitions
formed using an eref in `exclude` are not considered, meaning they will not be
in the output even if they are violated by the new partition. Each element of
`exclude` must refer to an `EdgeEndpoint`, otherwise the result may be incorrect.

A partition P in a tile is a pair of edge endpoints which are tile partners. Let
- P1 and P2 be the two endpoints respectively
- PA1 be the set of endpoints contained in the clockwise walk from P1 to P2
- PA2 be the set of endpoints contained in the counterclockwise walk from P1 to P2
- PC be the set of curvepieces which contain P1 and/or P2

Because tile partners are unique, P can be defined by either P1 or P2 alone.

Because tile partners must always have opposing directions, we can let P1 and P2
be the OUT and IN `EdgeEndpoint`s. Then we can uniquely assign names to the two
arcs PA1 and PA2: PA1 and PA2 are the 'clockwise arc' and 'counterclockwise arc'
of the partition respectively. The sets PA1, PA2, and {A, B} partition the set of
edge erefs in the tile, hence the name.

If P1 and P2 are on the same boundary curvepiece, PC will just contain it. If they
are not, then by virtue of being tile partners, they must be on the two central
curvepieces in the tile, which will both be in PC. In either case, the curvepieces
in PC split the area of the tile into two parts.

A partition P is violated by another partition Q if the endpoints Q1 and Q2 of Q
are in different arcs of P. This is equivalent to saying that the curvepieces in
PC intersect the curvepieces in QC, which can be verified easily by drawing.

Therefore, this function detects, given the prospective endpoint locations of
either a boundary curvepiece or a pair of central curvepieces, whether inserting
those curvepieces will cause any curvepiece intersections with curvepieces already
in the tile.

Return a set of erefs which each define one existing partition which would be
violated by the proposed new partition.
"""
function violated_partitions(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int;
    exclude::Set{EndpointRef}=Set{EndpointRef}()
)
    # get erefs in the clockwise arc of P (P is defined by the function arguments)
    arc = Set(edge_eref_clockwise_arc(t, edge1, pos1, edge2, pos2-1))
    # add the tile partners of the erefs to exclude, so if the one in exclude isn't
    # in arc, its tile partner will be and the exclusion will still occur
    full_exclude = copy(exclude)
    for e in exclude
        tp = tile_partner(t, e, EdgeEndpoint)
        if tp !== nothing push!(full_exclude, tp) end
    end
    # remove excluded erefs from arc, so they're not checked
    filter!(eref -> eref ∉ full_exclude, arc)
    # erefs in arc with tp not in arc define partitions violated by P
    _erefs_with_external_tile_partner(t, arc)
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
