"""
A curvepiece endpoint's direction will either be into or out of a tile, or
into or out of an anyon, if the endpoint is located on an edge or on an anyon
respectively.
"""
@enum EndpointDirection IN OUT

"""
Every curvepiece has two endpoints which either
- are both located on tile edges
- have one located on an edge and one located on an anyon
An endpoint's 'partner' is the other endpoint in the same curvepiece.
"""
abstract type CurvepieceEndpoint end

"""
An anyon endpoint has a `direction`, but no location information, because
there isn't any ordering of the endpoints on an anyon, like there is with
endpoints on an edge.
"""
struct AnyonEndpoint <: CurvepieceEndpoint
    direction::EndpointDirection
end

"""
An edge endpoint has a `direction` and a location, including:
- `edge`, which edge of the tile the endpoint is on
- `pos`, the clockwise position of the endpoint along the edge:
    that is, if there are three endpoints on an edge, then
    traversing clockwise they will have `pos` = 1, 2, and 3 respectively

We track the ordering of endpoints on an edge because curve diagrams must be planar
(non-intersecting), but can otherwise be deformed freely. Careless swapping of endpoints
would lead to two curve pieces intersecting. Note that the position of an endpoint is
relative to the other endpoints present on that edge rather than absolute, which means it
can change during tile mutation.
"""
struct EdgeEndpoint <: CurvepieceEndpoint
    direction::EndpointDirection
    edge::Int
    pos::Int
end

"""
Throws an error if endpoints `a` and `b` cannot be on the same curvepiece.

Endpoints on a curvepiece cannot:
- be both on edges and have the same directions (both IN or both OUT)
- be both on anyons
- be one on an anyon and one on an edge, and have differing directions
"""
function _validate_endpoints(a::CurvepieceEndpoint, b::CurvepieceEndpoint)
    (a isa EdgeEndpoint && b isa EdgeEndpoint && a.direction == b.direction) &&
        throw(ArgumentError("two edge endpoints must have opposing directions"))
    (a isa AnyonEndpoint && b isa AnyonEndpoint) &&
        throw(ArgumentError("curvepiece cannot have two anyon endpoints"))
    ((a isa AnyonEndpoint || b isa AnyonEndpoint) && a.direction != b.direction) &&
        throw(ArgumentError("edge and anyon endpoints must have the same direction"))
end

"""
Partial order on valid endpoint pairs, that reflects how an endpoint would be encountered
while traversing a curve diagram through the tile. Valid pair possibilities and their orders:
- Edge(IN) before Edge(OUT)
- Edge(IN) before Anyon(IN)
- Anyon(OUT) before Edge(OUT)
"""
function _is_ordered(a::CurvepieceEndpoint, b::CurvepieceEndpoint)
    a isa EdgeEndpoint && b isa EdgeEndpoint && return a.direction == IN
    a.direction == IN  && return a isa EdgeEndpoint
    a.direction == OUT && return a isa AnyonEndpoint
end

"""
A curvepiece is a piece of a curve diagram that lies inside a tile. Each curvepiece has
- `curve_id`, a unique id specifying which curve diagram the curvepiece is part of
- `position_in_curve`, which specifies which anyon in the curve diagram this curve piece
  comes after: that is, when traversing a curve diagram, any curve pieces after encountering
  the nth anyon will have a `position_in_curve` of n.
In addition, each curvepiece has two endpoints, `endpoint1` and `endpoint2`, which are stored in
the order they are encountered while traversing the curve diagram. The 'partner' of `endpoint1`
is `endpoint2`, and vice versa.

A curvepiece must either pass through a tile completely, meaning its first endpoint is at an edge
and its second endpoint is at an edge, or must pass from outside the tile to the tile's anyon, or
from the tile's anyon to the outside; in these latter scenarios one of the endpoints is on an edge
and one of them is on an anyon.

Each curvepiece in a tile has an id unique to the curvepieces in that tile. This value is used as a
key to lookup the curvepiece struct associated with each curvepiece, and therefore access its metadata.
Other than the curvepiece id, `Curvepiece` structs store all of the information about each curvepiece.
"""
struct Curvepiece
    curve_id::Int
    position_in_curve::Int
    endpoint1::CurvepieceEndpoint
    endpoint2::CurvepieceEndpoint
    # validates the endpoint pair and stores them in forward-traversal order
    function Curvepiece(curve_id::Int, position_in_curve::Int,
                        a::CurvepieceEndpoint, b::CurvepieceEndpoint)
        _validate_endpoints(a, b)
        ep1, ep2 = _is_ordered(a, b) ? (a, b) : (b, a)
        new(curve_id, position_in_curve, ep1, ep2)
    end
