"""
A curvepiece endpoint's direction will either be into or out of a tile, or into
or out of an anyon, if the endpoint is located on an edge or on an anyon
respectively.
"""
@enum EndpointDirection IN OUT

"""
Every curvepiece has two endpoints which either
- are both located on tile edges
- have one located on an edge and one located on an anyon
An endpoint's 'curvepiece partner' is the other endpoint in the same curvepiece.

A curvepiece is completely defined by the locations of its endpoints, as the body
of each curvepiece can be freely deformed within the tile without affecting the
curve diagram the curvepiece is a part of, as long as its endpoints remain fixed
and it does not intersect any other curvepieces.
"""
abstract type CurvepieceEndpoint end

"""
An anyon endpoint has a `direction`, but no location information, because
there isn't any ordering of the endpoints on an anyon like there is with
endpoints on an edge.
"""
struct AnyonEndpoint <: CurvepieceEndpoint
    direction::EndpointDirection
end

"""
An edge endpoint has a `direction` and a location, consisting of:
- `edge`, which edge of the tile the endpoint is on
- `pos`, the clockwise position of the endpoint along the edge: for example, if
there are three endpoints on an edge, then traversing clockwise they will have
`pos` = 1, 2, and 3 respectively

The relative ordering of edge endpoints is very important, as careless swapping
of endpoints could lead to two curvepieces intersecting. Note that the position
of an endpoint is not absolute, but is relative to the other endpoints present
on that edge, which means it can change during tile mutation.
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
Partial order (on valid endpoint pairs) that reflects how an endpoint would be
encountered while traversing a curve diagram through the tile.

Valid pair possibilities and their orders:
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
A curvepiece is a piece of a curve diagram that lies inside a tile. Each curvepiece
has
- `curve_id`, a unique id specifying which curve diagram the curvepiece is part of
- `anyon_count`, which specifies which anyon in the curve diagram this curvepiece
  comes after: that is, when traversing a curve diagram, any curve pieces after
  encountering the nth anyon will have an `anyon_count` of n

In addition, each curvepiece has two endpoints which are stored in the order they
are encountered while traversing the curve diagram, in the 2-tuple `endpoints`.
The '**curvepiece partner**' of `endpoints[1]` is `endpoints[2]`, and vice versa.

A curvepiece must either
- pass through a tile completely, so both of its endpoints are on edges
- go to the anyon from the tile edge, or vice versa, so one endpoint is on an
edge and one is on the anyon

These two types of curvepieces are called '**boundary**'/'**central**' curvepieces
respectively, where central curvepieces may be '**incoming**' or '**outgoing**',
going from the edge to the anyon or vice versa respectively.

Each curvepiece in a tile has an id unique to the curvepieces in that tile. This
value is used as a key to lookup the curvepiece struct associated with each
curvepiece, and therefore access its metadata. Other than the curvepiece id,
a `Curvepiece` struct stores all of the information about a specific curvepiece.
"""
struct Curvepiece
    curve_id::Int
    anyon_count::Int
    endpoints::NTuple{2, CurvepieceEndpoint}
    # validates the endpoint pair and stores them in forward-traversal order
    function Curvepiece(curve_id::Int, anyon_count::Int,
                        a::CurvepieceEndpoint, b::CurvepieceEndpoint)
        _validate_endpoints(a, b)
        ep1, ep2 = _is_ordered(a, b) ? (a, b) : (b, a)
        new(curve_id, anyon_count, (ep1, ep2))
    end
end

"""
Return a new `Curvepiece` which is the result of changing the location of `cp`'s
`endpoint_idx`th endpoint (the 'moving' endpoint), while leaving the other (the
'staying' endpoint) unchanged. The new endpoint (the 'target' endpoint) has location
`(edge, pos)`, unless either `edge` or `pos` are `nothing`, in which case its new
location is on the anyon.

There are 6 total cases which can be characterized according to the types (A for
AnyonEndpoint and E for EdgeEndpoint) of the (staying, moving -> target) endpoints:
1. E, E -> E
2. E, A -> E
3. E, E -> A
4. A, E -> E
5. E, A -> A
6. A, E -> A

Case 5 is always a no-op, and case 6 is always illegal, resulting in an error.
Cases 1 and 2 result in boundary curvepieces, while cases 3 and 4 result in a
new central curvepiece.

This function does not change the direction of a curvepiece. Therefore, the
ordering of the endpoints in the curvepiece does not change. That being said, the
direction of the target endpoint will need to be set in order to ensure that the
curvepiece direction is preserved and the curvepiece is valid:
- for cases 1 & 2, the new endpoint's direction will be opposite the staying one's
direction
- for cases 3 & 4 the new endpoint's direction will be the same as the staying one's
direction

This function is useful:
- when a curvepiece's endpoint location is shifted along an edge due to other
endpoints being added/removed before it on that edge; updating the location after
these shifts is necessary because endpoint locations are relative to all endpoints
present rather than absolute
- when an `Endpoint` has been moved from the anyon to the edge (or vice versa)
"""
function change_endpoint_location(cp::Curvepiece, endpoint_idx::Int, edge::Union{Nothing,Int}, pos::Union{Nothing,Int})
    ep_moving = cp.endpoints[endpoint_idx]
    if ep_moving isa EdgeEndpoint
        if edge === nothing || pos === nothing
            # cases 3 & 6, E -> A, direction doesn't matter for 6
            # direction is opposite the moving one's, i.e. same as the staying one's
            direction = ep_moving.direction == IN ? OUT : IN
            new_ep = AnyonEndpoint(direction)
        else
            # case 1, E -> E, preserve direction but different location
            new_ep = EdgeEndpoint(ep_moving.direction, edge, pos)
        end
    else
        # no-op case 5 early return
        if edge === nothing || pos === nothing return cp end
        # cases 2 & 4, A -> E, find cp direction from whether moving was
        # first/second in cp, then preserve that direction
        direction = endpoint_idx == 1 ? IN : OUT
        new_ep = EdgeEndpoint(direction, edge, pos)
    end
    # find which endpoint eref refers to, then replace that one with new endpoint
    new_eps = endpoint_idx == 1 ? (new_ep, cp.endpoints[2]) : (cp.endpoints[1], new_ep)
    # case 6 errors here
    Curvepiece(cp.curve_id, cp.anyon_count, new_eps...)
end
