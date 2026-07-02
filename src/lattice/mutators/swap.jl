"""
Swap two sequential anyons on the same `Curve` which are in neighboring tiles
`tile_id1` and `tile_id2`. The anyons must be 'directly connected', meaning that
between them are exactly two central curvepieces, one outgoing in the first tile
and one incoming in the second tile; these central curvepieces must be siblings
across the tiles' shared edge. The value of `dir` indicates whether to carry out
a (+1) 'counterclockwise' or (-1) 'clockwise' swap.

Throw an error if:
- the tiles provided do not share an edge
- A1, A2, and M are not as described below

A swap should be interpreted as changing the basis the lattice quantum state is
written in, not changing the physical state of the lattice itself. In other words,
we are only changing the ordering of anyons on a curve diagram, not the lattice
locations of any anyons.

To clarify the setup:
- T1 and T2 are neighboring tiles containing the two anyons A1 and A2 respectively
- E is the edge shared between T1 and T2
- A1 and A2 are connected by a sequence, M = (M1, M2), of two central curvepieces,
both part of the same `Curve` C
- M1 is outgoing from A1 to E, while M2 is incoming from E to A2
- M1 and M2 are siblings across E
- P, if it exists, is the (incoming central) curvepiece before M1 in C
- N, if it exists, is the (outgoing central) curvepiece after M2 in C
- E1 is the edge in T1 which hosts P's `EdgeEndpoint` (first endpoint)
- E2 is the edge in T2 which hosts N's `EdgeEndpoint` (second endpoint)

So the entire sequence of curvepieces in C is:
- P: E1 -> A1
- M1: A1 -> E
- M2: E -> A2
- N: E2 -> A2

If A1 is the first anyon in C, P will not be present. If A2 is the last anyon in
C, N will not be present.

The swap consists of three steps, one to modify each of P, M, and N respectively:
- M is always guaranteed to be present, and we just reverse its direction to get
MR, which goes A2 -> E via M2R, an outgoing central curvepiece in T2, then E -> A1
via M2R, an incoming central curvepiece in T1; M1R and M2R are the reversed M1 and
M2
- P's anyon endpoint is 'detached' from A1 and pulled/stretched alongside MR to
attach to A2; this requires crossing E, and therefore P becomes two curvepieces,
P1, which is a boundary curvepiece going from E1 to E, and P2, an incoming central
curvepiece going from E to A2
- Similarly, N's anyon endpoint is 'detached' from A2 and pulled/stretched alongside
MR to attach to A1; this requires crossing E, and therefore N becomes two curvepieces,
N1, which is an outgoing central curvepiece going from A1 to E, and N2, a boundary
curvpeiece going from E to E2

Therefore, after the swap, the sequence of curvepieces in the curve diagram is:
- P1: E1 -> E
- P2: E -> A2
- M2R: A2 -> E
- M1R: E -> A1
- N1: from A1 -> E
- N2: from E -> E2

P1 and P2 will only be present if P was present initially. N1 and N2 will only be
present if N was present initially.

P and N are pulled alongside MR on 'opposite sides'. That is, if we orient the
lattice so that MR is horizontal, one goes above M, and one goes below it. In
other words, the position of the edge endpoints of P2 and N2 will be at +1
and -1 offsets from the position of the edge endpoint in the middle of M.
Which one is +1 and which one is -1 depends on the value of `dir`: `dir` sets
the relative position of P2's edge endpoint.

Returns `action = [3, curve_id, seg, dir]`, where `seg` is the segment index between the
two anyons before the swap.
"""
function swap!(l::Lattice, tile_id1::Int, tile_id2::Int, dir::Int)
    # inserting before (dir=-1) requires offset +0, inserting after (dir=+1) requires offset +1
    dir ∈ (-1, 1) || throw(ArgumentError("dir must be ±1, got $dir"))
    pos_offset, pos_offset_inverse = dir == 1 ? (1, 0) : (0, 1)
    # get tiles
    t1 = get_tile(l, tile_id1)
    t2 = get_tile(l, tile_id2)
    # find edge nums of E in T1 and T2
    shared = shared_edge(l, tile_id1, tile_id2)
    shared !== nothing || throw(ArgumentError("tiles $tile_id1 and $tile_id2 do not share an edge"))
    e_t1, e_t2 = shared
    # P (incoming) and M1 (outgoing) in T1; M2 (incoming) and N (outgoing) in T2
    p_id, p_cp, m1_id, m1_cp = ordered_central_curvepieces(t1)
    m2_id, m2_cp, n_id, n_cp = ordered_central_curvepieces(t2)
    # curve_id and anyon_count value setup
    cid = m1_cp.curve_id
    acount_m = m1_cp.anyon_count
    new_acount_p = acount_m + 1 # was - 1, if it exists
    new_acount_n = acount_m - 1 # was + 1, if it exists
    # figure out how many (and which) crefs to remove
    m1_cref = CurvepieceRef(tile_id1, m1_id)
    m2_cref = CurvepieceRef(tile_id2, m2_id)
    start_cref = isnothing(p_id) ? m1_cref : CurvepieceRef(tile_id1, p_id)
    start_cref_idx = find_cref_index(l, cid, start_cref)
    num_old_crefs = (isnothing(p_id) ? 0 : 1) + 2 + (isnothing(n_id) ? 0 : 1)
    # step 1: reverse M1 and M2
    reverse_curvepiece!(t1, m1_id)
    reverse_curvepiece!(t2, m2_id)
    # step 2: turn P into P1 and N into N2
    if !isnothing(p_id)
        # move P's AnyonEndpoint to e_t1
        p1_pos = last(m1_cp).pos + pos_offset
        move_endpoint!(t1, anyon_eref(t1, p_id), e_t1, p1_pos)
    end
    if !isnothing(n_id)
        # move N's AnyonEndpoint to e_t2
        n2_pos = first(m2_cp).pos + pos_offset
        move_endpoint!(t2, anyon_eref(t2, n_id), e_t2, n2_pos)
    end
    # step 3: insert N1 (A1 -> e_t1) and P2 (e_t2 -> A2)
    m1r_cp = curvepiece(t1, m1_id) # get updated curvepieces after step 2
    m2r_cp = curvepiece(t2, m2_id)
    if !isnothing(n_id)
        n1_pos = first(m1r_cp).pos + pos_offset_inverse
        n1_id = insert_curvepiece!(t1, cid, new_acount_n, e_t1, n1_pos, OUT)
    end
    if !isnothing(p_id)
        p2_pos = last(m2r_cp).pos + pos_offset_inverse
        p2_id = insert_curvepiece!(t2, cid, new_acount_p, e_t2, p2_pos, IN)
    end
    # step 4: update Curve: [P, M1, M2, N] -> [P1, P2, M2R, M1R, N1, N2]
    # ids (and hence crefs) preserved: P -> P1, N -> N2, M1 -> M1R, M2 -> M2R
    for _ in 1:num_old_crefs
        _remove_cref!(l, cid, start_cref_idx)
    end
    idx = start_cref_idx
    if !isnothing(p_id)
        _insert_cref!(l, cid, idx, CurvepieceRef(tile_id1, p_id))
        idx += 1
        _insert_cref!(l, cid, idx, CurvepieceRef(tile_id2, p2_id))
        idx += 1
    end
    _insert_cref!(l, cid, idx, m2_cref)
    idx += 1
    _insert_cref!(l, cid, idx, m1_cref)
    idx += 1
    if !isnothing(n_id)
        _insert_cref!(l, cid, idx, CurvepieceRef(tile_id1, n1_id))
        idx += 1
        _insert_cref!(l, cid, idx, CurvepieceRef(tile_id2, n_id))
    end

    [3, curve_id, idx, dir]
end