end

"""
A reference to a curvepiece endpoint: contains the curvepiece's tile-unique id
`cp_id` and `endpoint_idx`, the index of the endpoint in the curvepiece (whether it
comes first or second).
"""
struct EndpointRef
    cp_id::Int
    endpoint_idx::Int  # 1 or 2, for Curvepiece.endpoint1/endpoint2
end

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
the simulation, meaning we could end up with an extremely large and sparse array of `nothing`
stored densely, if we did not use a `Dict`.

A tile can have any number of edges `n_edges`, which is the sole parameter for the constructor.
For each edge, we store a vector of `EndpointRef`s in the order the endpoints are encountered
when walking along the edges of the tile clockwise. This allows backward-lookups from endpoint
location to curvepiece struct. All of these vectors of `EndpointRef`s are themselves stored in
the vector `_edge_endpoints`, which has a length equal to `n_edges`.

This design pattern reflects the need to support two data access patterns:
- given the id of a curvepiece, we want to obtain the endpoint locations
- given the endpoint locations of a curvepiece, we want to obtain the curvepiece information
We also generally want to store all of the information about a curvepiece in one centralized
datastructure, and then for any 'backwards-lookups' or other data access patterns not supported
by the chosen data structure, store lightweight references to enable them.

The alternative would be something like storing the endpoint objects in the edge endpoint lists,
and then storing an index into this list (which would therefore encode the location) in each
`Curvepiece`, which leads to the data being spread across two different datastructures, which is
less clean and adds layers of indirection when trying to perform lookups.

Finally, 0, 1, or 2 endpoints can be located at the anyon in each tile. These endpoints are
stored in `_anyon_endpoints`.
"""
struct Tile
    _next_cp_id::Ref{Int}
    _curvepieces::Dict{Int, Curvepiece}
    _edge_endpoints::Vector{Vector{EndpointRef}}
    _anyon_endpoints::Set{EndpointRef}
    Tile(n_edges::Int) = new(Ref(1), Dict{Int, Curvepiece}(), [EndpointRef[] for _ in 1:n_edges], Set{EndpointRef}())
end

### PUBLIC GETTERS ###

"""The number of edges in the tile `t`."""
num_edges(t::Tile) = length(t._edge_endpoints)

"""The next edge number after edge `edge` in the tile `t`."""
next_edge(t::Tile, edge::Int) = mod1(edge + 1, num_edges(t))

"""The prev edge number after edge `edge` in the tile `t`."""
prev_edge(t::Tile, edge::Int) = mod1(edge - 1, num_edges(t))

"""Whether the edge `edge` in tile `t` has any endpoints on it."""
has_endpoints(t::Tile, edge::Int) = !isempty(t._edge_endpoints[edge])

"""The number of endpoints present on edge `edge` in `t`."""
num_endpoints(t::Tile, edge::Int) = length(t._edge_endpoints[edge])

"""Number of curvepieces with an endpoint at the tile's anyon."""
num_anyon_curvepieces(t::Tile) = length(t._anyon_endpoints)

"""Whether this curvepiece has an anyon endpoint."""
is_anyon_curvepiece(t::Tile, cp_id::Int) = get_anyon_EndpointRef(t, cp_id) != nothing

