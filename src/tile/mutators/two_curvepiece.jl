################################################################################
# EDGE SPLIT/MERGE
################################################################################

"""
Split the curvepiece `cp_id` into two at location `(edge, pos)` in `t`. Return
the curvepiece ids of the resulting two curvepieces.

Throw an error if the proposed move would lead to intersecting curvepieces. Omit
this validation by passing in `check_intersections=false`.

This operation is the inverse of `merge_curvepieces!`, up to curvepiece ids.

By 'split' we mean that if the curvepiece has (in traversal order) two endpoints
`erefA` and `erefB`:
- the original curvepiece is removed
- two new edge endpoints, `eref1` and `eref2`, are created
- two new curvepieces are created, going from `erefA` to `eref1` and `eref2` to
`erefB`

`eref1` will be located at either `pos` or `pos+1` on `edge`, with `eref2` at the
other location. There are two ways to do this assignment. In the case that `cp_id`
is the only central curvepiece in `t`, either assignment will be valid, so
we can arbitrarily choose the one where the outgoing curvepiece has its eref at
`pos`. In all other cases, only one of the assignments will be valid.

To determine which is valid, suppose `cp_id` is:
- a boundary curvepiece. Then let `erefX` and `erefY` be `erefA` and `erefB`.
- one of two central curvepieces in the tile. Then let `erefX` and `erefY` be (in
traversal order) their collective two edge endpoints (they have one each).

If a clockwise traversal of edge erefs starting from `pos` on `edge` encounters
`erefX` before it encounters `erefY`, then `eref1` should be at `pos+1`. Otherwise,
it should be at `pos`. This ensures that on a traversal of the endpoints, the
encounter order is `erefX`, `eref1`, `eref2`, `erefY`, which ensures that there
are no intersections.
"""
function edge_split!(
    t::Tile, cp_id::Int, edge::Int, pos::Int;
    check_intersections::Bool=true,
)
    # fetch existing curvepiece
    cp = curvepiece(t, cp_id)
    cid = cp.curve_id
    acount = cp.anyon_count
    # determine the relative ordering of eref2 compared to eref1
    if num_anyon_erefs(t) == 1 && is_central_curvepiece(t, cp_id)
        relpos = :ccw
    else
        # find erefX/Y
        if first(cp) isa EdgeEndpoint && last(cp) isa EdgeEndpoint
            erefX = EndpointRef(cp_id, 1)
            erefY = EndpointRef(cp_id, 2)
        else
            if first(cp) isa EdgeEndpoint
                erefX = EndpointRef(cp_id, 1)
                erefY = EndpointRef(other_central_curvepiece_id(t, cp_id), 2)
            else
                erefX = EndpointRef(other_central_curvepiece_id(t, cp_id), 1)
                erefY = EndpointRef(cp_id, 2)
            end
        end
        # determine if erefX is in the clockwise arc from the insertion position to erefY
        epY = endpoint(t, erefY)::EdgeEndpoint
        relpos = erefX ∈ edge_eref_clockwise_arc(t, edge, pos, epY.edge, epY.pos - 1) ? :ccw : :cw
    end
    # insert dummy u-turn at the split position -- remember to clean it up
    d_id = insert_curvepiece!(t, -1, 1, edge, pos, edge, pos)
    # insert new boundary curvepiece, then remove dummy
    try
        if first(cp) isa EdgeEndpoint
            # cp_id is incoming or boundary: first curvepiece is boundary
            cp_id1 = insert_curvepiece!(t, cid, acount,
                :cw, EndpointRef(cp_id, 1), IN,
                :cw, EndpointRef(d_id, 1), OUT;
                check_intersections=check_intersections,
                ignore_ids=Set([cp_id, d_id]),
            )
        else
            # cp_id is outgoing: second curvepiece is boundary
            cp_id2 = insert_curvepiece!(t, cid, acount,
                :cw, EndpointRef(d_id, 1), IN,
                :cw, EndpointRef(cp_id, 2), OUT;
                check_intersections=check_intersections,
                ignore_ids=Set([cp_id, d_id]),
            )
        end
    catch e
        remove_curvepiece!(t, d_id)
        rethrow(e)
    else
        remove_curvepiece!(t, d_id)
    end
    # insert other curvepiece
    if is_central_curvepiece(t, cp_id)
        remove_curvepiece!(t, cp_id)
        if first(cp) isa EdgeEndpoint
            # cp_id is incoming: second curvpiece is incoming central
            cp_id2 = insert_curvepiece!(t, cid, acount,
                relpos, EndpointRef(cp_id1, 2), IN;
                check_intersections=check_intersections,
            )
        else
            # cp_id is outgoing: first curvepiece is outgoing central
            inverted_relpos = relpos == :cw ? :ccw : :cw
            cp_id1 = insert_curvepiece!(t, cid, acount,
                inverted_relpos, EndpointRef(cp_id2, 1), OUT;
                check_intersections=check_intersections,
            )
        end
    else
        # cp_id is boundary: second curvpeiece is boundary
        cp_id2 = insert_curvepiece!(t, cid, acount,
            :cw, EndpointRef(cp_id, 2), OUT,
            relpos, EndpointRef(cp_id1, 2), IN;
            check_intersections=check_intersections,
            ignore_ids=Set(cp_id),
        )
        remove_curvepiece!(t, cp_id)
    end
    # return cp_ids of newly created pair of curvepieces
    cp_id1, cp_id2
