### GEOMETRY HELPERS ###

"""Return the polar angle of `point` relative to origin."""
@inline _polar_angle(point::Point2) = atan(point[2], point[1])

"""Return the polar angle of `point` relative to `center`."""
@inline _polar_angle(point::Point2, center::Point2) = atan(point[2] - center[2], point[1] - center[1])

"""Normalize `angle` to the range 0 to 2π."""
@inline _normalize_angle(angle::Real) = mod(angle, 2π)

"""
Return the optimal angular traversal direction (clockwise vs counterclockwise) from
`angle1` to `angle2`, where optimal means the one with the shortest arc (smaller
angular span) which does not cross the angle `avoid`, if `avoid` is not nothing.

Takes account of input angles not being normalized to lie between `0` and `2π`.

Output is either `:cw` or `:ccw`, for clockwise and counterclockwise respectively.
Throws an error if `avoid` equals either `angle1` or `angle2`.
"""
function _traversal_direction(angle1::Real, angle2::Real, avoid::Union{Real, Nothing}=nothing)
    a1, a2 = _normalize_angle(angle1), _normalize_angle(angle2)
    # 'rotate' frame of reference so a1 is at origin
    a2_prime = _normalize_angle(a2 - a1)
    if avoid === nothing
        # traverse in the direction of the shorter arc
        direction = a2_prime <= π ? :ccw : :cw
    else
        avoid = _normalize_angle(avoid) # need to normalize here to do error check, and then again when rotating
        a1 != avoid && a2 != avoid || throw(ArgumentError("boundary angle $a1 or $a2 equals avoided angle $avoid"))
        # rotate frame of reference so a1 is at origin
        avoid_prime = _normalize_angle(avoid - a1)
        # if avoid_prime is between 0 and a2_prime, then a counterclockwise traversal from a1 to a2 would encounter it
        direction = avoid_prime < a2_prime ? :cw : :ccw
    end
    direction
end

"""
Return the unit vector perpendicular to `v` by rotating `v` 90 degrees counterclockwise if `ccw`,
or clockwise otherwise.
"""
@inline _perp(v::Point2; ccw=true) = ccw ? Point2(-v[2], v[1]) : Point2(v[2], -v[1])

"""
Return the unit tangent to the circle with center `c` at a point on its circumference `p`,
choosing the direction based on `ccw`.
"""
@inline _circle_tangent(c::Point2, p::Point2; ccw=true) = _perp(normalize(p - c); ccw)

"""
Return the unit normal to the line through `e1` and `e2`, pointing toward `c`.
Throws an error if `c` lies on that line.
"""
function _normal_towards(e1::Point2, e2::Point2, c::Point2)
    line = normalize(e2 - e1)
    other = c - e1 # this segment makes an angle with line, letting us find the direction for the normal
    dot(line, other) < 1 || throw(ArgumentError("c cannot be on line between e1 and e2"))
    _perp(line; ccw=cross(line, other) > 0)
end

"""Return the point a distance `d` along the vector from `e1` to `e2`."""
@inline _point_along_vector(e1::Point2, e2::Point2, d::Real) = e1 + d * normalize(e2 - e1)

"""Returns the two vertices bounding edge `edge` of polygon `v`, with wraparound."""
@inline _edge_endpoints(v::Vector{<:Point2}, edge::Int) = (v[edge], v[mod1(edge + 1, length(v))])

"""Returns a point `n/(N+1)` of the way along edge `edge` of polygon `v`, moving clockwise."""
function _point_along_edge(v::Vector{<:Point2}, edge::Int, n::Int, N::Int)
    e1, e2 = _edge_endpoints(v, edge)
    _point_along_vector(e1, e2, n / (N+1))
end

"""Returns the center of polygon `v`, computed as the average of its vertices."""
@inline _polygon_center(v::Vector{<:Point2}) = sum(v) / length(v)

