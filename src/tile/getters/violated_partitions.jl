"""
Return a list of all `EndpointRef`s in `erefs` whose tile partners in `t`, if
they exist, are not in `erefs`.

Each element of `erefs` must refer to an `EdgeEndpoint`, otherwise the result
may be incorrect.
"""
function _erefs_with_external_tile_partner(t::Tile, erefs::Set{EndpointRef})
    externaltilepartner::Set{EndpointRef} = Set()
    for e in erefs
        tp = tile_partner(t, e, EdgeEndpoint)
        if tp !== nothing && tp ∉ erefs
            push!(externaltilepartner, e)
        end
    end
    externaltilepartner
end

"""
Return the set of partitions in `t` which would be violated if a new partition
with endpoints at `(edge1, pos1)` and `(edge2, pos2)` was created. Partitions
formed using an eref in `exclude` are not considered, meaning they will not be
in the output even if they are violated by the new partition. Each element of
`exclude` must refer to an `EdgeEndpoint`, otherwise the result may be incorrect.

Location arguments should be given in pre-insertion coordinates, meaning that
the effect of inserting at pos1 is not considered when calculating pos2.

A partition P in a tile is a pair of edge endpoints which are tile partners. Let
- P1 and P2 be the two endpoints respectively
- PA1 be the set of endpoints contained in the clockwise walk from P1 to P2
- PA2 be the set of endpoints contained in the counterclockwise walk from P1 to P2
- PC be the set of curvepieces which contain P1 and/or P2

Because tile partners are unique, P can be defined by either P1 or P2 alone.

Because tile partners must always have opposing directions, we can let P1 and P2
be the OUT and IN `EdgeEndpoint`s. Then we can uniquely assign names to the two
arcs PA1 and PA2: PA1 and PA2 are the 'clockwise arc' and 'counterclockwise arc'
of the partition respectively. The sets PA1, PA2, and {A, B} partition the set of
edge erefs in the tile, hence the name.

If P1 and P2 are on the same boundary curvepiece, PC will just contain it. If they
are not, then by virtue of being tile partners, they must be on the two central
curvepieces in the tile, which will both be in PC. In either case, the curvepieces
in PC split the area of the tile into two parts.

A partition P is violated by another partition Q if the endpoints Q1 and Q2 of Q
are in different arcs of P. This is equivalent to saying that the curvepieces in
PC intersect the curvepieces in QC, which can be verified easily by drawing.

Therefore, this function detects, given the prospective endpoint locations of
either a boundary curvepiece or a pair of central curvepieces, whether inserting
those curvepieces will cause any curvepiece intersections with curvepieces already
in the tile.

Return a set of erefs which each define one existing partition which would be
violated by the proposed new partition.
"""
function violated_partitions(t::Tile, edge1::Int, pos1::Int, edge2::Int, pos2::Int;
    exclude::Set{EndpointRef}=Set{EndpointRef}()
)
    # get erefs in the clockwise arc of P (P is defined by the function arguments)
    arc = Set(edge_eref_clockwise_arc(t, edge1, pos1, edge2, pos2 - 1))
    # add the tile partners of the erefs to exclude, so if the one in exclude isn't
    # in arc, its tile partner will be and the exclusion will still occur
    full_exclude = copy(exclude)
    for e in exclude
        tp = tile_partner(t, e, EdgeEndpoint)
        if tp !== nothing
            push!(full_exclude, tp)
        end
    end
    # remove excluded erefs from arc, so they're not checked
    filter!(eref -> eref ∉ full_exclude, arc)
    # erefs in arc with tp not in arc define partitions violated by P
    _erefs_with_external_tile_partner(t, arc)
end