"""Gets the sorted list of all curvepiece ids present in `t`."""
curvepiece_ids(t::Tile) = sort(collect(keys(t._curvepieces)))

"""Gets the curvepiece with id `cp_id` inside of `t`."""
get_curvepiece(t::Tile, cp_id::Int) = t._curvepieces[cp_id]

"""Gets the endpoint in `t` pointed to by `eref`."""
get_endpoint(t::Tile, eref::EndpointRef) =
    eref.endpoint_idx == 1 ? t._curvepieces[eref.cp_id].endpoint1 : t._curvepieces[eref.cp_id].endpoint2

"""Gets the EndpointRef for the `pos`th endpoint located on edge `edge` in tile `t`."""
get_edge_EndpointRef(t::Tile, edge::Int, pos::Int) = t._edge_endpoints[edge][pos]

"""Gets a clockwise-ordered list of all EndpointRefs located on edge `edge` of tile `t`."""
get_edge_EndpointRefs(t::Tile, edge::Int) = collect(t._edge_endpoints[edge])

"""Gets a clockwise-ordered list of all EndpointRefs located on the edges of tile `t`."""
get_edge_EndpointRefs(t::Tile) = cat([get_edge_EndpointRefs(t, i) for i in 1:num_edges(t)]...; dims=1)

"""Gets a list of all the EndpointRefs for all endpoints located on the anyon in tile `t`."""
get_anyon_EndpointRefs(t::Tile) = collect(t._anyon_endpoints)

"""Gets an EndpointRef to the partner of the endpoint that `eref` is pointing to."""
get_partner_EndpointRef(eref::EndpointRef) = EndpointRef(eref.cp_id, 3 - eref.endpoint_idx)

"""Whether the partner of `eref` is an `EdgeEndpoint`."""
has_edge_partner(t::Tile, eref::EndpointRef) =
    get_endpoint(t, get_partner_EndpointRef(eref)) isa EdgeEndpoint

"""Whether the partner of `eref` is an `AnyonEndpoint`."""
has_anyon_partner(t::Tile, eref::EndpointRef) =
    get_endpoint(t, get_partner_EndpointRef(eref)) isa AnyonEndpoint

"""
If `cp_id`'s curvepiece has an endpoint at `t`'s anyon, returns the EndpointRef for that endpoint.
Otherwise, returns `nothing`.
"""
function get_anyon_EndpointRef(t::Tile, cp_id::Int)
    for eref in t._anyon_endpoints
        eref.cp_id == cp_id && return eref
    end
    nothing
end

"""
Returns the `curve_id` of the curvepieces which have endpoints on the anyon, `nothing` if there are
no such curvepieces. If there are two curvepieces with endpoints on the anyon, note that they must
have the same `curve_id`.
"""
function anyon_curve_id(t::Tile)
    erefs = get_anyon_EndpointRefs(t)
    erefs == nothing && return nothing
    cp = get_curvepiece(t, first(erefs).cp_id)
    cp.curve_id
end

"""
Returns the `EndpointRef` of the endpoint next encountered while traversing edge `edge` of `t` *clockwise*
starting at position `pos`. Returns `nothing` if there is no further endpoint on that edge.
"""
function next_EndpointRef_on_edge(t::Tile, edge::Int, pos::Int)
    endpoints = t._edge_endpoints[edge]
    pos < length(endpoints) ? endpoints[pos + 1] : nothing
end

"""
Returns the `EndpointRef` of the endpoint next encountered while traversing edge `edge` of `t` *counterclockwise*
starting at position `pos`. Returns `nothing` if there is no further endpoint on that edge.
"""
function prev_EndpointRef_on_edge(t::Tile, edge::Int, pos::Int)
    endpoints = t._edge_endpoints[edge]
    pos > 1 ? endpoints[pos - 1] : nothing
end

