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
@inline function _point_along_edge(v::Vector{<:Point2}, edge::Int, n::Int, N::Int)
    e1, e2 = _edge_endpoints(v, edge)
    _point_along_vector(e1, e2, n / (N+1))
end

"""Returns the center of polygon `v`, computed as the average of its vertices."""
@inline _polygon_center(v::Vector{<:Point2}) = sum(v) / length(v)

"""Returns the inradius of polygon `v` with center `center`: the minimum distance from `center` to any edge."""
@inline function _polygon_inradius(v::Vector{<:Point2}, center::Point2)
    minimum(
        let (e1, e2) = _edge_endpoints(v, edge)
            edge_vec = e2 - e1
            center_vec = center - e1
            # cross product gives parallelogram area, dividing by base gives height, which is min dist to edge
            abs(cross(edge_vec, center_vec)) / norm(edge_vec)
        end
        for edge in 1:length(v)
    )
end

"""
Return the three vertices of an arrowhead triangle, used for indicating curvepiece directions.

The tip is at `center + (scale/2) * unit`. The base midpoint is at `center - (scale/2) * unit`,
so the total tip-to-base length equals `scale`. The base half-width is `scale * 0.4`.

`unit` must be a unit vector giving the pointing direction.
"""
function _arrow_triangle(center::Point2, unit::Point2, scale::Real)
    perp    = Point2f(-unit[2], unit[1])
    tip     = center + (scale / 2) * unit
    base    = center - (scale / 2) * unit
    width   = scale * 0.5f0
    Point2f[tip, base + width * perp, base - width * perp]
end

### CURVEPIECE PLOTTING HELPERS ###

"""
Sample the Bezier curve parameterized by `p0`, `p1`, `p2`, and `p3` from `t=0` to `t=1`.

The number of samples is scaled by the segment length `||p3 - p0||`, so that longer
curves get more points and the visual density of samples stays roughly constant.
`point_density` is the number of points per unit length.

To make sure small curves are drawn, at minimum `min_points` points are sampled.
"""
function _sample_bezier(p0::Point2, p1::Point2, p2::Point2, p3::Point2;
    point_density::Real, min_points::Int=5
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
    point_density::Real, min_points::Int=5
)
    angular_distance = ccw ? _normalize_angle(angle2 - angle1) : _normalize_angle(angle1 - angle2)
    arc_length = angular_distance * radius
    n = max(min_points, round(Int, point_density * arc_length))
    # derive a2 from a1 ± angular_distance so range always steps in the correct direction
    a1 = _normalize_angle(angle1)
    a2 = ccw ? a1 + angular_distance : a1 - angular_distance
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
    point_density::Real=30
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
    # scale control point offset by chord length so sharpness is geometry-independent;
    # sharpness=0 → straight line (no offset), sharpness=1 → offset equals full chord length
    chord = norm(connection_point - p)
    s = sharpness * chord

    if direction === :incoming
        p0 = p
        p3 = connection_point
        p1 = p0 + s * edge_normal # ctrl point should be in the tile
        p2 = p3 - s * connection_tangent
    elseif direction === :outgoing
        p0 = connection_point
        p3 = p
        p1 = p0 + s * connection_tangent
        p2 = p3 + s * edge_normal # ctrl point should be in the tile
    else
        throw(ArgumentError("direction must be either :incoming or :outgoing, got $direction"))
    end
    p0, p1, p2, p3
end

"""
Generate the points used to plot an edge-to-anyon curvepiece. The plot consists of one
cubic Bezier traveling from an edge of the tile ot the center of it. The control points
are chosen so that the curve intersects the edge of the tile perpendicularly (so that
the connections between corresponding curvepieces in adjacent tiles are continuous and
smooth).

This function is purely geometric, in the sense that it accepts as inputs points and
parameters and returns a list of `Point2`s to be used to plot the curvepiece. The
information the function accepts is, in brief:
- `p` the position of the curvepiece endpoint on its edge
- `e1` and `e2` the positions of the endpoints of that aforementioned edge
- `center` the position of the center of the tile
- `sharpness` how sharply the Bezier curve corners should be
- `point_density` the point sampling density
"""
function _edge_to_anyon_curvepiece_points(
    p::Point2, e1::Point2, e2::Point2,
    center::Point2, sharpness::Real;
    point_density::Real=30
)
    edge_normal = _normal_towards(e1, e2, center)
    p0 = p
    p3 = center
    # scale control point offset by chord length so sharpness is geometry-independent;
    # sharpness=0 → straight line (no offset), sharpness=1 → offset equals full chord length
    chord = norm(p3 - p0)
    s = sharpness * chord
    p1 = p0 + s * edge_normal
    p2 = p3 # degenerate control point pulls curve directly to center
    _sample_bezier(p0, p1, p2, p3; point_density=point_density)
end

### MISC HELPERS ###

"""
Returns the spatial position of the endpoint pointed to by `eref` in tile `t` with vertices `v`.

Edge endpoints are placed `n/(N+1)` of the way along their edge, where `n` is the endpoint's `pos`
and `N` is the total number of endpoints on that edge. Anyon endpoints are at the tile center.
"""
function _endpoint_position(t::Tile, v::Vector{<:Point2}, eref::EndpointRef)
    ep = endpoint(t, eref)
    ep isa AnyonEndpoint ? _polygon_center(v) : _point_along_edge(v, ep.edge, ep.pos, num_edge_erefs(t, ep.edge))
