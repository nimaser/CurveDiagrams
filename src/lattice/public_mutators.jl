"""
Create a new curve diagram between the anyons of two neighboring tiles, directed
from `tile_id1` to `tile_id2`. In particular, an anyon-to-edge and edge-to-anyon
curvepiece are inserted into the first and second tiles respectively, such that
their endpoints on the shared edge between the tiles are siblings, and the
associated `CurvepieceRef`s and other curve diagram bookkeeping structures are created.

For this operation to succeed:
- neither tile's anyon can already be on a curve diagram
- `tile_id1` and `tile_id2` must share exactly one edge

These guarantee that any curvepieces in the two affected tiles are always able to be
deformed to be out of the way of the two new curvepieces. Throws an error if either
condition is violated.

`pos` is the 1-based position in tile 1 at which the shared endpoint is inserted on
the shared edge, and defaults to 1. The corresponding position for the sibling
endpoint in tile 2 is calculated automatically. Throws an error if `pos` is invalid.

Assumes that the lattice is in a valid state to start with, in particular that every edge
endpoint for a curvepiece has a sibling. Violation of this assumption results in
undefined behavior.

Returns `(curve_id, action)` where `action = [0, curve_id, tile_id1, tile_id2]`. `action`
is used by callers to record actions taken by the simulation.
"""
function create_pair!(l::Lattice, tile_id1::Int, tile_id2::Int, pos::Int=1)
    # get references to tiles and edges
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    shared = shared_edge(l, tile_id1, tile_id2)
    shared != nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    e1, e2 = shared
    # check that anyons aren't part of curve diagrams already
    anyon_curve_id(t1) === nothing ||
        throw(ArgumentError("tile $tile_id1 already has an anyon on a curve diagram"))
    anyon_curve_id(t2) === nothing ||
        throw(ArgumentError("tile $tile_id2 already has an anyon on a curve diagram"))
    # check that insertion position is valid; assumes valid lattice state
    N = num_edge_erefs(t1, e1)
    1 <= pos <= N+1 || throw(ArgumentError("pos $pos not in range 1 to $(N+1)"))
    # curve diagram and position setup before curvepiece insertion
    curve_id = _allocate_curve_id!(l)
    anyon_count = 1
    sibling_pos = (N+1) - pos + 1 # see sibling_insert_pos() and sibling_location() for explanation
    # insert curvepieces
    cp_id1 = insert_curvepiece!(t1, curve_id, anyon_count, e1, pos, OUT)
    cp_id2 = insert_curvepiece!(t2, curve_id, anyon_count, e2, sibling_pos, IN)
    # register both curvepieces in the curve diagram
    _insert_cref!(l, curve_id, 1, CurvepieceRef(tile_id1, cp_id1))
    _insert_cref!(l, curve_id, 2, CurvepieceRef(tile_id2, cp_id2))
    # assemble and return the action
    action = [0, curve_id, tile_id1, tile_id2]
    curve_id, action
end