### CURVEPIECE DRAWING HELPERS ###

"""
Sample the Bezier curve parameterized by `p0`, `p1`, `p2`, and `p3` from `t=0` to `t=1`.

The number of samples is scaled by the segment length `||p3 - p0||`, so that longer
curves get more points and the visual density of samples stays roughly constant.
`point_density` is the number of points per unit length.

To make sure small curves are drawn, at minimum `min_points` points are sampled.
"""
function _sample_bezier(p0::Point2, p1::Point2, p2::Point2, p3::Point2;
    point_density::Real=5, min_points::Int=5
)
    n = max(min_points, round(Int, point_density * norm(p3 - p0)))
    bezier(p0, p1, p2, p3, t) = (1-t)^3*p0 + 3(1-t)^2*t*p1 + 3(1-t)*t^2*p2 + t^3*p3
    [bezier(p0, p1, p2, p3, t) for t in range(0, 1, n)]
end

"""
Sample a circular arc centered at `center` with radius `radius` from polar `angle1`
to `angle2`, choosing the traversal direction (counterclockwise or not) based on `ccw`.

Takes account of input angles not being normalized to lie between `0` and `2π`.

The number of samples is scaled by the arc length, so that longer curves get more
points and the visual density of samples stays roughly constant.
`point_density` is the number of points per unit length.

To make sure small curves are drawn, at minimum `min_points` points are sampled.
"""
function _sample_arc(center::Point2, radius::Real, angle1::Real, angle2::Real, ccw::Bool;
    point_density::Real=5, min_points::Int=5
)
    a1, a2 = _normalize_angle(angle1), _normalize_angle(angle2)
    angular_distance = ccw ? _normalize_angle(a2 - a1) : _normalize_angle(a1 - a2)
    arc_length = angular_distance * radius
    n = max(min_points, round(Int, point_density * arc_length))
    angles = range(a1, a2, n)
    [center + radius * Point2(cos(θ), sin(θ)) for θ in angles]
end

"""
Generate the points used to plot an edge-to-edge curvepiece. A curvepiece is plotted
in three parts: a radially inward part, a circular arc, and a radially outward part.
The radial portions are cubic Bezier curves with control points chosen so that:
- they stitch to the arc continuously and smoothly
- they intersect the tile edges perpendicularly (so that the connections between
corresponding curvepieces in adjacent tiles are continuous and smooth)
For more information, see the documentation for `_radial_bezier_control_points`.

This function is purely geometric, in the sense that it accepts as inputs points and
parameters and returns a list of `Point2`s to be used to plot the curvepiece. The
information the function accepts is, in brief:
- `pn` the position of the nth (n=1, 2) curvepiece endpoint on its edge
- `pn_em` the position of the mth (m=1, 2) endpoint of that aforementioned edge
- `center` the position of the center of the tile
- `radius` the radius of the arc
- `ccw` whether the arc should traverse counterclockwise
- `sharpness` how sharply the Bezier curve corners should be
- `point_density` the point sampling density

So for example, `p2` is the position of the outgoing curvepiece endpoint, while `p1_e1`
and `p1_e2` are the endpoints of the tile edge the incoming curvepiece endpoint lies on.
"""
function _edge_to_edge_curvepiece_points(
    p1::Point2,
    p1_e1::Point2,
    p1_e2::Point2,
    p2::Point2,
    p2_e1::Point2,
    p2_e2::Point2,
    center::Point2,
    radius::Real,
    ccw::Bool,
    sharpness::Real;
    point_density::Real=5
)
    # get Bezier control points
    incoming_bezier_control_points = _radial_bezier_control_points(p1, p1_e1, p1_e2, center, radius, ccw, sharpness, :incoming)
    outgoing_bezier_control_points = _radial_bezier_control_points(p2, p2_e1, p2_e2, center, radius, ccw, sharpness, :outgoing)
    # get arc angles
    angle1 = _polar_angle(p1, center)
    angle2 = _polar_angle(p2, center)
    # sample points
    incoming_points = _sample_bezier(incoming_bezier_control_points...; point_density=point_density)
    arc_points = _sample_arc(center, radius, angle1, angle2, ccw; point_density=point_density)
    outgoing_points = _sample_bezier(outgoing_bezier_control_points...; point_density=point_density)
    # trim duplicate points at start and end of arc, then concatenate into single list and return
    vcat(incoming_points, arc_points[2:end-1], outgoing_points)
