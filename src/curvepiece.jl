"""
Every `CurvepieceEndpoint` has an `EndpointDirection`, which will either be `IN`
to or `OUT` of a tile/anyon, if the endpoint is located on a tile edge/anyon
respectively.
"""
@enum EndpointDirection IN OUT

"""
Every `Curvepiece` has two `CurvepieceEndpoint`s, where either
- both are located on tile edges
- one is located on an edge and the other is located on an anyon

A `CurvepieceEndpoint`'s '**curvepiece partner**' is the other `CurvepieceEndpoint`
in the same curvepiece.

A `Curvepiece` is traversed in a certain direction, inherited from the traversal
direction of its `Curve`. Therefore, its endpoints have a natural ordering, with
one coming first and the other coming last. See `_is_ordered` for more.

A `Curvepiece` is completely defined by the locations of its endpoints, as the
body of each curvepiece can be freely deformed within the tile without affecting
the `Curve` the curvepiece is a part of, as long as its endpoints remain fixed
location-wise (and it does not intersect any other curvepieces, ensuring that the
overall curve diagram has no intersections).
"""
abstract type CurvepieceEndpoint end

"""
An `EdgeEndpoint` has a `direction` and a location, the latter consisting of:
- `edge`, which edge of the tile the endpoint is on
- `pos`, the clockwise position of the endpoint along the edge: for example, if
there are three endpoints on an edge, then traversing clockwise they will have
`pos` = 1, 2, and 3 respectively

The relative ordering of edge endpoints is very important, as careless swapping
of endpoints could lead to two curvepieces intersecting. Note that the `pos`
of an endpoint is not absolute, but is relative to the other endpoints present
on that edge, which means it can change during tile mutation.
"""
struct EdgeEndpoint <: CurvepieceEndpoint
    direction::EndpointDirection
    edge::Int
    pos::Int
    function EdgeEndpoint(direction::EndpointDirection, edge::Int, pos::Int)
        edge >= 0 || throw(ArgumentError("edge must be >= 0, got $edge"))
        pos >= 0 || throw(ArgumentError("pos must be >= 0, got $pos"))
        new(direction, edge, pos)
    end
end

"""
An `AnyonEndpoint` has a `direction`, but no location information, because
there isn't any ordering of the endpoints on an anyon (like there is with
endpoints on an edge).
"""
struct AnyonEndpoint <: CurvepieceEndpoint
    direction::EndpointDirection
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
Partial order (on valid endpoint pairs) that reflects how a pair of curvepiece
endpoints would be encountered while traversing a `Curve` through a tile. This
ordering is entirely determined by the endpoints' types and directions.

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
A `Curvepiece` is a piece of a `Curve` that lies inside a tile. Each has
two `CurvepieceEndpoints`, and must either:
- pass through the tile completely, meaning both of its endpoints are on edges
- go to the anyon from the tile edge, or vice versa, meaning one endpoint is on
an edge and one is on the anyon

These two types of curvepieces are called '**boundary**' and '**central**'
curvepieces respectively, where central curvepieces may be '**incoming**' or
'**outgoing**', going from the edge to the anyon or vice versa respectively.

`Curve`s have a traversal direction, which curvepieces inherit. This in turn
means that their endpoints are ordered. See `_is_ordered` for more. The first/
econd endpoints encountered in forward-traversal of the curvepiece `cp` can be
found with `first(cp)`/`last(cp)` respectively.

Fields:
- `curve_id`, an id specifying which curve the curvepiece is part of
- `anyon_count`, which specifies which anyon in the curve diagram this curvepiece
  comes after: that is, when traversing a curve diagram, any curve pieces after
  encountering the nth anyon will have an `anyon_count` of n; see `Curve` for more
- `endpoints`, a 2-tuple of the curvepiece's two `CurvepieceEndpoints`, stored
in forward-traversal order

Note that the '**curvepiece partner**' of `endpoints[1]` is `endpoints[2]`, and
vice versa.
"""
struct Curvepiece
    curve_id::Int
    anyon_count::Int
    endpoints::NTuple{2, CurvepieceEndpoint}
    # validates the endpoint pair and stores them in forward-traversal order
    function Curvepiece(curve_id::Int, anyon_count::Int,
                        a::CurvepieceEndpoint, b::CurvepieceEndpoint)
        anyon_count >= 1 || throw(ArgumentError("anyon_count must be >= 1, got $anyon_count"))
        _validate_endpoints(a, b)
        ep1, ep2 = _is_ordered(a, b) ? (a, b) : (b, a)
        new(curve_id, anyon_count, (ep1, ep2))
    end
end

# so we add the methods to Base rather than shadowing in the module namespace
import Base: first, last

"""Return the first endpoint of `cp`."""
@inline first(cp::Curvepiece) = first(cp.endpoints)

"""Return the last endpoint of `cp`."""
@inline last(cp::Curvepiece) = last(cp.endpoints)

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
- for cases 3 & 4 the new endpoint's direction will be the same as the staying
one's direction

This function is useful:
- when a curvepiece's endpoint location is shifted along an edge due to other
endpoints being added/removed before it on that edge; updating the location after
these shifts is necessary because endpoint locations are relative to all endpoints
present rather than absolute
- when a `CurvepieceEndpoint` has been moved from the anyon to the edge (or vice
versa)
"""
function change_endpoint_location(
    cp::Curvepiece, endpoint_idx::Int,
    edge::Union{Nothing,Int}, pos::Union{Nothing,Int}
)
    endpoint_idx ∈ (1, 2) || throw(ArgumentError("endpoint_idx must be 1 or 2, got $endpoint_idx"))
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
    new_eps = endpoint_idx == 1 ? (new_ep, last(cp)) : (first(cp), new_ep)
    # case 6 errors here
    Curvepiece(cp.curve_id, cp.anyon_count, new_eps...)
end