"""
Swap two sequential anyons on the same curve diagram which are in neighboring tiles.
The anyons must be 'directly connected', meaning that between them are exactly two
edge-to-anyon curvepieces, one in `tile_id1` and one in `tile_id2`, which connect
to each other at the shared edge. The value of `dir` indicates whether to carry out
a (+1) 'counterclockwise' or (-1) 'clockwise' swap.

Please note: a swap does not change the physical state of the lattice, but instead
changes the basis the lattice quantum state is written in. In other words, we are
only changing the ordering of anyons on a curve diagram, not the lattice locations
of any anyons.

To clarify the setup:
- let T1 and T2 be the tiles containing the two anyons A1 and A2 respectively
- A1 and A2 are connected by a sequence, M, of two anyon-to-edge curvepieces
- M is directed from A1 to A2
- let P be the curvepiece before M in the curve diagram, if it exists; i.e. P is
the other anyon-to-edge curvepiece in T1
- let N be the curvepiece after M in the curve diagram, if it exists; i.e. N is
the other anyon-to-edge curvepiece in T2
- let E1 be the edge in T1 which hosts P's edge endpoint
- let E2 be the edge in T2 which hosts N's edge endpoint
- let E be the edge shared between T1 and T2

So the entire sequence of curvepieces is:
- P goes E1 -> A1
- M goes A1 -> E -> A2
- N goes A2 -> E2

If A1 is the first anyon on the curve diagram, P will not be present. If A2
is the last anyon on the curve diagram, N will not be present. The swap consists
of three discrete steps, one to modify each of P, M, and N respectively.
- M is always guaranteed to be present, and we just reverse its direction to get Mr
- P's anyon endpoint is 'detached' from A1 and pulled/stretched alongside M to
attach to A2; this requires crossing E, and therefore P becomes two curvepieces,
P1, which is an edge-to-edge curvepiece going from E1 to E, and P2, an edge-to-anyon
curvepiece going from E to A2
- N does the same as P, except it is detached from A2, pulled alongside M, and
attached to A1

Therefore, after the swap, the sequence of curvepieces in the curve diagram is:
- P1 from E1 -> E
- P2 from E -> A2
- Mr from A2 -> E -> A1
- N1 from A1 -> E
- N2 from E -> E2

P1 and P2 will only be present if P was present initially. N1 and N2 will only be
present if N was present initially.

P and N are pulled alongside M on 'opposite sides'. That is, if we orient the
lattice so that M is horizontal, one goes above M, and one goes below it. In
other words, the position of the edge endpoints of P2 and N2 will be at +1
and -1 offsets from the position of the edge endpoint in the middle of M.
Which one is +1 and which one is -1 depends on the value of `dir`: `dir` sets
the relative position of P2's edge endpoint.

This function throws an error if:
- the tiles provided do not share an edge
- A1, A2, and M are not as described above

Returns `action = [3, curve_id, seg, dir]`, where `seg` is the segment index between the
two anyons before the swap.
"""
function swap!(l::Lattice, tile_id1::Int, tile_id2::Int, dir::Int)
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    shared = shared_edge(l, tile_id1, tile_id2)
    shared !== nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    e1, e2 = shared

    # find M: the anyon cp in each tile whose edge endpoint is on the shared edge
    m_t1_id = only(cp_id for cp_id in anyon_cp_ids(t1)
                   if (endpoint(t1, cp_partner(anyon_eref(t1, cp_id)))::EdgeEndpoint).edge == e1)
    m_t2_id = only(cp_id for cp_id in anyon_cp_ids(t2)
                   if (endpoint(t2, cp_partner(anyon_eref(t2, cp_id)))::EdgeEndpoint).edge == e2)

    curve_id = curvepiece(t1, m_t1_id).curve_id
    seg = curvepiece(t1, m_t1_id).anyon_count

    # P = other anyon cp in T1 (if present), N = other anyon cp in T2 (if present)
    p_id = partner_cp_id(t1, m_t1_id)
    n_id = partner_cp_id(t2, m_t2_id)

    # record endpoints and anyon_counts before any mutation
    p_ep = p_id !== nothing ? (endpoint(t1, cp_partner(anyon_eref(t1, p_id)))::EdgeEndpoint) : nothing
    ac_p = p_id !== nothing ? curvepiece(t1, p_id).anyon_count : nothing
    n_ep = n_id !== nothing ? (endpoint(t2, cp_partner(anyon_eref(t2, n_id)))::EdgeEndpoint) : nothing
    ac_n = n_id !== nothing ? curvepiece(t2, n_id).anyon_count : nothing

    # record diagram positions before any mutation
    m_t1_cref  = CurvepieceRef(tile_id1, m_t1_id)
    m_t2_cref  = CurvepieceRef(tile_id2, m_t2_id)
    start_cref = p_id !== nothing ? CurvepieceRef(tile_id1, p_id) : m_t1_cref
    pos_start  = find_cref_index(l, curve_id, start_cref)
    n_old      = (p_id !== nothing ? 1 : 0) + 2 + (n_id !== nothing ? 1 : 0)

    # step 1: reverse M in both tiles
    reverse_curvepiece!(t1, m_t1_id)
    reverse_curvepiece!(t2, m_t2_id)

    # step 2: remove P and N
    p_id !== nothing && remove_curvepiece!(t1, p_id)
    n_id !== nothing && remove_curvepiece!(t2, n_id)

    # eref for Mr_t1's edge endpoint on e1 after reversal
    m_t1_edge_eref = cp_partner(anyon_eref(t1, m_t1_id))
    p_m1 = (endpoint(t1, m_t1_edge_eref)::EdgeEndpoint).pos

    # step 3: compute P1/P2 positions (before inserting anything), then insert P1 and P2
    new_p1_id = nothing
    new_p2_id = nothing
    if p_id !== nothing
        p1_second_pos = p_m1 + (dir == 1 ? 1 : 0)
        p2_edge_pos   = sibling_insert_pos(l, tile_id1, e1, p1_second_pos)
        new_p1_id = insert_curvepiece!(t1, curve_id, ac_p, p_ep.edge, p_ep.pos, e1, p1_second_pos)
        new_p2_id = insert_curvepiece!(t2, curve_id, ac_p, e2, p2_edge_pos, IN)
    end

    # step 4: compute N1/N2 positions (after inserting P1/P2 so sibling pos accounts for P2), then insert
    new_n1_id = nothing
    new_n2_id = nothing
    if n_id !== nothing
        p_m1_now      = (endpoint(t1, m_t1_edge_eref)::EdgeEndpoint).pos  # may have shifted if dir==-1
        n1_second_pos = p_m1_now + (dir == 1 ? 0 : 1)
        n2_edge_pos   = sibling_insert_pos(l, tile_id1, e1, n1_second_pos)
        new_n1_id = insert_curvepiece!(t1, curve_id, ac_n, e1, n1_second_pos, OUT)
        new_n2_id = insert_curvepiece!(t2, curve_id, ac_n, e2, n2_edge_pos, n_ep.edge, n_ep.pos)
    end

    # step 5: update the curve diagram: replace [P, M_t1, M_t2, N] with [P1, P2, Mr_t2, Mr_t1, N1, N2]
    for _ in 1:n_old; _remove_cref!(l, curve_id, pos_start); end
    ins = pos_start
    if p_id !== nothing
        _insert_cref!(l, curve_id, ins, CurvepieceRef(tile_id1, new_p1_id)); ins += 1
        _insert_cref!(l, curve_id, ins, CurvepieceRef(tile_id2, new_p2_id)); ins += 1
    end
    _insert_cref!(l, curve_id, ins, m_t2_cref); ins += 1
    _insert_cref!(l, curve_id, ins, m_t1_cref); ins += 1
    if n_id !== nothing
        _insert_cref!(l, curve_id, ins, CurvepieceRef(tile_id1, new_n1_id)); ins += 1
        _insert_cref!(l, curve_id, ins, CurvepieceRef(tile_id2, new_n2_id))
    end

    [3, curve_id, seg, dir]