end

"""
Each edge-to-edge curvepiece is plotted in three parts, two radial sections (one where the curvepiece
enters the tile and one where it exits it) and a circular arc between them. This function computes the
Bezier control points for the radial sections of the curvepiece's plot.

Each radial section connects an entry/exit point `p` on an edge of the tile with the circular arc in the
center. In particular, the circular arc and radial section connect at a point on the line between `p` and
the `center` of the tile, at a distance of `radius` from the tile's `center`.

The control points are chosen so that the curve intersects the tile edge (whose endpoints are `e1` and
`e2`) perpendicularly and so the tangents to the curve and arc at the connection point are equal.

Arguments:
- `p` the point where the curvepiece enters/exits the tile
- `e1` one endpoint of the edge the curvepiece enters/exits the tile through
- `e2` the other endpoint of that same edge
- `center` the center of the tile
- `radius` the radius of the circular arc segment
- `ccw` the traversal direction of the circular arc segment
- `sharpness` how rounded the connection between the curve and arc is
- `direction` whether the radial segment is entering or exiting; should be one of `:incoming` or `:outgoing`
"""
function _radial_bezier_control_points(
    p::Point2, e1::Point2, e2::Point2,
    center::Point2, radius::Real, ccw::Bool,
    sharpness::Real, direction::Symbol
)
    edge_normal = _normal_towards(e1, e2, center)
    connection_point = _point_along_vector(center, p, radius)
    connection_tangent = _circle_tangent(center, connection_point; ccw=ccw)

    if direction === :incoming
        p0 = p
        p3 = connection_point
        p1 = p0 + sharpness * edge_normal
        p2 = p3 - sharpness * connection_tangent
    elseif direction === :outgoing
        p0 = connection_point
        p3 = p
        p1 = p0 + sharpness * connection_tangent
        p2 = p3 - sharpness * edge_normal
    else
        throw(ArgumentError("direction must be either :incoming or :outgoing, got $direction"))
    end
    p0, p1, p2, p3
end

function anyon_curvepiece(intersection, edge_p1, edge_p2, center, sharpness, n=20):
    t_edge = edge_normal(edge_p1, edge_p2, center)
    p0 = intersection
    p3 = center
    p1 = p0 + sharpness * t_edge
    p2 = p3  # free; pulling toward center directly is fine
    return sample_bezier(p0, p1, p2, p3, n)

### ENDPOINT POSITION HELPERS ###

"""
Returns the spatial position of the endpoint pointed to by `eref` in tile `t` with vertices `v`.

Edge endpoints are placed `n/(N+1)` of the way along their edge, where `n` is the endpoint's `pos`
and `N` is the total number of endpoints on that edge. Anyon endpoints are at the tile center.
"""
function _endpoint_point(t::Tile, v::Vector{<:Point2}, eref::EndpointRef)
    ep = endpoint(t, eref)
    ep isa AnyonEndpoint ? _tile_center(v) : _point_along_edge(v, ep.edge, ep.pos, num_edge_erefs(t, ep.edge))
end