end

"""
Merge two curvepieces in `t` at the specified edge endpoints `eref1` and `eref2`.
Return the curvepiece id of the resulting merged curvepiece.

Throw an error if the proposed move would lead to intersecting curvepieces. Omit
this validation by passing in `check_intersections=false`.

This operation is effectively the inverse of `edge_split!`, up to curvepiece ids.

By 'merge' we mean:
- suppose `eref1` belongs to `curvepiece1`, whose other endpoint is `erefA`
- suppose `eref2` belongs to `curvepiece2`, whose other endpoint is `erefB`
- `curvepiece1` and `curvepiece2` will be replaced with a single curvepiece going
with the endpoints referred to by `erefA` and `erefB`

Throw an error if `eref1` and `eref2` are not edge endpoints with different
directions located on different curvepieces. Throw an error if these curvepieces
are not both on the same `Curve`. These conditions are required for the operation
to result in a valid curvepiece.

This function is intended for use as a subroutine when removing U-turns and
trivial bends in lattices.
"""
function edge_merge!(
    t::Tile, eref1::EndpointRef, eref2::EndpointRef;
    check_intersections::Bool=true,
)
    # fetch curve_id, anyon_count
    cp1 = curvepiece(t, eref1.cp_id)
    cp2 = curvepiece(t, eref1.cp_id)
    cid = cp1.curve_id
    acount = cp1.anyon_count
    # validate
    eref1.cp_id != eref2.cp_id || throw(ArgumentError("eref1 and eref2 must be on different curvepieces"))
    ep1::EdgeEndpoint = endpoint(t, eref1)
    ep2::EdgeEndpoint = endpoint(t, eref2)
    ep1.direction != ep2.direction || throw(ArgumentError("eref1 and eref2 must have different directions"))
    cp1.curve_id == cp2.curve_id || throw(ArgumentError("eref1 and eref2 must be on the same curve"))
    cp1.anyon_count == cp2.anyon_count || throw(ArgumentError("eref1 and eref2 must have the same anyon_count"))
    # identify surviving endpoints erefA (partner of eref1) and erefB (partner of eref2)
    erefA = curvepiece_partner(eref1)
    erefB = curvepiece_partner(eref2)
    epA = endpoint(t, erefA)
    epB = endpoint(t, erefB)
    # ignore curvepiece1 and 2 for the purposes of insertion validation
    ignore_ids = Set([eref1.cp_id, eref2.cp_id])
    # three result cases
    if epA isa EdgeEndpoint && epB isa EdgeEndpoint
        # boundary
        cp_id = insert_curvepiece!(t, cid, acount,
            :ccw, erefA, epA.direction,
            :ccw, erefB, epB.direction;
            ignore_ids=ignore_ids,
        )
    else
        if epA isa EdgeEndpoint
            # incoming central
            cp_id = insert_curvepiece!(t, cid, acount,
                :ccw, erefA, epA.direction;
                check_intersections=check_intersections,
                ignore_ids=ignore_ids,
            )
        else
            # outgoing central
            cp_id = insert_curvepiece!(t, cid, acount,
                :ccw, erefB, epB.direction;
                ignore_ids=ignore_ids,
            )
        end
    end
    cp_id