end

"""
Create a u-turn by pulling `cref` across position `pos` in edge `edge` of its tile.
This operation is the 'inverse' of `_remove_u_turn!`, which is used in `simplify!`.

In detail, suppose `cref` refers to a curvepiece C, with endpoints e1 and e2 (in
traversal order), in a tile T1. T1 borders another tile T2 across the edge `edge`.

After this operation, C will have been deleted and replaced in its curve diagram
with a sequence of three new curvepieces, P, U, and N. P and N will be located in
T1, and will each 'inherit' one of C's endpoints e1 and e2, while U will be a
u-turn curvepiece located in T2.
- P's first endpoint will be e1 while its second endpoint, p2, will be on `edge`
- N's first endpoint, n1, will be on `edge` while its second endpoint will be e2
- U's first and second endpoints will be the siblings of p2 and n1 respectively,
hence connecting P to N

Either p2 or n1 will be at position `pos`, with the other at position `pos+1`,
depending on the exact layout of curvepieces in T1. The ordering is selected so
that P and N do not intersect each other. See `split_curvepiece!` for more
information on how this assignment is done.
"""
function _create_u_turn!(l::Lattice, cref::CurvepieceRef, edge::Int, pos::Int)
    t1 = get_tile(l, cref.tile_id)
    cp = curvepiece(t1, cref.cp_id)
    curve_id = cp.curve_id
    ac = cp.anyon_count
    ter = corresponding_edge(l, cref.tile_id, edge)
    t2_id, t2_edge = ter.tile_id, ter.edge
    t2 = get_tile(l, t2_id)
    pos_c = find_cref_index(l, curve_id, cref)

    p_id, n_id = split_curvepiece!(t1, cref.cp_id, edge, pos)
    _remove_cref!(l, curve_id, pos_c)
    _insert_cref!(l, curve_id, pos_c,     CurvepieceRef(cref.tile_id, p_id))
    _insert_cref!(l, curve_id, pos_c + 1, CurvepieceRef(cref.tile_id, n_id))

    p_ep = curvepiece(t1, p_id).endpoint2::EdgeEndpoint
    n_ep = curvepiece(t1, n_id).endpoint1::EdgeEndpoint
    u_pos1 = sibling_insert_pos(l, cref.tile_id, p_ep.edge, p_ep.pos)
    u_pos2 = sibling_insert_pos(l, cref.tile_id, n_ep.edge, n_ep.pos)

    u_id = insert_curvepiece!(t2, curve_id, ac, t2_edge, u_pos1, t2_edge, u_pos2; allow_intersections=true)
    _insert_cref!(l, curve_id, pos_c + 1, CurvepieceRef(t2_id, u_id))
    nothing