"""
Returns the polar angle (relative to the tile center) of the edge endpoint of an anyon curvepiece in `t`.

This angle is used as `r` in `_midpoint_angle` so that edge-to-edge curvepiece
control points are placed to avoid the radial line formed by the anyon curvepiece.
Throws an error if `t` has no anyon curvepieces.
"""
function _anyon_curvepiece_edge_angle(t::Tile, v::Vector{<:Point2})
    num_anyon_erefs(t) > 0 || throw(ArgumentError("tile has no anyon curvepieces"))
    anyon_eref = first(anyon_erefs(t))
    edge_eref = cp_partner(anyon_eref)
    edge_point = _endpoint_point(t, v, edge_eref)
    _polar_angle(edge_point, _tile_center(v))
end

### CONTROL POINT POSITION HELPERS ###

"""
Calculates the hierarchy number and max enclosing hierarchy number for each edge-to-edge
curve piece, returning a `Dict{Int, Tuple{Int, Int}}` that maps curvepiece ids to a tuple
of this information.

Edge-to-edge curvepieces in a tile may be nested 'inside' each other, in the sense that
their endpoints may enclose both endpoints of another curvepiece. In other words, each
edge-to-edge curvepiece partitions the tile into two parts, and all other edge-to-edge
curvepieces will lay inside one of those parts. The 'hierarchy number' of an edge-to-edge
curvepiece is the number of nested layers of edge-to-edge curvepieces enclosed within it.

Because the endpoints live on a circle, there are two ways to do this assignment, depending
on which part of the partition you consider "inside" vs "outside" for any particular
curvepiece. In the extreme case, two endpoints which are directly adjacent could either be
said to enclose all other curvepieces, or no other curvepieces.

We choose to assign hierarchy numbers in a way that is globally self-consistent for all
curvepieces within a tile and loosely speaking minimizes the hierarchy numbers assigned
across all curvepieces in the tile. To do this, we start by assigning all curvepieces with
adjacent endpoints a hierarchy number of 1, then remove their endpoints from consideration
when calculating adjacency. We then do this scan again, this time assigning curvepieces
with adjacent endpoints a hierarchy number of 2. We continue till all edge-to-edge
endpoints are assigned.

Because of this, hierarchy numbers tend to 'meet in the middle' of the tile, and the
assignments may depend on which endpoint around the tile the adjacency scans are started.

The maximum enclosing hierarchy number for a curvepiece is the largest hierarchy number of
any curvepiece which encloses it.
"""
function _calculate_hierarchy(t::Tile)
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
    edge_erefs = edge_erefs(t)
    n = length(edge_erefs)

    # track hierarchy assignment per endpoint or curvepiece
    assigned = falses(n)                                # mask for if endpoint has a hierarchy number
    hier     = Dict{Int,Int}()                          # hierarchy number
    max_enc  = Dict{Int,Int}(id => -1 for id in ee_ids) # max enclosing hierarchy number

    # rounds of assigning hierarchy numbers
    round = 1
    while true
        # list of edge-to-edge endpoints lacking an assigned hierarchy number
        # (anyon-to-edge endpoints are excluded from assignment but remain in edge_erefs as barriers)
        unassigned = [(i, edge_erefs[i]) for i in 1:n if !assigned[i] && edge_erefs[i].cp_id ∈ ee_ids]
        isempty(unassigned) && break # we're done, all assigned

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
            # set the hierarchy number for this curvepiece
            hier[eref_i.cp_id] = round
            # indices between orig_i and orig_j going clockwise, with wraparound
            between = orig_i < orig_j ? ((orig_i + 1):(orig_j - 1)) :
                                        Iterators.flatten(((orig_i + 1):n, 1:(orig_j - 1)))
            # set the max hierarchy number for all entries between the ones just assigned
            for b in between
                bid = edge_erefs[b].cp_id
                if haskey(hier, bid) max_enc[bid] = round end
            end
            # mark these two as assigned
            consumed[k] = consumed[nk] = true
            push!(newly_assigned, orig_i, orig_j)
        end

        for i in newly_assigned; assigned[i] = true; end
        round += 1
    end

    Dict(id => (hier[id], max_enc[id]) for id in ee_ids)
end

