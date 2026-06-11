@testset "Tile public mutators" begin

    # basic edge-to-edge insertion: returns cp_id=1, creates correct curvepiece
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        @test id == 1
        cp = curvepiece(t, 1)
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == EdgeEndpoint(OUT, 3, 1)
        @test edge_eref(t, 1, 1) == EndpointRef(1, 1)
        @test edge_eref(t, 3, 1) == EndpointRef(1, 2)
    end

    # basic edge-to-anyon insertion: returns cp_id=1, creates correct curvepiece
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, IN)
        @test id == 1
        @test num_anyon_erefs(t) == 1
        @test is_anyon_curvepiece(t, 1)
        cp = curvepiece(t, 1)
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == AnyonEndpoint(IN)
        @test edge_eref(t, 1, 1) == EndpointRef(1, 1)
    end

    # cp_id increments on successive insertions
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
        id2 = insert_curvepiece!(t, 20, 1, 3, 1, 4, 1)
        id3 = insert_curvepiece!(t, 30, 1, 2, 2, IN)
        @test id1 == 1
        @test id2 == 2
        @test id3 == 3
        @test Set(curvepiece_ids(t)) == Set((1, 2, 3))
    end

    # same edge insertion, IN then OUT
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 1, 2)
        @test num_edge_erefs(t, 1) == 2
        @test edge_eref(t, 1, 1) == EndpointRef(1, 1)  # IN endpoint
        @test edge_eref(t, 1, 2) == EndpointRef(1, 2)  # OUT endpoint
        @test (endpoint(t, EndpointRef(1, 1))::EdgeEndpoint).direction == IN
        @test (endpoint(t, EndpointRef(1, 2))::EdgeEndpoint).direction == OUT
    end

    # same edge insertion, OUT then IN
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 1, 1)
        @test num_edge_erefs(t, 1) == 2
        @test edge_eref(t, 1, 1) == EndpointRef(1, 2)  # OUT endpoint
        @test edge_eref(t, 1, 2) == EndpointRef(1, 1)  # IN endpoint
        @test (endpoint(t, edge_eref(t, 1, 1))::EdgeEndpoint).direction == OUT
        @test (endpoint(t, edge_eref(t, 1, 2))::EdgeEndpoint).direction == IN
    end

    # inserting two curvepieces on the same edge shifts positions correctly
    let t = Tile(4)
        # insert two nested curvepieces, both with the same IN endpoint location
        insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
        insert_curvepiece!(t, 20, 1, 1, 1, 3, 1)
        @test num_edge_erefs(t, 1) == 2
        # cp2 IN is at pos 1, old cp1 IN shifted to pos 2
        @test edge_eref(t, 1, 1) == EndpointRef(2, 1)
        @test edge_eref(t, 1, 2) == EndpointRef(1, 1)
        # cp1's stored endpoint1 position should be updated
        @test (endpoint(t, EndpointRef(1, 1))::EdgeEndpoint).pos == 2
    end

    # inserting a curvepiece which splits an existing curvepiece's endpoints throws error
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        @test_throws ArgumentError insert_curvepiece!(t, 20, 1, 2, 1, 4, 1)
    end

    # inserting two anyon curvepieces with correct curve_ids
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, IN)
        insert_curvepiece!(t, 10, 2, 3, 1, OUT)
        @test num_anyon_erefs(t) == 2
        @test is_anyon_curvepiece(t, 2)
    end

    # third anyon curvepiece throws error
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, IN)
        insert_curvepiece!(t, 10, 2, 3, 1, OUT)
        @test_throws ArgumentError insert_curvepiece!(t, 10, 3, 2, 1, IN)
    end

    # curve_id mismatch throws error
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, IN)
        @test_throws ArgumentError insert_curvepiece!(t, 20, 2, 2, 1, OUT)
    end

    # direction incompatibility throws error
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, IN)
        @test_throws ArgumentError insert_curvepiece!(t, 10, 2, 2, 1, IN)
    end

    # can add anyon curvepieces in the presense of an edge-to-edge cp
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        insert_curvepiece!(t, 20, 1, 2, 1, IN)
        insert_curvepiece!(t, 20, 2, 2, 2, OUT)
    end

    # inserting an anyon curvepiece which splits an existing curvepiece's endpoints throws error
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        insert_curvepiece!(t, 20, 1, 2, 1, IN)
        @test_throws ArgumentError insert_curvepiece!(t, 20, 2, 4, 1, IN)
    end

    # inserting an edge-to-edge curvepiece which intersects the anyon curvepieces throws error
    let t = Tile(4)
        insert_curvepiece!(t, 10, 1, 1, 1, IN)
        insert_curvepiece!(t, 10, 2, 3, 1, OUT)
        @test_throws ArgumentError insert_curvepiece!(t, 20, 1, 2, 1, 4, 1)
    end

    # removing edge-to-edge curvepiece
    let t = Tile(4)
        # insert curvepieces
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 1, 2, 2, 1)
        # make sure curvepiece was removed correctly
        remove_curvepiece!(t, id1)
        @test Set(curvepiece_ids(t)) == Set(id2)
        @test num_edge_erefs(t, 1) == 1
        @test num_edge_erefs(t, 3) == 0
        # remaining endpoint and eref positions are correct
        @test (endpoint(t, EndpointRef(id2, 1))::EdgeEndpoint).pos == 1
        @test edge_eref(t, 1, 1) == EndpointRef(id2, 1)
    end

    # removing an edge-to-anyon curvepiece
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, IN)
        @test num_anyon_erefs(t) == 1
        remove_curvepiece!(t, id)
        @test num_anyon_erefs(t) == 0
        @test isempty(curvepiece_ids(t))
    end

    # removing one of two anyon curvepieces leaves the other intact
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, IN)
        id2 = insert_curvepiece!(t, 10, 2, 3, 1, OUT)
        remove_curvepiece!(t, id1)
        @test num_anyon_erefs(t) == 1
        @test is_anyon_curvepiece(t, id2)
    end

    # merging curvepieces correctly
    let t = Tile(4)
        # erefs on same curvepiece
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
        @test_throws ArgumentError merge_curvepieces!(t, EndpointRef(id1, 1), EndpointRef(id1, 2))
        # erefs have same direction (ex: both IN)
        id2 = insert_curvepiece!(t, 10, 1, 4, 1, 3, 1)
        @test_throws ArgumentError merge_curvepieces!(t, EndpointRef(id1, 1), EndpointRef(id2, 1))
    end
    let t = Tile(4)
        # erefs on different curve diagrams
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 1, 2)
        id2 = insert_curvepiece!(t, 20, 1, 2, 1, 2, 2)
        @test_throws ArgumentError merge_curvepieces!(t, EndpointRef(id1, 2), EndpointRef(id2, 1))
        # erefs with different anyon_counts
        id3 = insert_curvepiece!(t, 10, 2, 3, 1, 4, 1)
        @test_throws ArgumentError merge_curvepieces!(t, EndpointRef(id3, 2), EndpointRef(id1, 1))
    end
    let t = Tile(4)
        # erefA and erefB on different edges
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
        id2 = insert_curvepiece!(t, 10, 1, 2, 2, 3, 1)
        merged_id = merge_curvepieces!(t, EndpointRef(id1, 2), EndpointRef(id2, 1))
        new_id = only(curvepiece_ids(t))
        cp = curvepiece(t, new_id)
        @test merged_id == new_id
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == EdgeEndpoint(OUT, 3, 1)
        @test num_edge_erefs(t, 1) == 1
        @test num_edge_erefs(t, 2) == 0
        @test num_edge_erefs(t, 3) == 1
        @test edge_eref(t, 1, 1) == EndpointRef(new_id, 1)
        @test edge_eref(t, 3, 1) == EndpointRef(new_id, 2)
    end
    let t = Tile(4)
        # erefA and erefB on same edge
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 10, 1, 3, 1, 1, 2)
        merged_id = merge_curvepieces!(t, EndpointRef(id1, 2), EndpointRef(id2, 1))
        new_id = only(curvepiece_ids(t))
        cp = curvepiece(t, new_id)
        @test merged_id == new_id
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == EdgeEndpoint(OUT, 1, 2)
        @test num_edge_erefs(t, 1) == 2
        @test num_edge_erefs(t, 2) == 0
        @test edge_eref(t, 1, 1) == EndpointRef(new_id, 1)
        @test edge_eref(t, 1, 2) == EndpointRef(new_id, 2)
    end
    let t = Tile(4)
        # surviving endpoint is an AnyonEndpoint: merge a2e + e2e → a2e
        # id1: a2e, Anyon(OUT) -> Edge(OUT, 2, 1)
        # id2: e2e, Edge(IN, 2, 2) -> Edge(OUT, 3, 1)
        # merge at id1's edge endpoint and id2's IN endpoint → Anyon(OUT) -> Edge(OUT, 3, 1)
        id1 = insert_curvepiece!(t, 10, 1, 2, 1, OUT)
        id2 = insert_curvepiece!(t, 10, 1, 2, 2, 3, 1)
        merged_id = merge_curvepieces!(t, EndpointRef(id1, 2), EndpointRef(id2, 1))
        new_id = only(k for k in curvepiece_ids(t) if is_anyon_curvepiece(t, k))
        cp = curvepiece(t, new_id)
        @test merged_id == new_id
        @test cp.curve_id == 10
        @test cp.anyon_count == 1
        @test cp.endpoint1 isa AnyonEndpoint
        @test cp.endpoint2 == EdgeEndpoint(OUT, 3, 1)
        @test num_edge_erefs(t, 2) == 0
        @test num_edge_erefs(t, 3) == 1
        @test num_anyon_erefs(t) == 1
    end

    # split curvepieces correctly
    let t = Tile(4)


    end

    # insert anyon correctly
    let t = Tile(4)

    end

    # remove anyon correctly
    let t = Tile(4)

    end

    # reverse direction of curvepiece
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, IN)
        id2 = insert_curvepiece!(t, 20, 2, 2, 1, 3, 1)
        reverse_curvepiece!(t, id1)
        cp1 = curvepiece(t, id1)
        # curve_id and anyon_count unchanged
        @test cp1.curve_id == 10
        @test cp1.anyon_count == 1
        # directions reversed
        @test cp1.endpoint1 == AnyonEndpoint(OUT)
        @test cp1.endpoint2 == EdgeEndpoint(OUT, 1, 1)
        # EndpointRef on edge 1 flipped from (id1,1) to (id1,2)
        # EndpointRef on anyon flipped from (id1,2) to (id1,1)
        @test edge_eref(t, 1, 1) == EndpointRef(id1, 2)
        @test EndpointRef(id1, 1) in anyon_erefs(t)
        # id2 unaffected
        @test curvepiece(t, id2) == Curvepiece(20, 2, EdgeEndpoint(IN, 2, 1), EdgeEndpoint(OUT, 3, 1))
    end
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, IN)
        id2 = insert_curvepiece!(t, 20, 2, 2, 1, 3, 1)
        reverse_curvepiece!(t, id2)
        cp2 = curvepiece(t, id2)
        # curve_id and anyon_count unchanged
        @test cp2.curve_id == 20
        @test cp2.anyon_count == 2
        # directions reversed
        @test cp2.endpoint1 == EdgeEndpoint(IN, 3, 1)
        @test cp2.endpoint2 == EdgeEndpoint(OUT, 2, 1)
        # EndpointRef on edge 2 flipped from (id2,1) to (id2,2)
        # EndpointRef on edge 3 flipped from (id2,2) to (id2,1)
        @test edge_eref(t, 2, 1) == EndpointRef(id2, 2)
        @test edge_eref(t, 3, 1) == EndpointRef(id2, 1)
        # id1 unaffected
        @test curvepiece(t, id1) == Curvepiece(10, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
    end

    # move to a different edge
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        eref = EndpointRef(id, 1) # IN endpoint
        move_endpoint!(t, eref, 2, 1)
        ep = endpoint(t, eref)::EdgeEndpoint
        @test ep.edge == 2 && ep.pos == 1
        @test num_edge_erefs(t, 1) == 0
        @test num_edge_erefs(t, 2) == 1
        @test num_edge_erefs(t, 3) == 1
        @test edge_eref(t, 2, 1) == eref
    end

    # move forward on same edge
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        id2 = insert_curvepiece!(t, 20, 1, 1, 2, 2, 1)
        eref = EndpointRef(id1, 1)
        move_endpoint!(t, eref, 2, 2) # move cp1
        @test num_edge_erefs(t, 1) == 1
        @test num_edge_erefs(t, 2) == 2
        @test num_edge_erefs(t, 3) == 1
        @test edge_eref(t, 1, 1) == EndpointRef(id2, 1)
        @test edge_eref(t, 2, 2) == EndpointRef(id1, 1)
        ep = endpoint(t, eref)::EdgeEndpoint
        @test ep.edge == 2
        @test ep.pos == 2
    end

    # move backward on same edge
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 1, 2)
        id2 = insert_curvepiece!(t, 20, 1, 1, 3, 2, 1)
        eref = EndpointRef(id2, 1)
        move_endpoint!(t, eref, 1, 1)
        @test edge_eref(t, 1, 1) == EndpointRef(id2, 1)
        @test edge_eref(t, 1, 2) == EndpointRef(id1, 1)
        ep = endpoint(t, eref)::EdgeEndpoint
        @test ep.edge == 1
        @test ep.pos == 1
    end

    # move that intersects another edge-to-edge curvepiece throws error
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
        id2 = insert_curvepiece!(t, 20, 1, 2, 2, 3, 1)
        @test_throws ArgumentError move_endpoint!(t, EndpointRef(id2, 1), 2, 1)
    end

    # move that intersects an edge-to-anyon curvepiece throws error
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
        id2 = insert_curvepiece!(t, 20, 1, 2, 2, 3, 1)
        id3 = insert_curvepiece!(t, 30, 1, 3, 2, IN)
        id4 = insert_curvepiece!(t, 30, 2, 4, 1, OUT)
        @test_throws ArgumentError move_endpoint!(t, EndpointRef(id4, 2), 1, 2)
    end

    # can move an anyon endpoint to an edge position
    let t = Tile(4)
        id1 = insert_curvepiece!(t, 10, 1, 1, 1, IN)
        move_endpoint!(t, EndpointRef(id1, 2), 2, 1)
        cp = curvepiece(t, id1)
        ep2 = cp.endpoint2::EdgeEndpoint
        @test ep2.edge == 2 && ep2.pos == 1 && ep2.direction == OUT
        @test num_anyon_erefs(t) == 0
        @test num_edge_erefs(t, 2) == 1
    end

    # setting curvepiece metadata correctly
    let t = Tile(4)
        id = insert_curvepiece!(t, 10, 1, 1, 1, 3, 1)
        set_curvepiece_metadata!(t, id, 20, 2)
        cp = curvepiece(t, id)
        @test cp.curve_id == 20
        @test cp.anyon_count == 2
        # endpoints unchanged
        @test cp.endpoint1 == EdgeEndpoint(IN, 1, 1)
        @test cp.endpoint2 == EdgeEndpoint(OUT, 3, 1)
    end
end
