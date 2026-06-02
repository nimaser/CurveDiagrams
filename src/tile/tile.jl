"""
A reference to a curvepiece endpoint. Type name is often shortened to 'eref'. Contains:
- `cp_id`, the curvepiece's tile-unique id
- `endpoint_idx`, the index of the endpoint in the curvepiece (whether it comes first or second)
"""
struct EndpointRef
    cp_id::Int
    endpoint_idx::Int  # 1 or 2, for Curvepiece.endpoint1/endpoint2
end

"""Returns an `EndpointRef` to the curvepiece partner of the endpoint that `eref` is pointing to."""
@inline cp_partner(eref::EndpointRef) = EndpointRef(eref.cp_id, 3 - eref.endpoint_idx) # idx: 1 -> 2, 2 -> 1

"""
Each `Tile` is comprised of a number of curvepieces which enter/exit the tile. Methods on
`Tile` manage all of the details of inserting, removing, and modifying curvepieces in
that `Tile`. The fields of a `Tile` should never be modified directly by user code.

Each tile assigns curvepiece ids in sequence starting from 1. `_next_cp_id` contains the id
which will be assigned to the next curvepiece that is created.

Each tile contains a dictionary `_curvepieces` which maps from curvepiece ids to `Curvepiece`
structs, which contain all of the information about each curvepiece. The reason to choose a
dictionary rather than an array here (unlike what we do in `Lattice` for `_curvediagrams`) is
that in this case if we store the curvepieces in an array, its eltype must be `Union{Nothing, Curvepiece}`.
This seems like it might induce a performance penalty, and more importantly there aren't clear
runtime guarantees on the maximum number of curvepieces that can be created in a tile during
the simulation, meaning if we did not use a `Dict` we could end up with an extremely large and
sparse array of `nothing` stored densely.

A tile can have any number of edges `n_edges`, which is the sole parameter for the constructor.
For each edge, we store a vector of `EndpointRef`s in the order the endpoints are encountered
when walking along the edges of the tile clockwise. This allows backward-lookups from endpoint
location to curvepiece struct. All of these vectors of `EndpointRef`s are themselves stored in
the vector `_edge_endpoints`, which has a length equal to `n_edges`.

This design pattern reflects the need to support two data access patterns:
- given the id of a curvepiece, we want to obtain the endpoint locations
- given the endpoint locations of a curvepiece, we want to obtain the curvepiece information
We also generally want to store all of the information about a curvepiece in one centralized
datastructure, and then to enable any 'backwards-lookups' or other data access patterns not
supported by the chosen data structure, store various lightweight references.

The alternative would be something like storing the endpoint objects in the edge endpoint lists,
and then storing an index into this list (which would therefore encode the location) in each
`Curvepiece`, which leads to the data being spread across two different datastructures, which is
less clean and adds layers of indirection when trying to perform lookups.

Finally, 0, 1, or 2 endpoints can be located at the anyon in each tile. These `EndpointRef`s
are stored in `_anyon_endpoints`.
"""
struct Tile
    _next_cp_id::Ref{Int}
    _curvepieces::Dict{Int, Curvepiece}
    _edge_endpoints::Vector{Vector{EndpointRef}}
    _anyon_endpoints::Set{EndpointRef}
    Tile(n_edges::Int) = new(Ref(1), Dict{Int, Curvepiece}(), [EndpointRef[] for _ in 1:n_edges], Set{EndpointRef}())
end

###############################################################################
# PUBLIC GETTERS
###############################################################################

### TILE GEOMETRY ###

"""The number of edges in the tile `t`."""
@inline num_edges(t::Tile) = length(t._edge_endpoints)

"""The next edge number after edge `edge` in the tile `t`, wrapping around."""
@inline next_edge(t::Tile, edge::Int) = mod1(edge + 1, num_edges(t))

"""The prev edge number after edge `edge` in the tile `t`, wrapping around."""
@inline prev_edge(t::Tile, edge::Int) = mod1(edge - 1, num_edges(t))

