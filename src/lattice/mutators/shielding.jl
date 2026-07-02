"""
Implements a single directional scan to find the position on `tref_edge` with the
minimum shielding number. See `_minimal_shielding_position` for context and more
information on the algorithm's details.

Scans from `start_eref` (exclusive) to `stop_eref` (exclusive) in the direction
given by `ccw`. If `stop_eref == nothing`, it stops once `tref_edge` has been
fully scanned. Internally, this is accomplished by finding the first eref 'beyond'
the end of `tref_edge` in the direction of traversal, and setting that to be the
`stop_eref`.

Returns `best_number`, `best_pos`, and `best_list`, which contain the minimum
shielding number of the positions scanned, its position on `tref_edge`, and the
shielding list at that position. If the `best_number` value is found to be `0`
at some point on `tref_edge`, we return early, as it doesn't get better than that.
"""
function _shielding_position_scan(t::Tile, tref_edge::Int,
    start_eref::EndpointRef, stop_eref::Union{EndpointRef,Nothing},
    ccw::Bool,
)
    shield_list = Int[]
    N = num_edge_erefs(t, tref_edge)
    best_number = typemax(Int)
    best_pos = 1
    best_list = Int[]

    # For empty tref_edge with no explicit stop, find the first eref beyond the
    # end of tref_edge in the scan direction and use it as the effective stop.
    effective_stop = stop_eref
    if N == 0 && stop_eref === nothing
        if !ccw
            e = next_edge(t, tref_edge)
            while e != tref_edge
                if has_edge_erefs(t, e)
                    effective_stop = edge_eref(t, e, 1)
                    break
                end
                e = next_edge(t, e)
            end
        else
            e = prev_edge(t, tref_edge)
            while e != tref_edge
                if has_edge_erefs(t, e)
                    effective_stop = edge_eref(t, e, num_edge_erefs(t, e))
                    break
                end
                e = prev_edge(t, e)
            end
        end
    end

    current = start_eref
    while true
        ep = endpoint(t, current)::EdgeEndpoint
        next = ccw ? prev_eref_wrap(t, ep.edge, ep.pos) :
               next_eref_wrap(t, ep.edge, ep.pos)
        next == effective_stop && break
        effective_stop === nothing && next == start_eref && break
        current = next
        ep_cur = endpoint(t, current)::EdgeEndpoint

        # Check the gap on the approaching side of this eref if it's on tref_edge
        if ep_cur.edge == tref_edge
            ins_pos = ccw ? ep_cur.pos + 1 : ep_cur.pos
            if length(shield_list) < best_number
                best_number = length(shield_list)
                best_pos = ins_pos
                best_list = copy(shield_list)
                best_number == 0 && return best_number, best_pos, best_list
            end
        end

        # Update shield_list: add tile partner's cp_id or remove if already present
        tp = tile_partner(t, current, EdgeEndpoint)
        if tp !== nothing
            idx = findfirst(==(current.cp_id), shield_list)
            if idx !== nothing
                deleteat!(shield_list, idx)
            else
                push!(shield_list, tp.cp_id)
            end
        end

        # After processing the last eref on tref_edge in this direction, check
        # the far gap and stop early
        if ep_cur.edge == tref_edge && (ccw ? ep_cur.pos == 1 : ep_cur.pos == N)
            ins_pos = ccw ? 1 : N + 1
            if length(shield_list) < best_number
                best_number = length(shield_list)
                best_pos = ins_pos
                best_list = copy(shield_list)
                best_number == 0 && return best_number, best_pos, best_list
            end
            break
        end
    end

    # Post-loop check for empty tref_edge: the loop never entered tref_edge, so
    # the current shield_list is the shielding count for the single position pos=1.
    if N == 0
        if length(shield_list) < best_number
            best_number = length(shield_list)
            best_pos = 1
            best_list = copy(shield_list)
            best_number == 0 && return best_number, best_pos, best_list
        end
    end

    best_number, best_pos, best_list
end

