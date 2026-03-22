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
- `anyon_count`, which specifies which anyon in the curve diagram this curve piece
  comes after: that is, when traversing a curve diagram, any curve pieces after encountering
  the nth anyon will have a `anyon_count` of n.
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
    anyon_count::Int
    endpoint1::CurvepieceEndpoint
    endpoint2::CurvepieceEndpoint
    # validates the endpoint pair and stores them in forward-traversal order
    function Curvepiece(curve_id::Int, anyon_count::Int,
                        a::CurvepieceEndpoint, b::CurvepieceEndpoint)
        _validate_endpoints(a, b)
        ep1, ep2 = _is_ordered(a, b) ? (a, b) : (b, a)
        new(curve_id, anyon_count, ep1, ep2)
    end
end
