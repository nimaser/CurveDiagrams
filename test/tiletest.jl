using CurveDiagrams

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
    @test ae_in <: CurvepieceEndpoint
    @test ae_out <: CurvepieceEndpoint
    @test ee_in <: CurvepieceEndpoint
    @test ee_out <: CurvepieceEndpoint
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
end

@testset "Tile getters" begin
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
    t1._curvepieces[1] = Curvepiece(5, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
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
    @test get_partner_cp_id(t1, 1) === nothing
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

end