end

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
    start_eref::EndpointRef, stop_eref::Union{EndpointRef, Nothing},
    ccw::Bool,
)
    shield_list = Int[]
    N = num_edge_erefs(t, tref_edge)
    best_number = typemax(Int)
    best_pos    = 1
    best_list   = Int[]

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
                best_pos    = ins_pos
                best_list   = copy(shield_list)
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
                best_pos    = ins_pos
                best_list   = copy(shield_list)
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
            best_pos    = 1
            best_list   = copy(shield_list)
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
`tref` is contained in one of the directions of traversal starting from `eref1`.
So we can just do one scan, and stop once we get to the end of `tref`.
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
    t    = get_tile(l, tref.tile_id)
    edge = tref.edge

    eref1_on_tref = (endpoint(t, eref1)::EdgeEndpoint).edge == edge
    eref2_on_tref = (endpoint(t, eref2)::EdgeEndpoint).edge == edge

    best_num  = typemax(Int)
    best_pos  = 1
    best_list = Int[]

    function update!(num, pos, list)
        if num < best_num
            best_num  = num
            best_pos  = pos
            best_list = list
        end
    end

    if !eref1_on_tref && !eref2_on_tref
        # tref entirely on one side of eref1; one CW scan suffices
        update!(_shielding_position_scan(t, edge, eref1, nothing, false)...)
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
        lower  = ep1.pos <= ep2.pos ? eref1 : eref2
        higher = ep1.pos <= ep2.pos ? eref2 : eref1
        update!(_shielding_position_scan(t, edge, lower,  nothing, true)...)
        update!(_shielding_position_scan(t, edge, higher, nothing, false)...)
        update!(_shielding_position_scan(t, edge, lower,  higher,  false)...)
    end

    best_pos, best_list
end