"""
Computes the quadratic Bézier control point for an edge-to-edge curvepiece given its two
endpoint positions, the tile center, hierarchy data, and the distance from the tile center
to the polygon boundary in the control point's direction.

The control point lies at angle `_midpoint_angle(a1, a2, r)` — where `a1`, `a2` are the
angles of `p1`, `p2` relative to `center`, and `r` is an optional avoidance angle — and
at radial distance `max_r * (max_h - h + 1) / max_h` from `center`, so that higher-hierarchy
(more enclosing) curvepieces have their control points closer to the center.
"""
function _ee_control_point(p1::Point2, p2::Point2, center::Point2,
                           h::Int, max_h::Int, max_r::Real,
                           r::Union{Real,Nothing}=nothing)
    angle = _midpoint_angle(_polar_angle(p1, center), _polar_angle(p2, center), r)
    dist  = max_r * (max_h - h + 1) / (max_h + 1)
    center + dist * Point2f(cos(angle), sin(angle))
end

### BEZIER PATH BUILDERS ###

"""
Returns a quadratic Bézier path for curvepiece `cp_id` in tile `t` with vertices `v`.

`h_dict` is the output of `_calculate_hierarchy(t)`. `max_h` is the maximum hierarchy value
across all edge-to-edge curvepieces. `avoidance_angle` is the angle of the anyon curvepiece
edge endpoint (or `nothing` if the tile has no anyon curvepieces).

For edge-to-edge curvepieces, the control point angle is computed first, then the distance
to the polygon boundary in that direction is used as the radial scale for `_ee_control_point`.
For edge-to-anyon curvepieces, the control point is the midpoint between the edge endpoint
position and the tile center.

Because GLMakie requires cubic Bezier curves for plotting, we insert the control point twice.
"""
function _cp_bezier_path(t::Tile, v::Vector{<:Point2}, cp_id::Int,
                         h_dict::Dict{Int,Tuple{Int,Int}}, max_h::Int,
                         avoidance_angle::Union{Real,Nothing})
    center = _tile_center(v)
    p1 = _endpoint_point(t, v, EndpointRef(cp_id, 1))
    p2 = _endpoint_point(t, v, EndpointRef(cp_id, 2))

    ctrl = if haskey(h_dict, cp_id)
        # edge-to-edge: angle first, then boundary distance in that direction
        h = first(h_dict[cp_id])
        ctrl_angle = _midpoint_angle(_polar_angle(p1, center), _polar_angle(p2, center),
                                     avoidance_angle)
        max_r = _ray_to_boundary_dist(center, ctrl_angle, v)
        _ee_control_point(p1, p2, center, h, max_h, max_r, avoidance_angle)
    else
        # edge-to-anyon: midpoint between edge endpoint and tile center
        cp = curvepiece(t, cp_id)
        edge_p = cp.endpoint1 isa EdgeEndpoint ? p1 : p2
        (edge_p + center) / 2
    end

    BezierPath([MoveTo(p1), CurveTo(ctrl, ctrl, p2)])
end

"""
Returns a vector of Bézier paths, one per curvepiece in `t`, given polygon vertices `v`.

Precomputes the hierarchy dict, global max hierarchy, and anyon avoidance angle once,
then delegates to `_cp_bezier_path` for each curvepiece.
"""
function _curvepiece_paths(t::Tile, v::Vector{<:Point2})
    h_dict = _calculate_hierarchy(t)
    max_h  = isempty(h_dict) ? 1 : maximum(first(tup) for tup in values(h_dict))
    avoidance_angle = num_anyon_erefs(t) > 0 ? _anyon_curvepiece_edge_angle(t, v) : nothing
    [_cp_bezier_path(t, v, cp_id, h_dict, max_h, avoidance_angle) for cp_id in curvepiece_ids(t)]
end

### PUBLIC API ###

