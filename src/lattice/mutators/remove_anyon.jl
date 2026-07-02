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
    cid = curve_id(t)
    cid === nothing && return

    # classify the anyon cps: e2a has anyon at endpoint2, a2e has anyon at endpoint1
    e2a_id = nothing
    a2e_id = nothing
    for cp_id in central_curvepiece_ids(t)
        if anyon_eref(t, cp_id).endpoint_idx == 2
            e2a_id = cp_id
        else
            a2e_id = cp_id
        end
    end

    if e2a_id === nothing
        # n=1: curve starts at this anyon; delete everything from a2e_1 through e2a_2
        pos_start = find_cref_index(l, cid, CurvepieceRef(tile_id, a2e_id))
        anyon2_tile = next_anyon(l, tile_id)
        t2 = get_tile(l, anyon2_tile)
        e2a_in_2 = only(cp_id for cp_id in central_curvepiece_ids(t2) if anyon_eref(t2, cp_id).endpoint_idx == 2)
        pos_end = find_cref_index(l, cid, CurvepieceRef(anyon2_tile, e2a_in_2))
        for pos in pos_end:-1:pos_start
            ref = get_curve(l, cid)[pos]
            remove_curvepiece!(get_tile(l, ref.tile_id), ref.cp_id)
            _remove_cref!(l, cid, pos)
        end
        _shift_anyon_count!(l, cid, pos_start, -1)

    elseif a2e_id === nothing
        # n=N: curve ends at this anyon; delete everything from a2e_{N-1} through e2a_N
        pos_end = find_cref_index(l, cid, CurvepieceRef(tile_id, e2a_id))
        prev_tile = prev_anyon(l, tile_id)
        t_prev = get_tile(l, prev_tile)
        a2e_in_prev = only(cp_id for cp_id in central_curvepiece_ids(t_prev) if anyon_eref(t_prev, cp_id).endpoint_idx == 1)
        pos_start = find_cref_index(l, cid, CurvepieceRef(prev_tile, a2e_in_prev))
        for pos in pos_end:-1:pos_start
            ref = get_curve(l, cid)[pos]
            remove_curvepiece!(get_tile(l, ref.tile_id), ref.cp_id)
            _remove_cref!(l, cid, pos)
        end

    else
        # middle: merge e2a + a2e into a single e2e curvepiece
        pos_e2a = find_cref_index(l, cid, CurvepieceRef(tile_id, e2a_id))
        pos_a2e = pos_e2a + 1
        new_cp_id = anyon_merge!(t)
        _remove_cref!(l, cid, pos_a2e)
        _remove_cref!(l, cid, pos_e2a)
        _insert_cref!(l, cid, pos_e2a, CurvepieceRef(tile_id, new_cp_id))
        _shift_anyon_count!(l, cid, pos_e2a + 1, -1)
    end

    isempty(get_curve(l, cid)) && _delete_curvediagram!(l, cid)
    simplify!(l)
end