"""
'Stretches' curvepiece `cref` into neighboring `tile_id2` to form a u-turn; see
`_create_u_turn!` for specific details on the configuration of u-turns. If there
are any 'shielding' curvepieces in the way, they are stretched into `tile_id2`
first.

Let E be the edge shared between `cref`'s tile and `tile_id2`, and the position
on E through which `cp_id` is pulled into `tile_id2` be the insertion position.
A shielding curvepiece is one which partitions the tile into two parts, one of
which contains the insertion position, and the other of which contains `cref`.
If it is not moved out of the way (by creating a u-turn in it, and thus creating
a 'clear path' to the insertion position), trying to create a u-turn in `cref`
will lead to curvepiece intersections.

Shielding curvepieces need to be dealt with in order from the innermost outwards,
because if there are multiple, the inner ones will also shield the outer ones.

The insertion position is chosen automatically to minimize the number of shielding
curvepieces, and the processing order is determined in the same pass. See
`_minimal_shielding_position` for details on how this is done. The endpoint
arguments to that function are chosen as one edge endpoint of `cref` along with
its tile partner. In the case where the tile partner doesn't exist, that (sole)
edge endpoint is used for both endpoint arguments.

All curve diagrams containing affected curvepieces are automatically updated.
Returns `nothing`.
"""
function stretch!(l::Lattice, cref::CurvepieceRef, tile_id2::Int)
    t1 = get_tile(l, cref.tile_id)
    cp = curvepiece(t1, cref.cp_id)
    e1, _ = shared_edge(l, cref.tile_id, tile_id2)

    # Get one edge endpoint of cref and its tile partner (or itself if no partner)
    eref1 = cp.endpoint1 isa EdgeEndpoint ? EndpointRef(cref.cp_id, 1) : EndpointRef(cref.cp_id, 2)
    tp    = tile_partner(t1, eref1, EdgeEndpoint)
    eref2 = tp !== nothing ? tp : eref1

    # Find optimal insertion position and ordered shielding list (innermost last)
    best_pos, shield_list = _minimal_shielding_position(l, TileEdgeRef(cref.tile_id, e1), eref1, eref2)
    n = length(shield_list)

    # Stretch shields innermost-first; each shifts best_pos up by 1
    for cp_id in reverse(shield_list)
        stretch!(l, CurvepieceRef(cref.tile_id, cp_id), tile_id2)
    end

    _create_u_turn!(l, cref, e1, best_pos + n)
    nothing
end