"""
Find the position on `tref` which is minimally shielded with respect to `eref1`
and `eref2`.

`eref1` and `eref2` must either be tile partners or the same `EndpointRef`,
otherwise an error will be thrown.

A position `pos` is 'shielded' from `eref1` and `eref2` by a pair, A and B, of
edge endpoints if:
- A and B are tile partners
- a traversal along arc 1 from `eref1` to `pos` encounters A
- a traversal along arc 2 from `eref2` to `pos` encounters B

In other words, the curvepiece or pair of curvepieces between A and B forms a
partition separating (shielding) `eref1` and `eref2` from `pos`. An equivalent
condition is:
- A and B are tile partners
- a traversal along arc 1 encounters A but not B

Let the traversal from `eref1` to `eref2` that does not include `pos` be arc 3.
Then arcs 1, 2, and 3, along with `eref1` and `eref2`, include all endpoints on
the tile. Note the following two possibilities:
- If `eref1 == eref2`, arc 3 has length 0, and so neither A nor B are on it.
- If `eref1` and `eref2` are tile partners, they partition the tile, meaning
A and B, being tile partners of each other, must either both be on arc 3 or
both not be on arc 3.

Therefore, if A is on arc 1 but B is not, then B must be on arc 2, and so the
conditions are equivalent.

The 'shielding number' of a position is the number of such shielding pairs. The
'shielding list' of a position is the list of shielding curvepieces, in the order
they are encountered during the traversal; the shielding number of a position is
the size of the shielding list at that position.

We calculate the shielding number of every position on the specified edge, then
find the minimum. We do this with a series of scans, each of which must start at
either `eref1` or `eref2`, then traverse either clockwise or counterclockwise
until a certain stop condition is reached. Roughly, for each scan:
- Initialize an empty list of curvepiece ids
- Initialize running minimum shielding number (value, position, list) variables
- Begin traversing from the start, and at each endpoint encountered:
    - if the endpoint's curvepiece id is already in the list, remove it from the
    list
    - if the endpoint's curvepiece id is not in the list, add its tile partner's
    curve id to the list
        - if the tile partner does not exist (in the case where there is only one
        edge-to-anyon curvepiece in the tile), skip the endpoint and leave the list
        unmodified, because a single anyon-to-edge curvepiece never shields anything
    - compare the current minimum shielding number to the stored extant minimum,
    and store the minimum value, the position it occured at, and a copy of the
    shielding list at that position
- Stop when we get to the stop condition

The reason we store the tile partner's curve id rather than the current endpoint's
curve id is so we handle the case where there are two anyon-to-edge curvepieces
in the tile. Namely, this way we store the curvepiece id of the edge endpoint which
is encountered second, which makes our comparison for whether an endpoint's curvepiece
id is already in the list very simple. A result of this choice is that the shielding
list will always contain the id for the second curvepiece encountered of the pair,
rather than the first. This is an arbitrary choice with no impact on correctness.

In terms of choosing scans, one naive way we could do this would be a to do two
scans, one clockwise and one counterclockwise, from `eref1` to `eref2`, so every
position in the tile would have been checked. However, this is inefficient, as
we can stop early if we have tested every position on `tref`. Therefore, we choose
our scan start positions, directions, and stop conditions based on the situation:
- Suppose that neither `eref1` nor `eref2` are on `tref`. Then the entirety of
`tref` is contained in one arc between `eref1` and `eref2`. We scan both
directions from `eref1` to cover both arcs, and take the minimum.
- Suppose that one of `eref1` or `eref2` is on `tref`. Then we can do the two
scans starting from that endpoint, stopping each once we get to the ends of `tref`.
- Suppose that `eref1` and `eref2` are the same, but are not on `tref`. Then we
can just do one clockwise scan starting from `eref1` and stopping when we get to
the end of `tref`.
- Suppose that both of `eref1` and `eref2` are on `tref`. Then we can do one
scan from `eref1` to `eref2` on `tref`, and one scan each in opposite directions
from `eref1` and `eref2` going 'outwards', stopping each when they reach the
ends `tref`.

In all cases but the last one, the stop condition for our scan is when we leave
`tref`.

Returns the position on the edge with the minimum shielding number, along with the
shielding list at that point.
"""
function _minimal_shielding_position(l::Lattice, tref::TileEdgeRef, eref1::EndpointRef, eref2::EndpointRef)
    t = get_tile(l, tref.tile_id)
    edge = tref.edge

    eref1_on_tref = (endpoint(t, eref1)::EdgeEndpoint).edge == edge
    eref2_on_tref = (endpoint(t, eref2)::EdgeEndpoint).edge == edge

    best_num = typemax(Int)
    best_pos = 1
    best_list = Int[]

    function update!(num, pos, list)
        if num < best_num
            best_num = num
            best_pos = pos
            best_list = list
        end
    end

    if !eref1_on_tref && !eref2_on_tref
        # tref is on one arc between eref1 and eref2; scan both directions
        # to find whichever arc contains tref
        update!(_shielding_position_scan(t, edge, eref1, nothing, false)...)
        update!(_shielding_position_scan(t, edge, eref1, nothing, true)...)
    elseif eref1_on_tref && !eref2_on_tref
        update!(_shielding_position_scan(t, edge, eref1, nothing, false)...)
        update!(_shielding_position_scan(t, edge, eref1, nothing, true)...)
    elseif !eref1_on_tref && eref2_on_tref
        update!(_shielding_position_scan(t, edge, eref2, nothing, false)...)
        update!(_shielding_position_scan(t, edge, eref2, nothing, true)...)
    else
        # both on tref: lower-pos eref scans CCW, higher-pos eref scans CW,
        # then scan CW from lower to higher
        ep1 = (endpoint(t, eref1)::EdgeEndpoint)
        ep2 = (endpoint(t, eref2)::EdgeEndpoint)
        lower = ep1.pos <= ep2.pos ? eref1 : eref2
        higher = ep1.pos <= ep2.pos ? eref2 : eref1
        update!(_shielding_position_scan(t, edge, lower, nothing, true)...)
        update!(_shielding_position_scan(t, edge, higher, nothing, false)...)
        update!(_shielding_position_scan(t, edge, lower, higher, false)...)
    end

    best_pos, best_list
end
