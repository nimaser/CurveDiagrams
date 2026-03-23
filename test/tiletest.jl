using CurveDiagrams
import CurveDiagrams: _allocate_cp_id!, _set_endpoint_location!, _set_endpoint_pos!,
    _insert_edge_EndpointRef!, _remove_edge_EndpointRef!, _push_anyon_EndpointRef!

@testset "Endpoint and Curvepiece" begin
    # random filler values that shouldn't affect test results
    maxrandval = 6
    edge1, pos1 = rand(1:maxrandval), rand(1:maxrandval)
    edge2, pos2 = rand(1:maxrandval), rand(1:maxrandval)
    id, count = rand(1:maxrandval), rand(1:maxrandval)
    # construct four representative curvepiece endpoints
    ae_in = AnyonEndpoint(IN)
    ae_out = AnyonEndpoint(OUT)
    ee_in = EdgeEndpoint(IN, edge1, pos1)
    ee_out = EdgeEndpoint(OUT, edge2, pos2)
    # check that they have the right type hierarchy
    @test ae_in isa CurvepieceEndpoint
    @test ae_out isa CurvepieceEndpoint
    @test ee_in isa CurvepieceEndpoint
    @test ee_out isa CurvepieceEndpoint
    # check that two anyon endpoints cannot be on the same curvepiece
    @test_throws ArgumentError Curvepiece(id, count, ae_in, ae_in)
    @test_throws ArgumentError Curvepiece(id, count, ae_in, ae_out)
    @test_throws ArgumentError Curvepiece(id, count, ae_out, ae_in)
    @test_throws ArgumentError Curvepiece(id, count, ae_out, ae_out)
    # check that two edge endpoints on a curvepiece cannot have the same direction
    @test_throws ArgumentError Curvepiece(id, count, ee_in, ee_in)
    @test_throws ArgumentError Curvepiece(id, count, ee_out, ee_out)
    # check that an edge and anyon endpoint in the same curvepiece cannot have different directions
    @test_throws ArgumentError Curvepiece(id, count, ae_in, ee_out)
    @test_throws ArgumentError Curvepiece(id, count, ae_out, ee_in)
    @test_throws ArgumentError Curvepiece(id, count, ee_in, ae_out)
    @test_throws ArgumentError Curvepiece(id, count, ee_out, ae_in)
    # check that endpoints are automatically correctly ordered for the three valid cases
    @test Curvepiece(id, count, ee_in, ae_in) == Curvepiece(id, count, ae_in, ee_in)
    @test Curvepiece(id, count, ee_out, ae_out) == Curvepiece(id, count, ae_out, ee_out)
    @test Curvepiece(id, count, ee_in, ee_out) == Curvepiece(id, count, ee_out, ee_in)
end

@testset "EndpointRef" begin
    # random filler values that shouldn't affect test results
    maxrandval = 6
    cp_id = rand(1:maxrandval)
    endpoint_idx = rand(1:maxrandval)
    # check that we can construct an EndpointRef
    eref = EndpointRef(cp_id, endpoint_idx)
    @test eref.cp_id == cp_id
    @test eref.endpoint_idx == endpoint_idx
end