"""
Extend an existing curve diagram by adding
Extend an existing curve diagram by adding a new anyon in `tile_id2`, which must be an
empty neighbor of `tile_id1`. `tile_id1`'s anyon must already be on a curve. `place=+1`
inserts the new anyon immediately after `tile_id1`'s in traversal order; `place=-1` inserts
it before.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge.
- `tile_id1`'s anyon is already on a curve (`anyon_curve_id(l, tile_id1) !== nothing`).
- `tile_id2` contains no anyon curvepiece.
- `place` is `+1` or `-1`.

Returns `action = [1, curve_id, pos, tile_id2]`, where `pos` is the 1-based index of the
new anyon in the curve.
"""
function grow!(l::Lattice, tile_id1::Int, tile_id2::Int, place::Int)
    # --- Validation ---
    # anyon_curve_id(l, tile_id2) !== nothing → error (t2 already has anyon)
    # anyon_curve_id(l, tile_id1) === nothing → error (t1 has no anyon)
    # place ∉ {-1,+1} → error

    # t1 = get_tile(l, tile_id1)
    # t2 = get_tile(l, tile_id2)
    # e1, e2 = shared_edge(l, tile_id1, tile_id2)

    # --- Step 1: clear shielding curvepieces ---
    # A curvepiece shields the anyon from e1 if it appears in the unpaired set of BOTH
    # the CW walk (e1 → anyon) and the CCW walk (e1 → anyon). Stretch each shielding
    # piece (outermost first) until none remain.
    # NOTE: makelist / shielding detection (two-directional walk + intersection) does not
    # yet have a Julia equivalent and needs to be implemented.
    # while any curvepiece in t1 shields the anyon from e1:
    #     stretch!(l, tile_id1, outermost_shielding_cp_id, tile_id2)

    # --- Identify a_cp: the relevant anyon curvepiece in t1 ---
    # place==+1 → the one with the highest anyon_count (last in traversal through the anyon)
    # place==-1 → the one with the lowest anyon_count (first in traversal through the anyon)
    # a_cp_id  = anyon cp in t1 with (place==+1 ? max : min) anyon_count
    # a_cp     = curvepiece(t1, a_cp_id)
    # curve_id = a_cp.curve_id
    # seg      = a_cp.anyon_count

    # --- Determine whether the curve has a segment on the 'place' side of a_cp ---
    # neighbor = (place == +1) ? next_curvepiece(l, tile_id1, a_cp_id)
    #                           : prev_curvepiece(l, tile_id1, a_cp_id)
    # neighbor = (neighbor_tile_id, neighbor_cp_id), or nothing if a_cp is a terminus
    # i1 = find_curve_position(l, curve_id, tile_id1, a_cp_id)

    # if neighbor !== nothing:
    #     neighbor_tile_id, neighbor_cp_id = neighbor
    #
    #     if neighbor_tile_id == tile_id2:
    #         # --- Case A1: the adjacent segment already crosses into t2 ---
    #         #
    #         # neighbor_cp (call it b) is an edge-to-edge curvepiece in t2 with one
    #         # endpoint on e2 (sibling of a_cp's edge endpoint). We split it at t2's
    #         # new anyon:
    #         #   b becomes:    EdgeEndpoint(other_edge) ↔ AnyonEndpoint
    #         #   new_cp gets:  EdgeEndpoint(e2, same pos) ↔ AnyonEndpoint
    #         #
    #         # Concretely:
    #         #   b_ep_e2     = the EdgeEndpoint of b on e2
    #         #   b_ep_other  = the other EdgeEndpoint of b (on some non-e2 edge)
    #         #   remove b from t2
    #         #   b_new    = insert_curvepiece!(t2, curve_id, seg,
    #         #                  b_ep_other.edge, b_ep_other.pos, ANYON)
    #         #   new_cp   = insert_curvepiece!(t2, curve_id, seg,
    #         #                  e2, <position on e2 matching b's old e2 endpoint>, ANYON)
    #         #   NOTE: anyon_count for b_new vs new_cp: both initially get seg; their
    #         #   order in t2's anyon list distinguishes them; _shift_anyon_count! at the
    #         #   end handles final renumbering.
    #         #   NOTE: position arithmetic on e2 after removing b needs careful handling
    #         #   (as in stretch!).
    #         #
    #         # Update curve diagram:
    #         #   replace CurvepieceRef(tile_id2, b_cp_id) with CurvepieceRef(tile_id2, b_new_id)
    #         #   insert  CurvepieceRef(tile_id2, new_cp_id) at position:
    #         #     place==+1 → i1+1   (new anyon is after a in the path)
    #         #     place==-1 → i1     (new anyon is before a in the path)
    #
    #     else:
    #         # --- Case A2: adjacent segment does NOT go to t2 ---
    #         #
    #         # Stretch a_cp into t2, creating a U-turn loop in t2 on e2.
    #         # cp1, cp2, cp3 = stretch!(l, tile_id1, a_cp_id, tile_id2)
    #         # cp3 is now an edge-to-edge loop in t2 (both endpoints on e2).
    #         # Split cp3 at the new anyon in t2, exactly as in case A1:
    #         #   cp3_in_ep  = the IN endpoint of cp3 on e2
    #         #   cp3_out_ep = the OUT endpoint of cp3 on e2
    #         #   remove cp3 from t2
    #         #   cp3a = insert_curvepiece!(t2, curve_id, seg, e2, cp3_in_ep.pos, ANYON)
    #         #   cp3b = insert_curvepiece!(t2, curve_id, seg, e2, cp3_out_ep.pos, ANYON)
    #         #   NOTE: position arithmetic on e2 after removing cp3 needs careful handling.
    #         #
    #         # Update curve diagram:
    #         #   replace CurvepieceRef(tile_id2, cp3) with CurvepieceRef(tile_id2, cp3a)
    #         #   insert  CurvepieceRef(tile_id2, cp3b) adjacent to it
    #         #   (ordering of cp3a vs cp3b in the diagram depends on place)
    #
    # else:
    #     # --- Case B: a_cp is at the terminus of the curve in the 'place' direction ---
    #     # No adjacent segment exists; must create entirely new curvepieces.
    #     #
    #     # Find insertion position on e1: walk CW from a_cp's edge endpoint around t1
    #     # to e1, counting unpaired erefs (same algorithm as in stretch!'s else branch).
    #     # NOTE: find_insertion_position_on_e1 could be extracted from stretch! into a
    #     # shared helper.
    #     # insert_pos = find_insertion_position_on_e1(t1, a_cp_id, e1)
    #     # _, _, sibling_pos = sibling_location(l, tile_id1, e1, insert_pos)
    #     #
    #     # direction = (place == +1) ? OUT : IN
    #     #   place==+1 → OUT on e1 (curve exits t1 after the anyon, heading to t2)
    #     #   place==-1 → IN  on e1 (curve enters t1 before the anyon, coming from t2)
    #     #
    #     # new_cp_t1 = insert_curvepiece!(t1, curve_id, seg, e1, insert_pos, direction)
    #     # new_cp_t2 = insert_curvepiece!(t2, curve_id, seg, e2, sibling_pos+1, opposite(direction))
    #     #
    #     # Extend the curve diagram at the terminus:
    #     # if place == +1:
    #     #     append CurvepieceRef(tile_id1, new_cp_t1) to diagram
    #     #     append CurvepieceRef(tile_id2, new_cp_t2) to diagram
    #     # else: # place == -1
    #     #     prepend CurvepieceRef(tile_id2, new_cp_t2) to diagram
    #     #     prepend CurvepieceRef(tile_id1, new_cp_t1) to diagram

    # --- Step 4: update anyon_count ---
    # From t2's new anyon cp onward in the curve, increment anyon_count by +1.
    # Equivalent to MATLAB's "update segment numbers" loop from istart to end.
    # new_t2_pos_in_diagram = position of t2's new anyon cp in curve diagram
    # _shift_anyon_count!(l, curve_id, new_t2_pos_in_diagram + 1, +1)

    # return [1, curve_id, seg + 1, tile_id2]