"""
Gets the `EndpointRef` of the endpoint next encountered when traversing `t`s edges *clockwise* starting at
position `pos` on edge `edge`.

If there is only one endpoint attached to the edges of the tile (for example, in the case where there is just
one curvepiece with one end connected to the anyon), the `EndpointRef` returned will be the one at `edge`, `pos`.
"""
function next_EndpointRef(t::Tile, edge::Int, pos::Int)
    # try to return the next endpointref on the same edge, if it exists
    next = next_EndpointRef_on_edge(t, edge, pos)
    if next !== nothing return next end
    # traverse the remaining edges, returning the first endpoint on the first nonempty one found
    e = next_edge(t, edge)
    while e != edge
        if has_endpoints(t, e) return get_edge_EndpointRef(t, e, 1) end
        e = next_edge(t, e)
    end
    # we wrapped back around to the starting edge, so return the first endpoint on it
    get_edge_EndpointRef(t, edge, 1)
end

"""
Gets the `EndpointRef` of the endpoint next encountered when traversing `t`s edges *counterclockwise* starting
at position `pos` on edge `edge`.

If there is only one endpoint attached to the edges of the tile (for example, in the case where there is just
one curvepiece with one end connected to the anyon), the `EndpointRef` returned will be the one at `edge`, `pos`.
"""
function prev_EndpointRef(t::Tile, edge::Int, pos::Int)
    # try to return the next endpointref on the same edge, if it exists
    prev = prev_EndpointRef_on_edge(t, edge, pos)
    if prev !== nothing return prev end
    # traverse the remaining edges, returning the first endpoint on the first nonempty one found
    e = prev_edge(t, edge)
    while e != edge
        if has_endpoints(t, e) return get_edge_EndpointRef(t, e, num_endpoints(t, e)) end
        e = prev_edge(t, e)
    end
    # we wrapped back around to the starting edge, so return the last endpoint on it
    get_edge_EndpointRef(t, edge, num_endpoints(t, e))
end

### INTERNAL VALIDATION HELPERS ###