### EREF GETTERS ###

"""Whether the edge `edge` in tile `t` has any endpoints on it."""
@inline has_edge_erefs(t::Tile, edge::Int) = !isempty(t._edge_endpoints[edge])

"""The number of endpoints present on edge `edge` in `t`."""
@inline num_edge_erefs(t::Tile, edge::Int) = length(t._edge_endpoints[edge])

"""Returns a clockwise-ordered list of all `EndpointRef`s located on edge `edge` of tile `t`."""
@inline edge_erefs(t::Tile, edge::Int) = collect(t._edge_endpoints[edge])

"""Returns a clockwise-ordered list of all `EndpointRef`s located on the edges of tile `t`."""
@inline edge_erefs(t::Tile) = collect(Iterators.flatten(t._edge_endpoints))

"""Whether the edge `edge` in tile `t` has any `EndpointRef` at position `pos`."""
@inline has_edge_eref(t::Tile, edge::Int, pos::Int) = 1 <= pos <= num_edge_erefs(t, edge)

"""Returns the `EndpointRef` at position `pos` on edge `edge` in tile `t`."""
@inline edge_eref(t::Tile, edge::Int, pos::Int) = t._edge_endpoints[edge][pos]

"""Number of curvepieces with an `EndpointRef` at tile `t`'s anyon."""
@inline num_anyon_erefs(t::Tile) = length(t._anyon_endpoints)

"""Whether there are any curvepieces with an `EndpointRef` at tile `t`'s anyon."""
@inline has_anyon_erefs(t::Tile) = !isempty(t._anyon_endpoints)

"""Returns a list of all the `EndpointRef`s located on the anyon in tile `t`."""
@inline anyon_erefs(t::Tile) = collect(t._anyon_endpoints)

"""Returns curvepiece `cp_id`s `EndpointRef`, if it exists, at `t`s anyon. Otherwise returns `nothing`."""
@inline function anyon_eref(t::Tile, cp_id::Int)
    for eref in t._anyon_endpoints # not using anyon_erefs(t) to avoid unnecessary collect() allocation
        eref.cp_id == cp_id && return eref
    end
    nothing
end

### EREF TRAVERSAL ###

"""
Returns the `EndpointRef` next encountered while traversing edge `edge` of `t` ***clockwise*** starting
at position `pos`; returns `nothing` if there is no further `EndpointRef` on that edge, and errors
if `pos` is out of bounds.
"""
function next_eref(t::Tile, edge::Int, pos::Int)
    endpoints = t._edge_endpoints[edge]
    1 <= pos <= length(endpoints) || throw(ArgumentError("pos $pos out of range 1..$(length(endpoints)) on edge $edge"))
    pos < length(endpoints) ? endpoints[pos + 1] : nothing
end

"""
Returns the `EndpointRef` next encountered while traversing edge `edge` of `t` ***counterclockwise***
starting at position `pos`; returns `nothing` if there is no further `EndpointRef` on that edge,
and errors if `pos` is out of bounds.
"""
function prev_eref(t::Tile, edge::Int, pos::Int)
    endpoints = t._edge_endpoints[edge]
    1 <= pos <= length(endpoints) || throw(ArgumentError("pos $pos out of range 1..$(length(endpoints)) on edge $edge"))
    pos > 1 ? endpoints[pos - 1] : nothing
end

"""
Returns the `EndpointRef` next encountered when traversing `t`s edges ***clockwise*** starting at
position `pos` on edge `edge`; errors if `pos` is out of bounds.

If there is only one `EndpointRef` on the edges of `t` (for example, in the case where there is just
one e2a or a2e curvepiece), the `EndpointRef` returned will be the one at (`edge`, `pos`), i.e. the
one at the starting position.
"""
function next_eref_wrap(t::Tile, edge::Int, pos::Int)
    # validate pos and return the next eref on the same edge, if it exists
    next = next_eref(t, edge, pos)
    if next !== nothing return next end
    # traverse the remaining edges, returning the first eref on the first nonempty one found
    e = next_edge(t, edge)
    while e != edge
        if has_edge_erefs(t, e) return edge_eref(t, e, 1) end
        e = next_edge(t, e)
    end
    # wrapped around, return first eref which exists from next_eref call success
    edge_eref(t, e, 1)