end

"""
Merges two distinct curve diagrams by connecting `cp_id_in_t1` in `tile_id1` to
`cp_id_in_t2` in `tile_id2` across their shared edge. The two formerly separate curves
become one connected curve diagram. The surviving `curve_id` is the one with the lower id;
the absorbed curve's id is permanently retired via `_delete_curvediagram!`.

Preconditions:
- `tile_id1` and `tile_id2` share exactly one edge.
- `cp_id_in_t1` has an endpoint on the shared edge.
- `cp_id_in_t2` has an endpoint on the same shared edge.
- The two curvepieces belong to different curve diagrams.

Returns `action = [2, surviving_curve_id, absorbed_curve_id, 0]`.
"""
function merge!(l::Lattice, tile_id1::Int, cp_id_in_t1::Int, tile_id2::Int, cp_id_in_t2::Int)
    # TODO
end

"""
The primary high-level operation. Drives a sequence of primitive operations until the
anyons in `tile_id1` and `tile_id2` are directly connected on the same curve diagram,
with `tile_id1`'s anyon coming before `tile_id2`'s in traversal order.

Handles four initial cases:
- Both tiles empty → `create_pair!`
- One tile empty → `grow!`
- Both on the same curve → repeated `swap!` / `stretch!` until adjacent
- Both on different curves → `merge!`, then bring adjacent

Returns an N×4 integer matrix where each row encodes one primitive operation in the MATLAB
convention:
- `[0, curve_id, t1, t2]` — pair created
- `[1, curve_id, pos, t2]` — grow
- `[2, curve_id1, curve_id2, 0]` — merge (curve_id1 survives)
- `[3, curve_id, seg, dir]` — swap
- `[-1, 0, 0, 0]` — decoding error (non-trivial loop)

Returns a 0×4 matrix if the anyons are already directly connected.
"""
function makeneighbors!(l::Lattice, tile_id1::Int, tile_id2::Int)
    # TODO
end

###############################################################################
# ANYON REMOVAL
###############################################################################