"""
Collects all `EndpointRef`s in the clockwise arc from `(edge1, pos1)` (inclusive) to
`(edge2, pos2)` (exclusive) on the boundary of `t`.
"""
function _EndpointRefs_between(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    arc = EndpointRef[]
    # if the arc is entirely contained within an edge
    if edge1 == edge2 && pos1 <= pos2
        for p in pos1:(pos2 - 1)
            push!(arc, get_edge_EndpointRef(t, edge1, p))
        end
    else
        # get endpoints on the remainder of edge1
        for p in pos1:num_endpoints(t, edge1)
            push!(arc, get_edge_EndpointRef(t, edge1, p))
        end
        # get all endpoints on intervening edges between edge1 and edge2
        e = next_edge(t, edge1)
        while e != edge2
            for p in 1:num_endpoints(t, e)
                push!(arc, get_edge_EndpointRef(t, e, p))
            end
            e = next_edge(t, e)
        end
        # get endpoints on the first part of the edge2
        for p in 1:(pos2 - 1)
            push!(arc, get_edge_EndpointRef(t, edge2, p))
        end
    end
    arc
end

"""Returns all `EndpointRef`s in `arc` whose partners are NOT also in `arc`."""
function _unpaired_EndpointRefs(arc::Vector{EndpointRef})
    arc_set = Set(arc)
    [eref for eref in arc if get_partner_EndpointRef(eref) ∉ arc_set]
end

"""
Validates that inserting an edge-to-edge curvepiece at `(edge1, pos1) → (edge2, pos2)` does not
cause curve pieces to intersect. Throws `ArgumentError` if the insertion is invalid. See
insert_curvepiece! for more details.
"""
function _validate_edge_to_edge_insertion(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int)
    arc      = _EndpointRefs_between(t, edge1, pos1, edge2, pos2)
    unpaired = _unpaired_EndpointRefs(arc)
    unpaired_edge_partners  = [eref for eref in unpaired if has_edge_partner(t, eref)]
    unpaired_anyon_partners = [eref for eref in unpaired if has_anyon_partner(t, eref)]

    if !isempty(unpaired_edge_partners)
        throw(ArgumentError(
            "insertion at ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "$(length(unpaired_edge_partners)) unpaired edge endpoint(s) in clockwise arc"))
    end
    n_anyon = length(unpaired_anyon_partners)
    if n_anyon == 1 && num_anyon_curvepieces(t) == 2
        throw(ArgumentError(
            "insertion at ($edge1,$pos1)→($edge2,$pos2) would intersect curves: " *
            "arc crosses exactly one of two anyon-curvepiece boundary points"))
    end
    # n_anyon == 0: valid; n_anyon == 1 with 1 anyon cp: valid; n_anyon == 2: valid
end

"""
Validates that inserting an edge-to-anyon curvepiece at `(edge, pos)` does not cause curve pieces
to intersect. Throws `ArgumentError` if the tile already has two anyon curvepieces, or if the
insertion would cause an existing edge-to-edge curvepiece to cross the resulting partition. See
insert_curvepiece! for more details.
"""
function _validate_edge_to_anyon_insertion(t::Tile, edge::Int, pos::Int)
    n = num_anyon_curvepieces(t)
    n == 2 && throw(ArgumentError(
        "tile already has two anyon curvepieces; cannot insert a third"))
    n == 0 && return  # first anyon curvepiece never causes intersections

    # n == 1: verify no edge-to-edge curvepiece crosses the partition the two anyon cps will form
    existing_anyon_eref = first(get_anyon_EndpointRefs(t))
    existing_edge_eref  = get_partner_EndpointRef(existing_anyon_eref)
    existing_endpoint = get_endpoint(t, existing_edge_eref)::EdgeEndpoint

    arc     = _EndpointRefs_between(t, edge, pos, existing_endpoint.edge, existing_endpoint.pos)
    unpaired = _unpaired_EndpointRefs(arc)

    if !isempty(unpaired)
        throw(ArgumentError(
            "anyon curvepiece insertion at ($edge,$pos) would intersect curves: " *
            "$(length(unpaired)) edge-to-edge curvepiece(s) cross the resulting partition"))
    end
end

"""
Validates that moving the endpoint referenced by `eref` to `(edge, pos)` does not cause
curvepieces to intersect. Throws `ArgumentError` if the move is invalid.

Validation is performed against the current state of the tile (before `eref` has been
removed from its old location), and mirrors the logic in `_validate_edge_to_edge_insertion`
and `_validate_edge_to_anyon_insertion`. `eref` is excluded from the arc when its old
position falls within the new arc, so the check is not confused by the endpoint's current
location.

For an edge-to-edge curvepiece:
The new partition runs clockwise from `(edge, pos)` to the partner's current position.
The move is invalid if:
- any other edge-to-edge curvepiece has one endpoint inside the arc and one outside, or
- there are two anyon curvepieces and exactly one of their edge endpoints lies inside the arc
  (which would mean the anyon partition and the new partition cross).

For an anyon-to-edge curvepiece:
The partition is formed by the new position together with the other anyon curvepiece's edge
endpoint. No partition is formed when there is only one anyon curvepiece, so such a move is
always valid. When there are two anyon curvepieces, the move is invalid if any edge-to-edge
curvepiece has one endpoint inside the resulting arc and one outside.
"""
function _validate_move(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    partner_eref = get_partner_EndpointRef(eref)
    partner_ep   = get_endpoint(t, partner_eref)

    if partner_ep isa EdgeEndpoint
        # Moving an edge-to-edge curvepiece endpoint.
        arc = _EndpointRefs_between(t, edge, pos, partner_ep.edge, partner_ep.pos)
        filter!(r -> r != eref, arc)   # eref may appear at its old position inside the new arc
        unpaired = _unpaired_EndpointRefs(arc)
        unpaired_edge_partners  = [r for r in unpaired if has_edge_partner(t, r)]
        unpaired_anyon_partners = [r for r in unpaired if has_anyon_partner(t, r)]

        if !isempty(unpaired_edge_partners)
            throw(ArgumentError(
                "move to ($edge,$pos) would intersect curves: " *
                "$(length(unpaired_edge_partners)) unpaired edge endpoint(s) in clockwise arc"))
        end
        n_anyon = length(unpaired_anyon_partners)
        if n_anyon == 1 && num_anyon_curvepieces(t) == 2
            throw(ArgumentError(
                "move to ($edge,$pos) would intersect curves: " *
                "arc crosses exactly one of two anyon-curvepiece boundary points"))
        end
    else
        # Moving an anyon-to-edge curvepiece endpoint.
        # A partition only forms when two anyon curvepieces are present.
        num_anyon_curvepieces(t) == 1 && return

        other_anyon_eref = first(r for r in get_anyon_EndpointRefs(t) if r.cp_id != eref.cp_id)
        other_edge_eref  = get_partner_EndpointRef(other_anyon_eref)
        other_edge_ep    = get_endpoint(t, other_edge_eref)::EdgeEndpoint

        arc = _EndpointRefs_between(t, edge, pos, other_edge_ep.edge, other_edge_ep.pos)
        filter!(r -> r != eref, arc)
        unpaired = _unpaired_EndpointRefs(arc)

        if !isempty(unpaired)
            throw(ArgumentError(
                "anyon curvepiece move to ($edge,$pos) would intersect curves: " *
                "$(length(unpaired)) edge-to-edge curvepiece(s) cross the resulting partition"))
        end
    end
end

### INTERNAL MUTATORS ###

"""Returns the next cp_id to be assigned."""
function _allocate_cp_id!(t::Tile)
    id = t._next_cp_id[]
    t._next_cp_id[] += 1
    id
end

"""
Replaces the stored location (edge and pos) of one endpoint within a `Curvepiece`.

This function should be called for `EndpointRefs` whose locations have been shifted
as a result of other curvepiece endpoints being added/moved/removed. This is
necessary because endpoint locations are relative to all of the endpoints present
rather than being absolute. Note that this means `eref` must point to an `EdgeEndpoint`,
as `AnyonEndpoint`s do not have a location.

The direction or endpoint type (edge vs anyon) of the endpoint indicated by `eref`,
and its partner, does not change as a result of mutating other curvepieces. Therefore,
the ordering of the endpoints in the curvepiece does not change, so no revalidation
or reordering is needed.
"""
function _set_endpoint_location!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    ep::EdgeEndpoint = get_endpoint(t, eref)
    cp = get_curvepiece(t, eref.cp_id)
    if eref.endpoint_idx == 1
        t._curvepieces[eref.cp_id] = Curvepiece(cp.curve_id, cp.position_in_curve,
            EdgeEndpoint(ep.direction, edge, pos), cp.endpoint2)
    else
        t._curvepieces[eref.cp_id] = Curvepiece(cp.curve_id, cp.position_in_curve,
            cp.endpoint1, EdgeEndpoint(ep.direction, edge, pos))
    end
end

"""
Replaces the stored pos of an endpoint within a `Curvepiece`.

Convenience wrapper for _set_endpoint_location! for the case when an endpoint has been
shifted along an edge, so only the pos needs to be updated.
"""
_update_endpoint_pos!(t::Tile, eref::EndpointRef, new_pos::Int) =
    _set_endpoint_location!(t, eref, (get_endpoint(t, eref)::EdgeEndpoint).edge, new_pos)

"""Insert `eref` into edge `edge` at position `pos`, shifting subsequent endpoint locations up."""
function _insert_edge_EndpointRef!(t::Tile, eref::EndpointRef, edge::Int, pos::Int)
    # shift all endpoints above the insertion point to have positions incremented by 1
    for oldendpointpos in pos:num_endpoints(t, edge)
        _update_endpoint_pos!(t, get_edge_EndpointRef(t, edge, oldendpointpos), oldendpointpos + 1)
    end
    # insert eref at pos
    insert!(t._edge_endpoints[edge], pos, eref)
end

"""Remove EndpointRef at position `pos` in edge `edge`, shifting subsequent endpoint locations down."""
function _remove_edge_EndpointRef!(t::Tile, edge::Int, pos::Int)
    # remove eref at pos
    deleteat!(t._edge_endpoints[edge], pos)
    # shift all endpoints above the removal point to have positions equal to their index in the array
    for newendpointpos in pos:num_endpoints(t, edge)
        _update_endpoint_pos!(t, get_edge_EndpointRef(t, edge, newendpointpos), newendpointpos)
    end
end

### PUBLIC MUTATORS ###

"""
Insert an edge-to-edge curvepiece. `edge1`, `pos1` is the IN endpoint, while `edge2`, `pos2` is the
OUT endpoint. Both positions are relative to the internal state at the time of the function call,
meaning that the caller should not 'adjust' for the fact that inserting one endpoint wil shift the
locations of endpoints. That is, if the two endpoints are on the same edge, `pos2 == pos1 + 1` would
lead to two endpoints, while `pos2 == pos1 + 2` would lead to endpoints separated by one intervening
endpoint.

This function validates attempted insertions against the current state of the tile to ensure that no
insertion leads to intersecting curve pieces. Note that each edge-to-edge curvepiece partitions the
tile into two parts. Note also that a pair of edge-to-anyon curvepieces also partitions the tile into
two parts. An insertion is only valid if, for any pair of parts formed by partitioning the tile in the
above ways, the insertion points of the new curvepiece both lie in the same part.

This validation can be done by checking the endpoints located between the two proposed insertion points;
note that an endpoint is 'unpaired' if it is between the insertion points but its partner is not:
- if there are no intervening unpaired endpoints, the insertion is valid
- if there are any intervening unpaired endpoints whose partners are on an edge, the insertion is invalid
- if there is one intervening unpaired endpoint whose partner is on the anyon, and there is only one
  curvepiece with an endpoint on the anyon in the tile, the insertion is valid
- if there is one intervening unpaired endpoint whose partner is on the anyon, and there are two
  curvepieces with endpoints on the anyon, the insertion is invalid
- if there are two intervening unpaired endpoints whose partners are on the anyon, the insertion is valid

Returns the `cp_id` of the created curvepiece.
"""
function insert_curvepiece!(t::Tile, curve_id::Int, position_in_curve::Int,
    edge1::Int, pos1::Int,
    edge2::Int, pos2::Int,
)
    _validate_edge_to_edge_insertion(t, edge1, pos1, edge2, pos2)
    cp_id = _allocate_cp_id!(t)
    # if both endpoints are on the same edge, inserting the first one shifts pos2
    pos2 = (edge1 == edge2 && pos1 <= pos2) ? pos2 + 1 : pos2
    cp = Curvepiece(curve_id, position_in_curve,
        EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2))
    t._curvepieces[cp_id] = cp
    _insert_edge_EndpointRef!(t, EndpointRef(cp_id, 1), edge1, pos1)
    _insert_edge_EndpointRef!(t, EndpointRef(cp_id, 2), edge2, pos2)
    cp_id
end

"""
Insert an edge-to-anyon curvepiece. The provided direction will apply to both endpoints. It
is an error to have more than two edge-to-anyon curvepieces in the same tile, so any insertions
which would lead to that will throw an error.

This function also validates attempted insertions against the current state of the tile to
ensure that no insertion leads to intersecting curve pieces. Note that a pair of anyon-to-edge
curvepieces partitions the tile into two parts. An insertion is invalid when it causes an existing
edge-to-edge curvepiece to have its endpoints in different parts of the resulting partition. This
means that an insertion of the first edge-to-anyon curvepiece in a tile will never be invalid, as
having only one edge-to-anyon curvepiece does not result in a tile partition.

Algorithmically, this condition can be checked by sweeping one part of the partition caused by
the proposed insertion and verifying that there are no unpaired endpoints, i.e. endpoints whose
partners are in the other part of the partition, for the edge-to-edge curvepieces.

Finally, this function ensures that both curvepieces connected to an anyon have the same `curve_id`.

Returns the `cp_id` of the created curvepiece.
"""
function insert_curvepiece!(t::Tile, edge::Int, pos::Int, direction::EndpointDirection,
                            curve_id::Int, position_in_curve::Int)
    if num_anyon_curvepieces(t) == 1
        existing = anyon_curve_id(t)
        existing != curve_id && throw(ArgumentError(
            "both anyon curvepieces must belong to the same curve; " *
            "existing curve_id=$existing, new curve_id=$curve_id"))
    end
    _validate_edge_to_anyon_insertion(t, edge, pos)
    cp_id = _allocate_cp_id!(t)
    # correct ordering occurs on construction
    cp = Curvepiece(curve_id, position_in_curve,
        EdgeEndpoint(direction, edge, pos), AnyonEndpoint(direction))
    t._curvepieces[cp_id] = cp
    # extract ordering from cp, then use it to construct endpointrefs
    edge_which  = cp.endpoint1 isa EdgeEndpoint ? 1 : 2
    anyon_which = 3 - edge_which
    _insert_edge_EndpointRef!(t, EndpointRef(cp_id, edge_which), edge, pos)
    push!(t._anyon_endpoints, EndpointRef(cp_id, anyon_which))
    cp_id
end

"""Remove the curvepiece with id `cp_id` from `t`, along with its EndpointRefs."""
function remove_curvepiece!(t::Tile, cp_id::Int)
    cp = t._curvepieces[cp_id]
    for (idx, ep) in enumerate((cp.endpoint1, cp.endpoint2))
        eref = EndpointRef(cp_id, idx)
        if ep isa EdgeEndpoint
            _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
        else
            delete!(t._anyon_endpoints, eref)
        end
    end
    delete!(t._curvepieces, cp_id)
    nothing
end

"""
Move an EdgeEndpoint to a new location. `new_pos` is relative to the internal state
at the time of the function call, meaning the caller should not 'adjust' for the fact that
locations will shift after removing the existing EndpointRef from the internal datastructures.

Validates attempted moves against the current internal state of the tile to ensure that no
movement leads to crossed curvepieces. Similarly to the validation described in the
insert_curvepiece! methods, moving a curvepiece endpoint results in moving a partition of
the tile.

For moving an edge-to-edge curvpiece:
We have to check that the new partition of the tile does not split the two endpoints
of any other edge-to-edge curvepiece into different parts of the partition, and that if there
are two anyon-to-edge curvepieces, both of their edge endpoints are inside the same partition.

For moving an anyon-to-edge curvepiece:
We have to check that the new partition of the tile does not split the two endpoints of any edge-
to-edge curvepiece into different parts of the partition.
"""
function move_endpoint!(t::Tile, eref::EndpointRef, new_edge::Int, new_pos::Int)
    ep::EdgeEndpoint = get_endpoint(t, eref)
    _validate_move(t, eref, new_edge, new_pos)
    _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
    # if moving to somewhere on the same edge, removing the original EndpointRef changes the insertion position
    new_pos = (new_edge == ep.edge && new_pos > ep.pos) ? new_pos - 1 : new_pos
    _insert_edge_EndpointRef!(t, eref, new_edge, new_pos)
    _set_endpoint_location!(t, eref, new_edge, new_pos)
    nothing
end

"""Update the curve-related metadata for a curvepiece after e.g. a merge or grow operation."""
function set_curvepiece_metadata!(t::Tile, cp_id::Int, curve_id::Int, position_in_curve::Int)
    cp = get_curvepiece(t, cp_id)
    t._curvepieces[cp_id] = Curvepiece(curve_id, position_in_curve, cp.endpoint1, cp.endpoint2)
    nothing
end