end

################################################################################
# ANYON SPLIT/MERGE
################################################################################

"""
Split the specified boundary curvepiece `cp_id` into a pair of central curvepieces,
one incoming and one outgoing, preserving the overall traversal direction.
Effectively 'inserts' an anyon into the middle of the boundary curvepiece.

In detail, if `erefA` and `erefB` are the endpoints of `cp_id`, in traversal
order, then:
- `cp_id` will be removed
- an incoming central curvepiece C1 will be inserted from `erefA` to the anyon
- an outgoing central curvepiece C2 will be inserted from the anyon to `erefB`
- the `curve_id`s of C1 and C2 will be inherited from `cp_id`
- the `anyon_count` of C1 will be inherited from `cp_id`, while the `anyon_count`
of C2 will be 1 greater than that of `cp_id`

This operation is the inverse of `anyon_merge!`, up to curvepiece ids.

Throw an error if `t` already has any central curvepieces. Return the curvepiece
ids of the two newly created central curvepieces.
"""
function anyon_split!(t::Tile, cp_id::Int)
    num_anyon_erefs(t) == 0 || throw(ArgumentError("tile already has anyon endpoints"))
    # fetch curve_id, anyon_count
    cp = curvepiece(t, cp_id)
    cid = cp.curve_id
    acount = cp.anyon_count
    # insert incoming/outgoing central curvepieces
    cp_id1 = insert_curvepiece!(t, cid, acount,
        :ccw, EndpointRef(cp_id, 1), IN;
        check_intersections=false, # not possible to intersect if cp_id was nonintersecting
    )
    cp_id2 = insert_curvepiece!(t, cid, acount + 1,
        :ccw, EndpointRef(cp_id, 2), OUT;
        check_intersections=false, # not possible to intersect if cp_id was nonintersecting
    )
    # remove initial boundary curvepiece and return new cp_ids
    remove_curvepiece!(t, cp_id)
    cp_id1, cp_id2
end

"""
Merge `t`'s two central curvepieces together into a single boundary curvepiece,
preserving the overall traversal direction. Effectively 'removes' the anyon from
the middle of the pair.

In detail, if `erefA` and `erefB` are the `EdgeEndpoints` of the two central
curvepieces in traversal order (i.e. `erefA` and `erefB` belong to the incoming
and outgoing central curvepieces respectively), and `eref1` and `eref2` are the
two `AnyonEndpoints`, then the result of this function will be:
- the two central curvpieces are removed
- a new boundary curvepiece from `erefA` to `erefB` is created, with a `curve_id`
and `anyon_count` equal to the incoming central curvepiece's `curve_id` and
`anyon_count`

This operation is the inverse of `anyon_split!`, up to curvepiece ids.

Throw an error if the tile does not contain two central curvepieces. Return the
curvepiece_id of the newly created boundary curvepiece.
"""
function anyon_merge!(t::Tile)
    num_anyon_erefs(t) == 2 || throw(ArgumentError("tile must have exactly two central curvepieces"))
    incoming_id, incoming, outgoing_id, outgoing = ordered_central_curvepieces(t)
    # fetch curve_id, anyon_count
    cid = incoming.curve_id
    acount = incoming.anyon_count
    # insert new boundary curvepiece
    cp_id = insert_curvepiece!(t, cid, acount,
        :ccw, EndpointRef(incoming_id, 1), IN,
        :ccw, EndpointRef(outgoing_id, 2), OUT;
        check_intersections=false, # not possible to intersect if incoming and outgoing were nonintersecting
    )
    remove_curvepiece!(t, incoming_id)
    remove_curvepiece!(t, outgoing_id)
    cp_id
end