@testset "Tile public getters" begin
    # set up a 5-edge tile with edges 1-4 populated and edge 5 empty; the curvepieces are:
    # cp1 (id=1, curve 10): Edge(IN,1,1) -> Edge(OUT,4,2)
    # cp2 (id=2, curve 20): Edge(IN,1,2) -> Edge(OUT,1,3)  [both endpoints on edge 1]
    # cp3 (id=3, curve 30): Edge(IN,2,1) -> Anyon(IN)
    # cp4 (id=4, curve 30): Anyon(OUT) -> Edge(OUT,4,1)
    t = Tile(5)
    # make curvepieces
    c1 = Curvepiece(10, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 4, 2))
    c2 = Curvepiece(20, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 1, 3))
    c3 = Curvepiece(30, 2, EdgeEndpoint(IN, 2, 1), AnyonEndpoint(IN))
    c4 = Curvepiece(30, 3, AnyonEndpoint(OUT), EdgeEndpoint(OUT, 4, 1))
    t._curvepieces[1] = c1
    t._curvepieces[2] = c2
    t._curvepieces[3] = c3
    t._curvepieces[4] = c4
    # put endpointrefs on edges
    push!(t._edge_endpoints[1], EndpointRef(1, 1))  # edge 1 pos 1
    push!(t._edge_endpoints[1], EndpointRef(2, 1))  # edge 1 pos 2
    push!(t._edge_endpoints[1], EndpointRef(2, 2))  # edge 1 pos 3
    push!(t._edge_endpoints[2], EndpointRef(3, 1))  # edge 2 pos 1
    push!(t._edge_endpoints[4], EndpointRef(4, 2))  # edge 4 pos 1
    push!(t._edge_endpoints[4], EndpointRef(1, 2))  # edge 4 pos 2
    push!(t._anyon_endpoints, EndpointRef(3, 2))    # cp3 AnyonEndpoint(IN)
    push!(t._anyon_endpoints, EndpointRef(4, 1))    # cp4 AnyonEndpoint(OUT)

    # set up a 3-edge tile with a single anyon-to-edge curvepiece - only used in anyon curvepiece tests
    t1 = Tile(3)
    @test num_anyon_curvepieces(t1) == 0
    t1._curvepieces[5] = Curvepiece(5, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
    push!(t1._edge_endpoints[1], EndpointRef(5, 1))
    push!(t1._anyon_endpoints, EndpointRef(5, 2))

    # num_edges
    @test num_edges(t) == 5

    # next_edge / prev_edge — mid-range and wrap-around
    @test next_edge(t, 3) == 4
    @test next_edge(t, 5) == 1
    @test prev_edge(t, 2) == 1
    @test prev_edge(t, 1) == 5

    # has_endpoints
    @test has_endpoints(t, 1)
    @test !has_endpoints(t, 3)

    # num_endpoints
    @test num_endpoints(t, 1) == 3
    @test num_endpoints(t, 2) == 1
    @test num_endpoints(t, 3) == 0

    # num_anyon_curvepieces
    @test num_anyon_curvepieces(t) == 2
    @test num_anyon_curvepieces(t1) == 1

    # curvepiece_ids — sorted
    @test curvepiece_ids(t) == [1, 2, 3, 4]

    # get_curvepiece
    @test get_curvepiece(t, 1) == c1
    @test get_curvepiece(t, 3) == c3

    # get_endpoint
    @test get_endpoint(t, EndpointRef(1, 1)) == c1.endpoint1
    @test get_endpoint(t, EndpointRef(1, 2)) == c1.endpoint2
    @test get_endpoint(t, EndpointRef(2, 1)) == c2.endpoint1
    @test get_endpoint(t, EndpointRef(2, 2)) == c2.endpoint2
    @test get_endpoint(t, EndpointRef(3, 1)) == c3.endpoint1
    @test get_endpoint(t, EndpointRef(3, 2)) == c3.endpoint2
    @test get_endpoint(t, EndpointRef(4, 1)) == c4.endpoint1
    @test get_endpoint(t, EndpointRef(4, 2)) == c4.endpoint2

    # get_edge_EndpointRef, fetches erefs by edge and position
    @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(1, 1)
    @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(2, 1)
    @test get_edge_EndpointRef(t, 1, 3) == EndpointRef(2, 2)
    @test get_edge_EndpointRef(t, 2, 1) == EndpointRef(3, 1)
    @test get_edge_EndpointRef(t, 4, 1) == EndpointRef(4, 2)
    @test get_edge_EndpointRef(t, 4, 2) == EndpointRef(1, 2)

    # get_edge_EndpointRefs(t, edge) — multi-endpoint edge and empty edge
    @test get_edge_EndpointRefs(t, 1) == [EndpointRef(1,1), EndpointRef(2,1), EndpointRef(2,2)]
    @test get_edge_EndpointRefs(t, 3) == EndpointRef[]

    # get_edge_EndpointRefs(t) — all erefs concatenated in clockwise order, empty edges skipped
    @test get_edge_EndpointRefs(t) == [
        EndpointRef(1,1), EndpointRef(2,1), EndpointRef(2,2),   # edge 1
        EndpointRef(3,1),                                       # edge 2 (edge 3 is empty)
        EndpointRef(4,2), EndpointRef(1,2),                     # edge 4 (edge 5 is empty)
    ]

    # get_anyon_EndpointRefs, order doesn't matter
    @test Set(get_anyon_EndpointRefs(t)) == Set([EndpointRef(3,2), EndpointRef(4,1)])

    # get_partner_EndpointRef — flips endpoint_idx between 1 and 2
    @test get_partner_EndpointRef(EndpointRef(2, 1)) == EndpointRef(2, 2)
    @test get_partner_EndpointRef(EndpointRef(2, 2)) == EndpointRef(2, 1)

    # has_edge_partner / has_anyon_partner
    @test has_edge_partner(t, EndpointRef(1, 1))    # partner is Edge(OUT,4,2)
    @test !has_edge_partner(t, EndpointRef(3, 1))   # partner is Anyon
    @test has_anyon_partner(t, EndpointRef(3, 1))   # partner is Anyon
    @test !has_anyon_partner(t, EndpointRef(1, 1))  # partner is Edge
    @test has_anyon_partner(t, EndpointRef(4, 2))   # partner is Anyon(OUT)

    # get_anyon_EndpointRef — fetches from cp_id
    @test get_anyon_EndpointRef(t, 3) == EndpointRef(3, 2)
    @test get_anyon_EndpointRef(t, 4) == EndpointRef(4, 1)
    @test get_anyon_EndpointRef(t, 1) === nothing

    # is_anyon_curvepiece
    @test is_anyon_curvepiece(t, 3)
    @test !is_anyon_curvepiece(t, 1)

    # get_anyon_cp_ids, order doesn't matter
    @test Set(get_anyon_cp_ids(t)) == Set([3, 4])

    # get_partner_cp_id — two anyon cps, single anyon cp, and non-anyon cp
    @test get_partner_cp_id(t, 3) == 4
    @test get_partner_cp_id(t, 4) == 3
    @test get_partner_cp_id(t1, 5) === nothing
    @test_throws ArgumentError get_partner_cp_id(t, 1)

    # anyon_curve_id
    @test anyon_curve_id(t) == 30
    @test anyon_curve_id(t1) == 5

    # next_EndpointRef_on_edge
    @test next_EndpointRef_on_edge(t, 1, 1) == EndpointRef(2, 1)  # pos 1 -> pos 2
    @test next_EndpointRef_on_edge(t, 1, 2) == EndpointRef(2, 2)  # pos 2 -> pos 3
    @test next_EndpointRef_on_edge(t, 1, 3) === nothing            # at last pos on edge
    @test next_EndpointRef_on_edge(t, 2, 1) === nothing            # single endpoint on edge

    # prev_EndpointRef_on_edge
    @test prev_EndpointRef_on_edge(t, 1, 2) == EndpointRef(1, 1)  # pos 2 -> pos 1
    @test prev_EndpointRef_on_edge(t, 1, 3) == EndpointRef(2, 1)  # pos 3 -> pos 2
    @test prev_EndpointRef_on_edge(t, 1, 1) === nothing            # at first pos on edge
    @test prev_EndpointRef_on_edge(t, 2, 1) === nothing            # single endpoint on edge

    # next_EndpointRef
    @test next_EndpointRef(t, 1, 2) == EndpointRef(2, 2)  # same edge: pos 2 -> pos 3
    @test next_EndpointRef(t, 1, 3) == EndpointRef(3, 1)  # end of edge 1 -> first on edge 2
    @test next_EndpointRef(t, 2, 1) == EndpointRef(4, 2)  # end of edge 2 -> skips empty edge 3 -> first on edge 4
    @test next_EndpointRef(t, 4, 2) == EndpointRef(1, 1)  # end of edge 4 -> skips empty edge 5 -> first on edge 1

    # prev_EndpointRef
    @test prev_EndpointRef(t, 1, 2) == EndpointRef(1, 1)  # same edge: pos 2 -> pos 1
    @test prev_EndpointRef(t, 2, 1) == EndpointRef(2, 2)  # start of edge 2 -> last on edge 1
    @test prev_EndpointRef(t, 4, 1) == EndpointRef(3, 1)  # start of edge 4 -> skips empty edge 3 -> last on edge 2
    @test prev_EndpointRef(t, 1, 1) == EndpointRef(1, 2)  # start of edge 1 -> skips empty edge 5 -> last on edge 4
end

@testset "Tile internal mutators" begin
    # _allocate_cp_id! — sequential from 1
    let t = Tile(3)
        @test _allocate_cp_id!(t) == 1
        @test _allocate_cp_id!(t) == 2
        @test _allocate_cp_id!(t) == 3
    end

    # _set_endpoint_location! — updates edge and pos in curvepiece, leaves direction and partner unchanged
    let t = Tile(3)
        t._curvepieces[1] = Curvepiece(1, 0, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 2, 1))
        _set_endpoint_location!(t, EndpointRef(1, 1), 3, 2)
        ep = get_endpoint(t, EndpointRef(1, 1))
        @test ep.edge == 3 && ep.pos == 2 && ep.direction == IN
        @test get_endpoint(t, EndpointRef(1, 2)) == EdgeEndpoint(OUT, 2, 1)  # partner unchanged
    end

    # _set_endpoint_pos! — only pos changes, edge and direction preserved
    let t = Tile(3)
        t._curvepieces[1] = Curvepiece(1, 0, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 2, 1))
        _set_endpoint_pos!(t, EndpointRef(1, 1), 2)
        ep = get_endpoint(t, EndpointRef(1, 1))
        @test ep.edge == 1 && ep.pos == 2 && ep.direction == IN
        @test get_endpoint(t, EndpointRef(1, 2)) == EdgeEndpoint(OUT, 2, 1)  # partner unchanged
    end

    # _insert_edge_EndpointRef! - inserts eref and shifts existing ones up
    let t = Tile(3)
        # cp1 has both endpoints on edge 1 at initial positions 1 and 2
        t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 1, 2))
        _insert_edge_EndpointRef!(t, EndpointRef(1, 1), 1, 1)
        _insert_edge_EndpointRef!(t, EndpointRef(1, 2), 1, 2)
        # cp3's edge-1 endpoint (EndpointRef(3,2)) will be inserted at pos 1, shifting cp1 to pos 2 and 3
        t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 1, 1))
        _insert_edge_EndpointRef!(t, EndpointRef(3, 1), 3, 1)
        _insert_edge_EndpointRef!(t, EndpointRef(3, 2), 1, 1)
        # check that EndpointRefs are correct
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(3, 2)
        @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(1, 1)
        @test get_edge_EndpointRef(t, 1, 3) == EndpointRef(1, 2)
        # check that Endpoints are correct
        @test (get_endpoint(t, EndpointRef(1, 1))).pos == 2  # shifted
        @test (get_endpoint(t, EndpointRef(1, 2))).pos == 3  # shifted
    end

    # _remove_edge_EndpointRef! — removes eref and shifts existing ones down
    let t = Tile(3)
        # cp1 has endpoints at positions 2 and 3 on edge 1, cp3 has an endpoint at pos 1 on edge 1
        t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 1, 3))
        t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 1, 1))
        _insert_edge_EndpointRef!(t, EndpointRef(3, 2), 1, 1)
        _insert_edge_EndpointRef!(t, EndpointRef(1, 1), 1, 2)
        _insert_edge_EndpointRef!(t, EndpointRef(1, 2), 1, 3)
        # remove pos 1 on edge 1, shifting curvepiece 1's endpoints over
        _remove_edge_EndpointRef!(t, 1, 1)
        @test num_endpoints(t, 1) == 2
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(1, 1)
        @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(1, 2)
        @test (get_endpoint(t, EndpointRef(1, 1))::EdgeEndpoint).pos == 1  # shifted
        @test (get_endpoint(t, EndpointRef(1, 2))::EdgeEndpoint).pos == 2  # shifted
    end

    # _push_anyon_EndpointRef! — valid pushes succeed; 3rd push throws
    let t = Tile(3)
        t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
        t._curvepieces[2] = Curvepiece(2, 1, AnyonEndpoint(OUT), EdgeEndpoint(OUT, 2, 1))
        _push_anyon_EndpointRef!(t, EndpointRef(1, 2))
        @test num_anyon_curvepieces(t) == 1
        _push_anyon_EndpointRef!(t, EndpointRef(2, 1))
        @test num_anyon_curvepieces(t) == 2
        @test_throws ArgumentError _push_anyon_EndpointRef!(t, EndpointRef(3, 2)) # 3rd fails
    end