end

"""
Returns the `EndpointRef` next encountered when traversing `t`s edges ***counterclockwise*** starting
at position `pos` on edge `edge`; errors if `pos` is out of bounds.

If there is only one `EndpointRef` on the edges of `t` (for example, in the case where there is just
one e2a or a2e curvepiece), the `EndpointRef` returned will be the one at (`edge`, `pos`), i.e. the
one at the starting position.
"""
function prev_eref_wrap(t::Tile, edge::Int, pos::Int)
    # validate pos and return the prev eref on the same edge, if it exists
    prev = prev_eref(t, edge, pos)
    if prev !== nothing return prev end
    # traverse the remaining edges, returning the first eref on the first nonempty one found
    e = prev_edge(t, edge)
    while e != edge
        if has_edge_erefs(t, e) return edge_eref(t, e, num_edge_erefs(t, e)) end
        e = prev_edge(t, e)
    end
    # wrapped around, return last eref which exists from prev_eref call success
    edge_eref(t, e, num_edge_erefs(t, e))
end

"""
Orders the contents of `erefs` according to the order they are encountered when traversing
the `Tile`s edges clockwise starting at `pos` on `edge`. Assumes that

Throws an error if any element of `erefs` is not in the `Tile`.
"""
function ordered_erefs(t::Tile, erefs::Set{EndpointRef}, edge::Int, pos::Int)
    result = EndpointRef[]
    isempty(erefs) && return result
    start = has_edge_eref(t, edge, pos) ? edge_eref(t, edge, pos) : next_eref_wrap(t, edge, pos)
    start == nothing && throw(ArgumentError("tile has no endpoints"))
    current = start
    while true
        current ∈ erefs && push!(result, current)
        length(result) == length(erefs) && break
        epc = endpoint(t, current)::EdgeEndpoint
        current = next_eref_wrap(t, epc.edge, epc.pos)
        current == start && break
    end
    length(result) == length(erefs) || throw(ArgumentError("not all endpoints found in tile"))
    result
end