end

"""
Returns the polar angle (relative to `center`) of the edge endpoint of one of tile `t`'s anyon
curvepieces, given it has vertices `v`. Returns `nothing` if `t` has no anyon curvepieces.

This angle is used as an avoidance angle when determining arc traversal direction for edge-to-edge
curvepieces, so that their arcs do not cross the anyon radial line.
"""
function _anyon_avoid_angle(t::Tile, v::Vector{<:Point2}, center::Point2)
    num_anyon_erefs(t) == 0 && return nothing
    a_eref  = first(anyon_erefs(t))
    p_avoid = _endpoint_position(t, v, cp_partner(a_eref))
    _polar_angle(p_avoid, center)
end

"""
Given a curvepiece's `nesting` number and `max_enc`, its maximum enclosing number in the nesting hierarchy
determined by `calculate_nesting_hierarchy`, and a `max_radius` value which should be constant for any given
tile (across curvepieces that is), return the radius at which an edge-to-edge curvepiece's circular plot
section should travel around the tile center.

As `1 <= nesting <= max_enc`, as `nesting` grows, the radius gets smaller as the arc travels closer to the
tile's center.
"""
function _curvepiece_radius(nesting::Int, max_enc::Int, max_radius::Real)
    max_radius * (1 - (nesting / (max_enc + 1)))
end

### PUBLIC API ###

"""
Draws tile `t` onto `ax` with convex polygon vertices `v` (one vertex per edge, clockwise).

Each curvepiece is plotted as a sequence of points, obtained from `_edge_to_edge_curvepiece_points`
and `_edge_to_anyon_curvepiece_points`. Each curvepiece is a GLMakie `CHECK` plot, with an
inspector label readable via `DataInspector`. Each curvepiece is drawn with a directional arrow at
its midpoint.


Returns a dictionary from curvepiece id to plot objects, to allow later modification of the plotted
curves. Throws if `length(v) != num_edges(t)`.
"""
function CurveDiagrams.visualize!(ax::Axis, t::Tile, v::Vector{<:Point2}; sharpness::Real=0.3)
    EDGE_COLOR = :gray90
    CENTER_COLOR = :gray60
    CURVEPIECE_COLOR = :red

    length(v) == num_edges(t) ||
        throw(ArgumentError("expected $(num_edges(t)) vertices, got $(length(v))"))
    # draw tile edges and anyon center point
    edges_plot = lines!(ax, push!(copy(v), v[1]); color=EDGE_COLOR)
    center = _polygon_center(v)
    center_plot = num_anyon_erefs(t) > 0 ? scatter!(ax, [center]; markersize=12, color=CENTER_COLOR) : nothing
    # preliminary calculations we'll need later
    inradius     = _polygon_inradius(v, center)
    arrow_scale  = 0.10f0 * inradius
    nesting_dict = calculate_nesting_hierarchy(t)
    avoid_angle  = _anyon_avoid_angle(t, v, center)
    # plot curvepieces
    curvepiece_plots = Dict{Int, Any}()
    for cp_id in curvepiece_ids(t)
        cp    = curvepiece(t, cp_id)
        label = "curvepiece with id $cp_id in curve $(cp.curve_id) after anyon $(cp.anyon_count)"

        pts = if cp.endpoint1 isa EdgeEndpoint && cp.endpoint2 isa EdgeEndpoint # e2e
            ep1      = cp.endpoint1::EdgeEndpoint
            ep2      = cp.endpoint2::EdgeEndpoint
            p1       = _endpoint_position(t, v, EndpointRef(cp_id, 1))
            p2       = _endpoint_position(t, v, EndpointRef(cp_id, 2))
            p1_e1, p1_e2 = _edge_endpoints(v, ep1.edge)
            p2_e1, p2_e2 = _edge_endpoints(v, ep2.edge)
            dir      = _traversal_direction(_polar_angle(p1, center), _polar_angle(p2, center), avoid_angle)
            ccw      = dir == :ccw
            nesting, max_enc = nesting_dict[cp_id]
            radius   = _curvepiece_radius(nesting, max_enc, inradius)
            _edge_to_edge_curvepiece_points(p1, p1_e1, p1_e2, p2, p2_e1, p2_e2, center, radius, ccw, sharpness)
        else # e2a / a2e
            edge_ep    = cp.endpoint1 isa EdgeEndpoint ? cp.endpoint1::EdgeEndpoint : cp.endpoint2::EdgeEndpoint
            edge_which = cp.endpoint1 isa EdgeEndpoint ? 1 : 2
            p          = _endpoint_position(t, v, EndpointRef(cp_id, edge_which))
            e1, e2     = _edge_endpoints(v, edge_ep.edge)
            _edge_to_anyon_curvepiece_points(p, e1, e2, center, sharpness)
        end
        lp = lines!(ax, pts; color=CURVEPIECE_COLOR, inspector_label=(_, _, _) -> label)
        # direction arrow at the midpoint of the sampled points
        mid_idx = length(pts) ÷ 2
        unit    = Point2f(normalize(pts[mid_idx + 1] - pts[mid_idx - 1])...)
        ap = poly!(ax, _arrow_triangle(pts[mid_idx], unit, arrow_scale);
                   color=CURVEPIECE_COLOR, inspectable=false)
        curvepiece_plots[cp_id] = (lines=lp, arrow=ap)
    end
    # return plots
    edges_plot, center_plot, curvepiece_plots
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