end

@testset "Tile public mutators" begin

    ### insert_curvepiece! edge-to-edge version ###

    # basic insertion: returns cp_id=1, creates correct curvepiece
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        @test id == 1
        cp = get_curvepiece(t, 1)
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == EdgeEndpoint(OUT, 3, 1)
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(1, 1)
        @test get_edge_EndpointRef(t, 3, 1) == EndpointRef(1, 2)
    end

    # cp_id increments on successive insertions
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 2, 1, 4, 1)
        @test id1 == 1
        @test id2 == 2
        @test curvepiece_ids(t) == [1, 2]
    end

    # same-edge insertion: pos2 is adjusted; both endpoints land correctly
    let t = Tile(4)
        # insert with pos1=1, pos2=1 (same edge, same raw position) ->
        # after inserting IN endpoint at pos 1, OUT should land at pos 2
        id = insert_curvepiece!(t, 10, 1, 1, 1, 1, 1)
        @test num_endpoints(t, 1) == 2
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(1, 1)
        @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(1, 2)
        ep1 = get_endpoint(t, EndpointRef(1, 1))::EdgeEndpoint
        ep2 = get_endpoint(t, EndpointRef(1, 2))::EdgeEndpoint
        @test ep1.pos == 1 && ep2.pos == 2
    end

    # inserting two curvepieces on the same edge shifts positions correctly
    let t = Tile(4)
        # cp1: edge1 pos1 (IN) -> edge3 pos1 (OUT)
        insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        # cp2: insert IN at edge1 pos1, shifts cp1's IN to pos2
        insert_curvepiece!(t, 20, 1, 1, 1, 2, 1)
        @test num_endpoints(t, 1) == 2
        # new cp2 IN is at pos 1, old cp1 IN shifted to pos 2
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(2, 1)
        @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(1, 1)
        # cp1's stored endpoint1 position should be updated
        @test (get_endpoint(t, EndpointRef(1, 1))::EdgeEndpoint).pos == 2
    end

    # validation: inserting a cp whose arc splits an existing cp's endpoints → error
    let t = Tile(4)
        # existing cp: edge1,pos1 (IN) -> edge3,pos1 (OUT)
        insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        # new cp would go edge2,pos1 -> edge4,pos1; the arc from edge2 to edge4
        # passes through edge3, where one endpoint of cp1 lives (pos1); its partner
        # is on edge1 which is outside the arc → invalid
        @test_throws ArgumentError insert_curvepiece!(t, 20, 1, 2, 1, 4, 1)
    end

    # validation: arc crossing one of two anyon-cp boundary points → error
    let t = Tile(4)
        # two anyon cps: their edge endpoints are at edge1,pos1 and edge3,pos1
        insert_curvepiece!(t, 5, 1, 1, 1, IN, 5, 1)
        insert_curvepiece!(t, 3, 1, IN, 5, 2)
        # new edge-to-edge cp from edge2,pos1 to edge4,pos1: arc from edge2→edge4
        # passes through edge3, pos1 (one anyon boundary), but not edge1, pos1 → invalid
        @test_throws ArgumentError insert_curvepiece!(t, 99, 1, 2, 1, 4, 1)
    end

    # --- insert_curvepiece! edge-to-anyon ---

    # first anyon cp is always valid; returns correct cp_id and stores endpoints
    let t = Tile(4)
        id = insert_curvepiece!(t, 1, 1, IN, 10, 1)
        @test id == 1
        @test num_anyon_curvepieces(t) == 1
        @test is_anyon_curvepiece(t, 1)
        cp = get_curvepiece(t, 1)
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
    end

    # second anyon cp with matching curve_id succeeds
    let t = Tile(4)
        insert_curvepiece!(t, 1, 1, IN, 10, 1)
        id2 = insert_curvepiece!(t, 3, 1, IN, 10, 2)
        @test num_anyon_curvepieces(t) == 2
        @test is_anyon_curvepiece(t, 2)
    end

    # third anyon cp throws
    let t = Tile(4)
        insert_curvepiece!(t, 1, 1, IN, 10, 1)
        insert_curvepiece!(t, 3, 1, IN, 10, 2)
        @test_throws ArgumentError insert_curvepiece!(t, 2, 1, IN, 10, 3)
    end

    # curve_id mismatch throws
    let t = Tile(4)
        insert_curvepiece!(t, 1, 1, IN, 10, 1)
        @test_throws ArgumentError insert_curvepiece!(t, 2, 1, IN, 99, 2)
    end

    # validation: second anyon cp whose partition splits an edge-to-edge cp → error
    let t = Tile(4)
        # edge-to-edge cp: edge1,pos1 -> edge3,pos1
        insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        # first anyon cp at edge2,pos1 (no partition yet, always valid)
        insert_curvepiece!(t, 2, 1, IN, 5, 1)
        # second anyon cp at edge4,pos1: partition goes from edge4,pos1 to edge2,pos1
        # the arc from edge4→edge2 passes through edge1 (one endpoint of the edge-to-edge cp)
        # but not edge3 → splits the edge-to-edge cp → invalid
        @test_throws ArgumentError insert_curvepiece!(t, 4, 1, IN, 5, 2)
    end

    # --- remove_curvepiece! ---

    # removing an edge-to-edge curvepiece cleans up both edge positions and shifts remaining
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 1, 2, 2, 1)  # IN at edge1,pos2
        remove_curvepiece!(t, id1)
        @test curvepiece_ids(t) == [id2]
        @test num_endpoints(t, 1) == 1
        @test num_endpoints(t, 3) == 0
        # cp2's endpoint1 was at edge1,pos2; after removing cp1 (which was at pos1) it shifts to pos1
        @test (get_endpoint(t, EndpointRef(id2, 1))::EdgeEndpoint).pos == 1
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(id2, 1)
    end

    # removing an anyon curvepiece cleans up anyon_endpoints
    let t = Tile(4)
        id = insert_curvepiece!(t, 1, 1, IN, 10, 1)
        @test num_anyon_curvepieces(t) == 1
        remove_curvepiece!(t, id)
        @test num_anyon_curvepieces(t) == 0
        @test isempty(curvepiece_ids(t))
    end

    # removing one of two anyon curvepieces leaves the other intact
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 1, 1, IN, 10, 1)
        id2 = insert_curvepiece!(t, 3, 1, IN, 10, 2)
        remove_curvepiece!(t, id1)
        @test num_anyon_curvepieces(t) == 1
        @test is_anyon_curvepiece(t, id2)
    end

    # --- move_endpoint! ---

    # basic move to a different edge
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        eref = EndpointRef(id, 1)  # the IN endpoint on edge 1
        move_endpoint!(t, eref, 2, 1)
        ep = get_endpoint(t, eref)::EdgeEndpoint
        @test ep.edge == 2 && ep.pos == 1
        @test num_endpoints(t, 1) == 0
        @test num_endpoints(t, 2) == 1
        @test get_edge_EndpointRef(t, 2, 1) == eref
    end

    # move forward on same edge
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 1, 2, 2, 1)
        # edge 1 now has: [EndpointRef(id1,1) at pos1, EndpointRef(id2,1) at pos2]
        # move cp1's IN from pos1 to pos3 (i.e., after cp2's IN)
        eref = EndpointRef(id1, 1)
        move_endpoint!(t, eref, 1, 3)
        @test num_endpoints(t, 1) == 2
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(id2, 1)
        @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(id1, 1)
        @test (get_endpoint(t, EndpointRef(id1, 1))::EdgeEndpoint).pos == 2
        @test (get_endpoint(t, EndpointRef(id2, 1))::EdgeEndpoint).pos == 1
    end

    # move backward on same edge
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 1, 2, 2, 1)
        # edge 1: [cp1 IN at pos1, cp2 IN at pos2]; move cp2 IN to pos 1 (before cp1)
        eref = EndpointRef(id2, 1)
        move_endpoint!(t, eref, 1, 1)
        @test get_edge_EndpointRef(t, 1, 1) == EndpointRef(id2, 1)
        @test get_edge_EndpointRef(t, 1, 2) == EndpointRef(id1, 1)
    end

    # validation: move that would intersect another curvepiece → error
    let t = Tile(4)
        # cp1: edge1,pos1 (IN) -> edge3,pos1 (OUT)
        # cp2: edge2,pos1 (IN) -> edge4,pos1 (OUT)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 2, 1, 4, 1)
        # moving cp1's OUT from edge3,pos1 to edge1,pos2 would cross cp2
        @test_throws ArgumentError move_endpoint!(t, EndpointRef(id1, 2), 1, 2)
    end

    # --- set_curvepiece_metadata! ---

    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        set_curvepiece_metadata!(t, id, 99, 5)
        cp = get_curvepiece(t, id)
        @test cp.curve_id == 99
        @test cp.anyon_count == 5
        # endpoints unchanged
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == EdgeEndpoint(OUT, 3, 1)
    end

end
