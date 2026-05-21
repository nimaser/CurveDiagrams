### GEOMETRY HELPERS ###

"""Returns the polar angle of point `p` relative to origin."""
@inline _polar_angle(p::Point2) = atan(p[2], p[1])

"""Returns the polar angle of point `p` relative to center `c`."""
@inline _polar_angle(p::Point2, c::Point2) = atan(p[2] - c[2], p[1] - c[1])

"""Normalizes an angle to the range 0 to 2π."""
@inline _normalize_angle(a::Real) = mod(a, 2π)


"""
Finds the midpoint angle `a` between angles `a1` and `a2`.

- If `r` is provided, chooses the traversal from `a1` to `a2` (either clockwise or
counterclockwise) that avoids crossing `r`, then returns its midpoint. Throws an
error if `r` equals `a1` or `a2`.
- If `r` is not provided, chooses the shorter arc (smaller angular span) and returns
its midpoint.

Returned angle is normalized to lie between 0 and 2π.
"""
function _midpoint_angle(a1::Real, a2::Real, r::Union{Real,Nothing}=nothing)
    a1, a2 = _normalize_angle(a1), _normalize_angle(a2)
    # 'rotate' frame of reference so a1 is at origin
    a2_prime = _normalize_angle(a2 - a1)
    a_prime = if r === nothing
        # shorter arc: counterclockwise if a2_prime ≤ π, clockwise otherwise
        a2_prime ≤ π ? a2_prime / 2 : (a2_prime - 2π) / 2
    else
        r = _normalize_angle(r)
        a1 != r && a2 != r || throw(ArgumentError("boundary angle $a1 or $a2 equals avoided angle $r"))
        r_prime = _normalize_angle(r - a1)
        # if r_prime is between 0 and a2_prime, avoid going counterclockwise, and vice versa
        r_prime < a2_prime ? a2_prime / 2 : (a2_prime - 2π) / 2
    end
    _normalize_angle(a_prime + a1)
end

"""Returns the two vertices bounding edge `edge` of polygon `v`, with wraparound."""
@inline _edge_endpoints(v::Vector{<:Point2}, edge::Int) = (v[edge], v[mod1(edge + 1, length(v))])

"""Returns the center of polygon `v`, computed as the average of its vertices."""
@inline _tile_center(v::Vector{<:Point2}) = sum(v) / length(v)

"""
Returns the distance from `center` to the boundary of convex polygon `v` along `angle`.

Casts a ray from `center` in direction `angle` and returns the distance to the first
edge it intersects. Assumes `center` is strictly inside `v`.

Not sure how this works, it was Claude-written and uses Cramer's rule.
"""
function _ray_to_boundary_dist(center::Point2, angle::Real, v::Vector{<:Point2})
    dx, dy = cos(angle), sin(angle)
    n = length(v)
    min_t = Inf
    for e in 1:n
        vi, vj = v[e], v[mod1(e + 1, n)]
        ex, ey = vj[1] - vi[1], vj[2] - vi[2]
        rx, ry = vi[1] - center[1], vi[2] - center[2]
        denom = dy * ex - dx * ey
        iszero(denom) && continue  # ray is parallel to this edge
        t = (ex * ry - rx * ey) / denom
        s = (dx * ry - dy * rx) / denom
        t > 0 && 0 ≤ s ≤ 1 && (min_t = min(min_t, t))
    end
    Float32(min_t)
end

"""Returns a point `n/(N+1)` of the way along edge `edge` of polygon `v`, moving clockwise."""
function _point_along_edge(v::Vector{<:Point2}, edge::Int, n::Int, N::Int)
    v1, v2 = _edge_endpoints(v, edge)
    v1 + (n / (N + 1)) * (v2 - v1)
end

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