"""
Collects all `EndpointRef`s in the clockwise arc from `(edge1, pos1)` (inclusive) to
`(edge2, pos2)` (exclusive) on the boundary of `t`.
"""
function erefs_between(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    arc = EndpointRef[]
    # if the arc is entirely contained within an edge
    if edge1 == edge2 && pos1 <= pos2
        for p in pos1:(pos2 - 1)
            push!(arc, edge_eref(t, edge1, p))
        end
    else
        # get endpoints on the remainder of edge1
        for p in pos1:num_edge_erefs(t, edge1)
            push!(arc, edge_eref(t, edge1, p))
        end
        # get all endpoints on intervening edges between edge1 and edge2
        e = next_edge(t, edge1)
        while e != edge2
            for p in 1:num_edge_erefs(t, e)
                push!(arc, edge_eref(t, e, p))
            end
            e = next_edge(t, e)
        end
        # get endpoints on the first part of edge2
        for p in 1:(pos2 - 1)
            push!(arc, edge_eref(t, edge2, p))
        end
    end
    arc
end

"""Returns all `EndpointRef`s in `arc` whose partners are NOT also in `arc`."""
function unpaired_erefs(arc::Vector{EndpointRef})
    arc_set = Set(arc)
    [eref for eref in arc if cp_partner(eref) ∉ arc_set]
end

### ENDPOINTS ###

"""Returns the `Endpoint` in `t` pointed to by `eref`."""
@inline endpoint(t::Tile, eref::EndpointRef) =
    eref.endpoint_idx == 1 ? t._curvepieces[eref.cp_id].endpoint1 : t._curvepieces[eref.cp_id].endpoint2

"""Return the `Endpoint` of `cp` pointed to by `eref`."""
@inline endpoint(cp::Curvepiece, eref::EndpointRef) =
    eref.endpoint_idx == 1 ? cp.endpoint1 : cp.endpoint2

"""Returns the type (`EdgeEndpoint` or `AnyonEndpoint`) of the curvepiece partner of `eref` in tile `t`."""
@inline cp_partner_type(t::Tile, eref::EndpointRef) = typeof(endpoint(t, cp_partner(eref)))

"""
Returns the 'tile partner' of `eref`, an edge endpoint in tile `t`. Returns `nothing` if `eref`
doesn't have a tile partner. A tile partner for an ***edge*** endpoint is informally the other edge endpoint
that can be reached by traversing curvepieces only in that tile, where two curvepieces 'connect' if
they both have an endpoint on the anyon. Formally:

If `eref` is on an e2e curvepiece, its tile partner is the same as its curvepiece partner, i.e. the
other endpoint on the curvepiece.

If `eref` is on an a2e/e2a curvepiece `cp1`:
- if there is only one endpoint on `t`'s anyon, its tile partner doesn't exist
- if there are two endpoints on `t`'s anyon, call the other curvepiece with an endpoint on the anyon `cp2`;
  the tile partner of `eref` is the edge endpoint of `cp2`

Throws an error if `eref` does not reference an `EdgeEndpoint`.
"""
function tile_partner(t::Tile, eref::EndpointRef, ::Type{EdgeEndpoint})
    endpoint(t, eref)::EdgeEndpoint
    cp_partner_type(t, eref) === EdgeEndpoint && return cp_partner(eref)
    other_cp_id = partner_cp_id(t, eref.cp_id)
    other_cp_id === nothing && return nothing
    cp_partner(anyon_eref(t, other_cp_id))
end

"""
Returns the 'tile partner' of `eref`, an anyon endpoint in tile `t`. Returns `nothing` if `eref`
doesn't have a tile partner. A tile partner for an ***anyon*** endpoint is the other anyon endpoint
on `t`'s anyon.

Throws an error if `eref` does not reference an `AnyonEndpoint`.
"""
function tile_partner(t::Tile, eref::EndpointRef, ::Type{AnyonEndpoint})
    endpoint(t, eref)::AnyonEndpoint
    other_cp_id = partner_cp_id(t, eref.cp_id)
    other_cp_id === nothing && return nothing
    anyon_eref(t, other_cp_id)
end

### CURVEPIECES ###

"""Returns an iterator over all curvepiece ids present in `t`."""
curvepiece_ids(t::Tile) = keys(t._curvepieces)

"""Returns `cp_id`s for all anyon-to-edge curvepieces in `t`."""
function anyon_cp_ids(t::Tile)
    erefs = anyon_erefs(t)
    [eref.cp_id for eref in erefs]
end

"""
Given an anyon curvepiece `cp_id` in tile `t`, returns the `cp_id` of the other anyon
curvepiece on the same curve (its partner), or `nothing` if no such piece exists. Throws
an error if `cp_id` is not an anyon curvepiece.
"""
function partner_cp_id(t::Tile, cp_id::Int)
    is_anyon_curvepiece(t, cp_id) ||
        throw(ArgumentError("curvepiece $cp_id is not an anyon curvepiece so has no partner"))
    for eref in t._anyon_endpoints
        eref.cp_id != cp_id && return eref.cp_id
    end
    nothing
end

"""
Return a list of curvepiece ids for the u-turn curvepieces in `t`. A u-turn
curvepiece is an edge-to-edge curvepiece with both endpoints on the same edge.

This function is `O(N)` where `N` is the number of curvepieces in the tile.
"""
function u_turn_cp_ids(t::Tile)
    u_turns = Int[]
    for (cp_id, cp) in t._curvepieces # access field directly for efficiency
        ep1, ep2 = cp.endpoint1, cp.endpoint2
        if ep1 isa EdgeEndpoint && ep2 isa EdgeEndpoint # is it e2e
            if ep1.edge == ep2.edge # are both on same edge
                push!(u_turns, cp_id)
            end
        end
    end
    u_turns
end

"""
Return whether the curvepiece hugs any corner in `t`.

If E1 and E2 are two adjacent (going clockwise) edges in `t` which meet at a corner
A, then `cp_id` hugs A if its endpoints are the last on E1 and first on E2. In
other words, it hugs A if there are no endpoints between its endpoints and A.
"""
function hugs_corner(t::Tile, cp_id::Int)
    cp = curvepiece(t, cp_id)
    ep1 = cp.endpoint1
    ep2 = cp.endpoint2
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

"""Returns the `Curvepiece` with id `cp_id` inside of `t`."""
@inline curvepiece(t::Tile, cp_id::Int) = t._curvepieces[cp_id]

"""Whether curvepiece `cp_id` in `t` has an `AnyonEndpoint`."""
@inline is_anyon_curvepiece(t::Tile, cp_id::Int) = anyon_eref(t, cp_id) != nothing

"""
Returns the `curve_id` of the curvepieces which have endpoints on the anyon, `nothing` if there are
no such curvepieces. If there are two curvepieces with endpoints on the anyon, note that they will
have the same `curve_id`.
"""
function anyon_curve_id(t::Tile)
    cp_ids = anyon_cp_ids(t)
    isempty(cp_ids) && return nothing
    cp = curvepiece(t, first(cp_ids))
    cp.curve_id
end

"""
Return the `anyon_count` of the anyon in this tile, if it has one, or `nothing` otherwise. That is,
if there are any curvepieces with endpoints on the anyon, they are are part of a curve diagram, and
this function returning `n` means that this anyon is the `nth` encountered on the curve diagram.
"""
function anyon_count(t::Tile)
    cp_ids = anyon_cp_ids(t)
    isempty(cp_ids) && return nothing
    cps = [curvepiece(t, id) for id in cp_ids]
    # try to find an anyon-to-edge curvepiece, and return its anyon_count if found
    a2e = findfirst(cp -> cp.endpoint1 isa AnyonEndpoint, cps)
    if a2e !== nothing
        return cps[a2e].anyon_count
    else
        # only an edge-to-anyon curvepiece present, so we need to increase by 1
        return only(cps).anyon_count + 1
    end
end

"""
Calculates the nesting number and max enclosing number for each edge-to-edge
curve piece, returning a `Dict{Int, Tuple{Int, Int}}` that maps curvepiece ids to a tuple
of this information.

Edge-to-edge curvepieces in a tile may be nested 'inside' each other, in the sense that
their endpoints may enclose both endpoints of another curvepiece. In other words, each
edge-to-edge curvepiece partitions the tile into two parts, and all other edge-to-edge
curvepieces will lay inside one of those parts. The 'nesting number' of an edge-to-edge
curvepiece is the number of nested layers of edge-to-edge curvepieces enclosed within it.

To be clear, this is not the total number of curvepieces enclosed within it. Consider two
situations, each with three curvepieces A, B, and C. First:
- C encloses nothing
- B encloses C's endpoints
- A encloses B's endpoints
Then in this case, C, B, and A would have nesting numbers of 1, 2, and 3 respectively. Next:
- C encloses nothing
- B encloses nothing
- A encloses both B and C's endpoints
In this case, B and C are akin to 'siblings', both having nesting numbers of 1, while A has
a nesting number of 2. So nesting number counts nested layers, not total enclosed curvpeieces.

Because the endpoints live on a circle, there are two ways to do this assignment, depending
on which part of the partition you consider "inside" vs "outside" for any particular
curvepiece. In the extreme case, two endpoints which are directly adjacent could either be
said to enclose all other curvepieces, or no other curvepieces.

We choose to assign nesting numbers in a way that is globally self-consistent for all
curvepieces within a tile and loosely speaking minimizes the nesting numbers assigned
across all curvepieces in the tile. To do this, we start by assigning all curvepieces with
adjacent endpoints a nesting number of 1, then remove their endpoints from consideration
when calculating adjacency. We then do this scan again, this time assigning curvepieces
with adjacent endpoints a nesting number of 2. We continue till all edge-to-edge
endpoints are assigned.

Because of this, nesting numbers tend to 'meet' in the 'middle' of the tile, and the
assignments may depend on which endpoint around the tile the adjacency scans are started.

The maximum enclosing number for a curvepiece is the largest nesting number of
any curvepiece which encloses it, or if no curvepiece encloses it, its own nesting number.

The complexity of this function is as follows:
- in the worst case, with `n` edge endpoints, all curvepieces are nested, requiring `n/2` passes
through the outer loop to assign all `n/2` curvepieces
- the inner loop is `O(n)` on each pass, considering building `unassigned`, iterating through
1:m, and iterating through the `between` loop are all `O(n)`
- therefore, it is `O(n^2)` in time complexity
- in terms of space complexity, `all_edge_erefs`, `assigned`, `nesting`, `max_enc`, `ee_ids`
are all `O(n)` persistent datastructures in the function
- `unassigned`, `consumed`, and `newly_assigned` are also all `O(n)` datastructures, whose memory
is reallocated at the beginning of each loop
- therefore, it is `O(n)` in space complexity
I'm not exactly sure how memory allocations play into things, but there may be some significant
effects there...hopefully not.
"""
function calculate_nesting_hierarchy(t::Tile)
    # get all edge-to-edge curvepiece ids
    ee_ids = Set(
        cp_id for cp_id in curvepiece_ids(t)
        if let cp = curvepiece(t, cp_id)
            cp.endpoint1 isa EdgeEndpoint && cp.endpoint2 isa EdgeEndpoint
        end
    )

    # get ordered list of all endpointrefs on the edges, including anyon-to-edge ones
    # (anyon-to-edge endpoints are kept in to preserve the positional barriers they form
    # between ee endpoints on opposite sides of the anyon radial line)
    all_edge_erefs = edge_erefs(t)
    n = length(all_edge_erefs)

    # track nesting number assignment per endpoint or curvepiece
    assigned = falses(n)                                # mask for if endpoint has a nesting number
    nesting  = Dict{Int,Int}()                          # nesting number
    max_enc  = Dict{Int,Int}(id => -1 for id in ee_ids) # max enclosing number

    # rounds of assigning hierarchy numbers
    round = 1
    while true
        # list of edge-to-edge endpoints lacking an assigned nesting number, along with anyon-to-edge
        # endpoints which act as barriers
        unassigned = [(i, all_edge_erefs[i]) for i in 1:n if !assigned[i]]
        length(nesting) == length(ee_ids) && break # we're done, all ee endpoints assigned

        # we'll scan through the initially unassigned endpoints, assigning consecutive pairs
        m = length(unassigned)
        consumed        = falses(m) # if we assigned this initially unassigned endpoint during this round
        newly_assigned  = Int[]     # endpoints which were assigned this round

        for k in 1:m
            # skip if we already assigned this or the next k value
            consumed[k] && continue
            nk = mod1(k + 1, m)
            consumed[nk] && continue
            # if the two consecutive unassigned endpoints are not on the same curvepiece, skip
            orig_i, eref_i = unassigned[k]
            orig_j, eref_j = unassigned[nk]
            eref_i.cp_id == eref_j.cp_id || continue
            # set the number number for this curvepiece
            nesting[eref_i.cp_id] = round
            # indices between orig_i and orig_j going clockwise, with wraparound
            between = orig_i < orig_j ? ((orig_i + 1):(orig_j - 1)) :
                                        Iterators.flatten(((orig_i + 1):n, 1:(orig_j - 1)))
            # set the max enclosing number for all entries between the ones just assigned
            for b in between
                bid = all_edge_erefs[b].cp_id
                if haskey(nesting, bid) max_enc[bid] = round end
            end
            # mark these two as assigned
            consumed[k] = consumed[nk] = true
            push!(newly_assigned, orig_i, orig_j)
        end

        for i in newly_assigned; assigned[i] = true; end
        round += 1
    end

    # update maximally enclosing curvepiece values from the -1 initial value
    max_enc = Dict(id => max_enc[id] == -1 ? nesting[id] : max_enc[id] for id in ee_ids)

    # dictionary mapping curvepiece_id to nesting and max enclosing numbers
    Dict(id => (nesting[id], max_enc[id]) for id in ee_ids)
end

###############################################################################
# INTERNAL MUTATORS
###############################################################################

"""Return the next cp_id to be assigned."""
function _allocate_cp_id!(t::Tile)
    id = t._next_cp_id[]
    t._next_cp_id[] += 1
    id
end

"""
Set the stored location of a `CurvepieceEndpoint` of a `Curvepiece`.

There are two cases:
- `eref` refers to an `EdgeEndpoint`, whose edge and position are then set, while
its direction is preserved
- `eref` refers to an `AnyonEndpoint`, which is converted to an `EdgeEndpoint` with
the specified edge and position values; its direction is set in accordance with the
other edge endpoint so that the curvepiece is valid (ie the direction is the opposite
of the extant edge endpoint)

This function is useful to call on `EndpointRef`s whose locations have been
shifted along an edge as a result of other curvepiece endpoints being added/
moved/removed. Updating the location after these shifts is necessary because
endpoint locations are relative to all endpoints present rather than absolute.

This function does not change the direction of a curvepiece. Therefore, the
ordering of the endpoints in the curvepiece does not change, so no revalidation
or reordering is needed.

Returns nothing.
"""
function _set_endpoint_location!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    cp = curvepiece(t, eref.cp_id)
    ep = endpoint(cp, eref)
    if ep isa EdgeEndpoint
        # the new endpoint has the same direction but different location
        new_ep = EdgeEndpoint(ep.direction, edge, pos)
    else
        # find new ep's direction based on whether the anyon endpoint was first/second
        direction = eref.endpoint_idx == 1 ? IN : OUT
        new_ep = EdgeEndpoint(direction, edge, pos)
    end
    # find which endpoint eref refers to, then replace that one with the new endpoint
    eps = eref.endpoint_idx == 1 ? (new_ep, cp.endpoint2) : (cp.endpoint1, new_ep)
    t._curvepieces[eref.cp_id] = Curvepiece(cp.curve_id, cp.anyon_count, eps...)
    nothing
end

"""Insert `eref` into edge `edge` at position `pos`, shifting subsequent endpoint locations up."""
function _insert_edge_eref!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    erefs = t._edge_endpoints[edge] # this is a hot path, so avoid collect() allocation in edge_erefs()
    # shift all endpoints above the insertion point to have positions incremented by 1
    for oldendpointpos in pos:length(erefs)
        _set_endpoint_location!(t, erefs[oldendpointpos], edge, oldendpointpos + 1)
    end
    # insert eref at pos
    insert!(erefs, pos, eref)
end

"""Remove EndpointRef at position `pos` in edge `edge`, shifting subsequent endpoint locations down."""
function _remove_edge_eref!(t::Tile, edge::Int, pos::Int)
    erefs = t._edge_endpoints[edge] # this is a hot path, so avoid collect() allocation in edge_erefs()
    deleteat!(erefs, pos) # remove eref at pos
    # shift all endpoints above the removal point to have positions equal to their index in the array
    for newendpointpos in pos:length(erefs)
        _set_endpoint_location!(t, erefs[newendpointpos], edge, newendpointpos)
    end
end

"""Pushes an EndpointRef onto the anyon. Errors if this would result in more than 2 endpoints on the anyon."""
function _push_anyon_eref!(t::Tile, eref::EndpointRef)
    length(t._anyon_endpoints) < 2 || throw(ArgumentError("cannot add another EndpointRef to the anyon"))
    push!(t._anyon_endpoints, eref)
end

"""Removes an EndpointRef from the anyon."""
function _remove_anyon_eref!(t::Tile, eref::EndpointRef)
    delete!(t._anyon_endpoints, eref)
end
