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