"""
Draws tile `t` onto `ax` with convex polygon vertices `v` (one vertex per edge, clockwise).

Each curvepiece is drawn as a Bézier curve with a direction arrow at its midpoint and an
inspector label readable via `DataInspector`. Throws if `length(v) != num_edges(t)`.
"""
function CurveDiagrams.visualize!(ax::Axis, t::Tile, v::Vector{<:Point2})
    length(v) == num_edges(t) ||
        throw(ArgumentError("expected $(num_edges(t)) vertices, got $(length(v))"))

    lines!(ax, push!(copy(v), v[1]); color=:gray80)
    num_anyon_erefs(t) > 0 && scatter!(ax, [_tile_center(v)]; markersize=12, color=:gray60)

    # precompute shared quantities once
    center = _tile_center(v)
    h_dict = _calculate_hierarchy(t)
    max_h  = isempty(h_dict) ? 1 : maximum(first(tup) for tup in values(h_dict))
    avoidance_angle = num_anyon_erefs(t) > 0 ? _anyon_curvepiece_edge_angle(t, v) : nothing
    # arrow scale: ~15% of the polygon circumradius
    arrow_scale = 0.15f0 * maximum(sqrt((p[1] - center[1])^2 + (p[2] - center[2])^2) for p in v)

    for cp_id in curvepiece_ids(t)
        cp = curvepiece(t, cp_id)
        p1 = _endpoint_point(t, v, EndpointRef(cp_id, 1))
        p2 = _endpoint_point(t, v, EndpointRef(cp_id, 2))

        ctrl = if haskey(h_dict, cp_id)
            h = first(h_dict[cp_id])
            ctrl_angle = _midpoint_angle(_polar_angle(p1, center), _polar_angle(p2, center),
                                         avoidance_angle)
            max_r = _ray_to_boundary_dist(center, ctrl_angle, v)
            _ee_control_point(p1, p2, center, h, max_h, max_r, avoidance_angle)
        else
            edge_p = cp.endpoint1 isa EdgeEndpoint ? p1 : p2
            (edge_p + center) / 2
        end
        @show ctrl

        bp    = BezierPath([MoveTo(p1), CurveTo(ctrl, ctrl, p2)])
        label = "curvepiece with id $cp_id in curve $(cp.curve_id) at position $(cp.anyon_count)"
        lines!(ax, bp; color=:red, inspector_label=(_, _, _) -> label)

        # direction arrow at the bezier midpoint, pointing from p1 toward p2
        d = p2 - p1
        dnorm = sqrt(d[1]^2 + d[2]^2)
        if dnorm > 0
            unit = Point2f(d[1] / dnorm, d[2] / dnorm)
            midpt = 0.25 * p1 + 0.5 * ctrl + 0.25* p2
            arr_len = 0.5f0 * arrow_scale
            # arrows2d!(ax, [midpt - 0.5 * arr_len * unit],
                        # [arr_len * unit]; color=:red,
                        # tipwidth=arr_len * 4, tiplength=arr_len * 0.7,
                        # inspectable=false)

            arrows2d!(ax, [midpt],
                        [unit]; color=:red, align=:tip, shaftlength=0, taillength=0,
                        tipwidth=arr_len * 4, tiplength=arr_len * 0.7,

                        inspectable=false)
        end
    end
end

"""
Visualizes tile `t` with convex polygon vertices `v` (one vertex per edge, listed clockwise).

Creates a new `Figure` and `Axis`, draws the tile, attaches a `DataInspector` for curvepiece
tooltips, and returns the figure. Throws if `length(v) != num_edges(t)`.
"""
function CurveDiagrams.visualize(t::Tile, v::Vector{<:Point2})
    f  = Figure()
    ax = Axis(f[1, 1]; aspect=DataAspect())
    visualize!(ax, t, v)
    DataInspector(f)
    hidespines!(ax)
    hidedecorations!(ax)
    resize_to_layout!(f)
    f
end
