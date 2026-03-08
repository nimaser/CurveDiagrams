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
- `pos`, the position of the endpoint along the edge:
    that is, if there are three endpoints on an edge, then
    traversing clockwise they will have `pos` = 1, 2, and 3 respectively

We track the ordering of endpoints on an edge because curve diagrams must be planar
(non-intersecting), but can otherwise be deformed freely. Careless swapping of endpoints
would lead to two curve pieces intersecting.
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
the order they are encountered while traversing the curve diagram.

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
structs, which contain all of the information about each curvepiece.

A tile can have any number of edges `n_edges`, which is the sole parameter for the constructor.
For each edge, we store a vector of `EndpointRef`s, which allows backward-lookups from endpoint
location to curvepiece struct. All of these vectors are themselves stored in the vector
`_edge_endpoints`, which has a length equal to `n_edges`.

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
    next_cp_id::Ref{Int}
    curvepieces::Dict{Int, Curvepiece}
    edge_endpoints::Vector{Vector{EndpointRef}}
    anyon_endpoints::Set{EndpointRef}
    Tile(n_edges::Int) = new(Ref(1), [EndpointRef[] for _ in 1:n_edges], Set{EndpointRef}(), Dict{Int, Curvepiece}())
end

# ---- getters ----

get_curvepiece(t::Tile, cp_id::Int) = t.curvepieces[cp_id]
get_curvepiece_ids(t::Tile) = sort(collect(keys(t.curvepieces)))

get_endpoint(t::Tile, eid::EndpointRef) =
    eid.endpoint_idx == 1 ? t.curvepieces[eid.cp_id].endpoint1 : t.curvepieces[eid.cp_id].endpoint2

get_other_EndpointRef(t::Tile, eid::EndpointRef) = EndpointRef(eid.cp_id, 3 - eid.endpoint_idx)

get_edge_EndpointRef(t::Tile, edge::Int, pos::Int) = t.edge_endpoints[edge][pos]

function get_anyon_EndpointRef(t::Tile, cp_id::Int)
    for eid in t.anyon_endpoints
        eid.cp_id == cp_id && return eid
    end
    error("curvepiece $cp_id has no anyon endpoint")
end

function adjacent_EndpointRefs(t::Tile, edge::Int, pos::Int)
    arr = t.edge_endpoints[edge]
    prev = pos > 1            ? arr[pos - 1] : nothing
    next = pos < length(arr)  ? arr[pos + 1] : nothing
    prev, next
end

edge_length(t::Tile, edge::Int) = length(t.edge_endpoints[edge])

# ---- internal setters ----

function _allocate_cp_id!(t::Tile)
    id = t.next_cp_id[]
    t.next_cp_id[] += 1
    id
end

# Replace the stored location (edge + pos) of one endpoint within a Curvepiece.
# Direction and ordering are unchanged, so no re-validation needed.
function _set_endpoint_location!(t::Tile, eid::EndpointRef, edge::Int, pos::Int)
    cp = t.curvepieces[eid.cp_id]
    if eid.endpoint_idx == 1
        ep = cp.endpoint1::EdgeEndpoint
        t.curvepieces[eid.cp_id] = Curvepiece(cp.curve_id, cp.position_in_curve,
            EdgeEndpoint(ep.direction, edge, pos), cp.endpoint2)
    else
        ep = cp.endpoint2::EdgeEndpoint
        t.curvepieces[eid.cp_id] = Curvepiece(cp.curve_id, cp.position_in_curve,
            cp.endpoint1, EdgeEndpoint(ep.direction, edge, pos))
    end
end

_update_endpoint_pos!(t::Tile, eid::EndpointRef, new_pos::Int) =
    _set_endpoint_location!(t, eid, (get_endpoint(t, eid)::EdgeEndpoint).edge, new_pos)

# Insert an EndpointRef into an edge array at pos, shifting subsequent entries up.
function _insert_edge_EndpointRef!(t::Tile, edge::Int, pos::Int, eid::EndpointRef)
    arr = t.edge_endpoints[edge]
    for i in pos:length(arr)
        _update_endpoint_pos!(t, arr[i], i + 1)
    end
    insert!(arr, pos, eid)
end

# Remove the EndpointRef at pos from an edge array, shifting subsequent entries down.
function _remove_edge_EndpointRef!(t::Tile, edge::Int, pos::Int)
    arr = t.edge_endpoints[edge]
    deleteat!(arr, pos)
    for i in pos:length(arr)
        _update_endpoint_pos!(t, arr[i], i)
    end
end

# Update curve metadata for a curvepiece (e.g. after merge or grow).
function set_curvepiece_metadata!(t::Tile, cp_id::Int, curve_id::Int, position_in_curve::Int)
    cp = t.curvepieces[cp_id]
    t.curvepieces[cp_id] = Curvepiece(curve_id, position_in_curve, cp.endpoint1, cp.endpoint2)
end

# ---- public mutators ----

# Insert an edge-to-edge curvepiece. edge1/pos1 is the IN endpoint, edge2/pos2 the OUT endpoint.
# Positions are relative to the current array state before insertion.
function insert_curvepiece!(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int,
                            curve_id::Int, position_in_curve::Int)
    cp_id = _allocate_cp_id!(t)
    # If both endpoints land on the same edge, inserting ep1 first shifts pos2.
    final_pos2 = (edge1 == edge2 && pos1 <= pos2) ? pos2 + 1 : pos2
    cp = Curvepiece(curve_id, position_in_curve,
        EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, final_pos2))
    t.curvepieces[cp_id] = cp
    _insert_edge_EndpointRef!(t, edge1, pos1,      EndpointRef(cp_id, 1))
    _insert_edge_EndpointRef!(t, edge2, final_pos2, EndpointRef(cp_id, 2))
    cp_id
end

# Insert an edge-to-anyon curvepiece. direction applies to both endpoints.
function insert_curvepiece!(t::Tile, edge::Int, pos::Int, direction::EndpointDirection,
                            curve_id::Int, position_in_curve::Int)
    cp_id = _allocate_cp_id!(t)
    cp = Curvepiece(curve_id, position_in_curve,
        EdgeEndpoint(direction, edge, pos), AnyonEndpoint(direction))
    t.curvepieces[cp_id] = cp
    edge_which  = cp.endpoint1 isa EdgeEndpoint ? 1 : 2
    anyon_which = 3 - edge_which
    _insert_edge_EndpointRef!(t, edge, pos, EndpointRef(cp_id, edge_which))
    push!(t.anyon_endpoints, EndpointRef(cp_id, anyon_which))
    cp_id
end

function remove_curvepiece!(t::Tile, cp_id::Int)
    cp = t.curvepieces[cp_id]
    for (idx, ep) in enumerate((cp.endpoint1, cp.endpoint2))
        eid = EndpointRef(cp_id, idx)
        if ep isa EdgeEndpoint
            _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
        else
            delete!(t.anyon_endpoints, eid)
        end
    end
    delete!(t.curvepieces, cp_id)
end

# Move an EdgeEndpoint to a new location. new_pos is relative to the array state after removal.
function move_endpoint!(t::Tile, eid::EndpointRef, new_edge::Int, new_pos::Int)
    ep = get_endpoint(t, eid)::EdgeEndpoint
    _remove_edge_EndpointRef!(t, ep.edge, ep.pos)
    # If removing from the same edge shifts the target position, adjust.
    ins_pos = (new_edge == ep.edge && new_pos > ep.pos) ? new_pos - 1 : new_pos
    _set_endpoint_location!(t, eid, new_edge, ins_pos)
    _insert_edge_EndpointRef!(t, new_edge, ins_pos, eid)
end