"""
Remove the anyon in `tile_id` from its curve diagram.

There are three cases, depending on whether the selected anyon is the first,
last or a middle anyon in its curve diagram. Let the anyon number be `n`, of
`N` total anyons in the curve diagram.
- `n = 1`: Every curvepiece between anyons 1 and 2 is deleted. Anyon 2 becomes
anyon 1, and the `anyon_count` for every curvepiece in the curve diagram is
decremented by 1. If there were only two anyons in the curve diagram, there are
no curvepieces left, and so the curve diagram is deleted.
- `n = N`: Every curvepiece between anyons `N-1` and `N` is deleted. If there
were only two anyons in the curve diagram, there are no curvepieces left, and
so the curve diagram is deleted.
- `1 < n < N`: There are originally two anyon-to-edge curvepieces in the tile.
Let their edge endpoints be A and B, where A is the endpoint encountered by
traversing backwards, while B is obtained by traversing forwards, from the
anyon. Both curvespieces will be deleted, and a new edge-to-edge curvepiece
going from A to B will be inserted, with `anyon_count=n-1`. All curvepieces
between B and the `n+1`th anyon will have their `anyon_count`s decreased by
one, from `n` to `n-1`.
"""
function remove_anyon!(l::Lattice, tile_id::Int)
    t = get_tile(l, tile_id)
    curve_id = anyon_curve_id(t)
    curve_id === nothing && return

    # classify the anyon cps: e2a has anyon at endpoint2, a2e has anyon at endpoint1
    e2a_id = nothing
    a2e_id = nothing
    for cp_id in anyon_cp_ids(t)
        if anyon_eref(t, cp_id).endpoint_idx == 2
            e2a_id = cp_id
        else
            a2e_id = cp_id
        end
    end

    if e2a_id === nothing
        # n=1: curve starts at this anyon; delete everything from a2e_1 through e2a_2
        pos_start = find_cref_index(l, curve_id, CurvepieceRef(tile_id, a2e_id))
        anyon2_tile = next_anyon(l, tile_id)
        t2 = get_tile(l, anyon2_tile)
        e2a_in_2 = only(cp_id for cp_id in anyon_cp_ids(t2) if anyon_eref(t2, cp_id).endpoint_idx == 2)
        pos_end = find_cref_index(l, curve_id, CurvepieceRef(anyon2_tile, e2a_in_2))
        for pos in pos_end:-1:pos_start
            ref = get_curvediagram(l, curve_id)[pos]
            remove_curvepiece!(get_tile(l, ref.tile_id), ref.cp_id)
            _remove_cref!(l, curve_id, pos)
        end
        _shift_anyon_count!(l, curve_id, pos_start, -1)

    elseif a2e_id === nothing
        # n=N: curve ends at this anyon; delete everything from a2e_{N-1} through e2a_N
        pos_end = find_cref_index(l, curve_id, CurvepieceRef(tile_id, e2a_id))
        prev_tile = prev_anyon(l, tile_id)
        t_prev = get_tile(l, prev_tile)
        a2e_in_prev = only(cp_id for cp_id in anyon_cp_ids(t_prev) if anyon_eref(t_prev, cp_id).endpoint_idx == 1)
        pos_start = find_cref_index(l, curve_id, CurvepieceRef(prev_tile, a2e_in_prev))
        for pos in pos_end:-1:pos_start
            ref = get_curvediagram(l, curve_id)[pos]
            remove_curvepiece!(get_tile(l, ref.tile_id), ref.cp_id)
            _remove_cref!(l, curve_id, pos)
        end

    else
        # middle: merge e2a + a2e into a single e2e curvepiece
        pos_e2a = find_cref_index(l, curve_id, CurvepieceRef(tile_id, e2a_id))
        pos_a2e = pos_e2a + 1
        new_cp_id = remove_anyon!(t)
        _remove_cref!(l, curve_id, pos_a2e)
        _remove_cref!(l, curve_id, pos_e2a)
        _insert_cref!(l, curve_id, pos_e2a, CurvepieceRef(tile_id, new_cp_id))
        _shift_anyon_count!(l, curve_id, pos_e2a + 1, -1)
    end

    isempty(get_curvediagram(l, curve_id)) && _delete_curvediagram!(l, curve_id)
    simplify!(l)
end

###############################################################################
# ANYON MOVE
###############################################################################

"""

"""
function move_anyon!(l::Lattice, tile_id1::Int, tile_id2::Int)

end
