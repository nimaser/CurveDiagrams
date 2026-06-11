# this file tests anything not already tested in test/tile/tile.jl

###############################################################################
# TILE GEOMETRY
###############################################################################

@testset "next_edge; prev_edge" begin
    maxrandval = 6
    n_edges = rand(1:maxrandval)
    t = Tile(n_edges)
    # next_edge
    e = rand(1:maxrandval-1)
    @test next_edge(t, e) == e + 1
    @test next_edge(t, maxrandval) == 1
    # prev_edge
    e = rand(2:maxrandval)
    @test prev_edge(t, e) == e - 1
    @test prev_edge(t, 1) == maxrandval
end

###############################################################################
# EREF GETTERS
###############################################################################

@test "all_edge_erefs" begin

end

@test "has_edge_eref; edge_eref" begin

end

###############################################################################
# EREF TRAVERSAL
###############################################################################

@testset "next_eref" begin

end

@testset "prev_eref" begin

end

@testset "next_eref_wrap" begin

end

@testset "prev_eref_wrap" begin

end

###############################################################################
# EREF COLLECTIONS
###############################################################################

@testset "unpaired_erefs" begin

end

@testset "clockwise_sort" begin

end

@testset "erefs_between" begin
    # TODO SEE ORIGINAL FUNCTION
end

###############################################################################
# ENDPOINTS
###############################################################################

@testset "endpoint" begin

end

@testset "curvepiece_partner_type" begin

end

@testset "tile_partner" begin

end

@testset "tile_partner" begin

end

###############################################################################
# CURVEPIECES
###############################################################################

@testset "curvepiece_ids" begin

end

@testset "curvepiece" begin

end

@testset "central_curvepiece_ids" begin

end

@testset "is_central_curvepiece" begin

end

@testset "other_central_curvepiece_id" begin

end

@testset "curve_id" begin

end

@testset "anyon_count" begin

end

@testset "u_turn_curvepiece_ids" begin

end

@testset "hugs_corner" begin

end

@testset "nesting_hierarchy" begin

end

# @testset "Tile public getters" begin
#     # set up a 5-edge tile with edges 1-4 populated and edge 5 empty; the curvepieces are:
#     # cp1 (id=1, curve 10): Edge(IN,1,1) -> Edge(OUT,4,2)
#     # cp2 (id=2, curve 20): Edge(IN,1,2) -> Edge(OUT,1,3)  [both endpoints on edge 1]
#     # cp3 (id=3, curve 30): Edge(IN,2,1) -> Anyon(IN)
#     # cp4 (id=4, curve 30): Anyon(OUT) -> Edge(OUT,4,1)
#     t = Tile(5)
#     # make curvepieces
#     c1 = Curvepiece(10, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 4, 2))
#     c2 = Curvepiece(20, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 1, 3))
#     c3 = Curvepiece(30, 2, EdgeEndpoint(IN, 2, 1), AnyonEndpoint(IN))
#     c4 = Curvepiece(30, 3, AnyonEndpoint(OUT), EdgeEndpoint(OUT, 4, 1))
#     t._curvepieces[1] = c1
#     t._curvepieces[2] = c2
#     t._curvepieces[3] = c3
#     t._curvepieces[4] = c4
#     # put endpointrefs on edges
#     push!(t._edge_endpoints[1], EndpointRef(1, 1))  # edge 1 pos 1
#     push!(t._edge_endpoints[1], EndpointRef(2, 1))  # edge 1 pos 2
#     push!(t._edge_endpoints[1], EndpointRef(2, 2))  # edge 1 pos 3
#     push!(t._edge_endpoints[2], EndpointRef(3, 1))  # edge 2 pos 1
#     push!(t._edge_endpoints[4], EndpointRef(4, 2))  # edge 4 pos 1
#     push!(t._edge_endpoints[4], EndpointRef(1, 2))  # edge 4 pos 2
#     push!(t._anyon_endpoints, EndpointRef(3, 2))    # cp3 AnyonEndpoint(IN)
#     push!(t._anyon_endpoints, EndpointRef(4, 1))    # cp4 AnyonEndpoint(OUT)

#     # set up a 3-edge tile with a single anyon-to-edge curvepiece - only used in anyon curvepiece tests
#     t1 = Tile(3)
#     @test num_anyon_erefs(t1) == 0
#     t1._curvepieces[5] = Curvepiece(5, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
#     push!(t1._edge_endpoints[1], EndpointRef(5, 1))
#     push!(t1._anyon_endpoints, EndpointRef(5, 2))

#     # has_edge_erefs
#     @test has_edge_erefs(t, 1)
#     @test !has_edge_erefs(t, 3)

#     # num_edge_erefs
#     @test num_edge_erefs(t, 1) == 3
#     @test num_edge_erefs(t, 2) == 1
#     @test num_edge_erefs(t, 3) == 0

#     # num_anyon_erefs
#     @test num_anyon_erefs(t) == 2
#     @test num_anyon_erefs(t1) == 1

#     # curvepiece_ids
#     @test Set(curvepiece_ids(t)) == Set((1, 2, 3, 4))

#     # curvepiece
#     @test curvepiece(t, 1) == c1
#     @test curvepiece(t, 3) == c3

#     # endpoint
#     @test endpoint(t, EndpointRef(1, 1)) == c1.endpoint1
#     @test endpoint(t, EndpointRef(1, 2)) == c1.endpoint2
#     @test endpoint(t, EndpointRef(2, 1)) == c2.endpoint1
#     @test endpoint(t, EndpointRef(2, 2)) == c2.endpoint2
#     @test endpoint(t, EndpointRef(3, 1)) == c3.endpoint1
#     @test endpoint(t, EndpointRef(3, 2)) == c3.endpoint2
#     @test endpoint(t, EndpointRef(4, 1)) == c4.endpoint1
#     @test endpoint(t, EndpointRef(4, 2)) == c4.endpoint2

#     # endpoint
#     @test endpoint(c1, EndpointRef(1, 1)) == c1.endpoint1
#     @test endpoint(c1, EndpointRef(1, 2)) == c1.endpoint2
#     @test endpoint(c4, EndpointRef(4, 1)) == c4.endpoint1
#     @test endpoint(c4, EndpointRef(4, 2)) == c4.endpoint2

#     # edge_eref, fetches erefs by edge and position
#     @test edge_eref(t, 1, 1) == EndpointRef(1, 1)
#     @test edge_eref(t, 1, 2) == EndpointRef(2, 1)
#     @test edge_eref(t, 1, 3) == EndpointRef(2, 2)
#     @test edge_eref(t, 2, 1) == EndpointRef(3, 1)
#     @test edge_eref(t, 4, 1) == EndpointRef(4, 2)
#     @test edge_eref(t, 4, 2) == EndpointRef(1, 2)

#     # edge_erefs(t, edge) — multi-endpoint edge and empty edge
#     @test edge_erefs(t, 1) == [EndpointRef(1,1), EndpointRef(2,1), EndpointRef(2,2)]
#     @test edge_erefs(t, 3) == EndpointRef[]

#     # edge_erefs(t) — all erefs concatenated in clockwise order, empty edges skipped
#     @test edge_erefs(t) == [
#         EndpointRef(1,1), EndpointRef(2,1), EndpointRef(2,2),   # edge 1
#         EndpointRef(3,1),                                       # edge 2 (edge 3 is empty)
#         EndpointRef(4,2), EndpointRef(1,2),                     # edge 4 (edge 5 is empty)
#     ]

#     # anyon_erefs, order doesn't matter
#     @test Set(anyon_erefs(t)) == Set([EndpointRef(3,2), EndpointRef(4,1)])

#     # cp_partner — flips endpoint_idx between 1 and 2
#     @test cp_partner(EndpointRef(2, 1)) == EndpointRef(2, 2)
#     @test cp_partner(EndpointRef(2, 2)) == EndpointRef(2, 1)

#     # cp_partner_type
#     @test cp_partner_type(t, EndpointRef(1, 1)) === EdgeEndpoint    # partner is Edge(OUT,4,2)
#     @test cp_partner_type(t, EndpointRef(3, 1)) !== EdgeEndpoint   # partner is Anyon
#     @test cp_partner_type(t, EndpointRef(3, 1)) === AnyonEndpoint   # partner is Anyon
#     @test cp_partner_type(t, EndpointRef(1, 1)) !== AnyonEndpoint  # partner is Edge
#     @test cp_partner_type(t, EndpointRef(4, 2)) === AnyonEndpoint   # partner is Anyon(OUT)

#     # anyon_eref — fetches from cp_id
#     @test anyon_eref(t, 3) == EndpointRef(3, 2)
#     @test anyon_eref(t, 4) == EndpointRef(4, 1)
#     @test anyon_eref(t, 1) === nothing

#     # is_anyon_curvepiece
#     @test is_anyon_curvepiece(t, 3)
#     @test !is_anyon_curvepiece(t, 1)

#     # anyon_cp_ids, order doesn't matter
#     @test Set(anyon_cp_ids(t)) == Set([3, 4])

#     # partner_cp_id — two anyon cps, single anyon cp, and non-anyon cp
#     @test partner_cp_id(t, 3) == 4
#     @test partner_cp_id(t, 4) == 3
#     @test partner_cp_id(t1, 5) === nothing
#     @test_throws ArgumentError partner_cp_id(t, 1)

#     # anyon_curve_id
#     @test anyon_curve_id(t) == 30
#     @test anyon_curve_id(t1) == 5

#     # next_eref
#     @test next_eref(t, 1, 1) == EndpointRef(2, 1)  # pos 1 -> pos 2
#     @test next_eref(t, 1, 2) == EndpointRef(2, 2)  # pos 2 -> pos 3
#     @test next_eref(t, 1, 3) === nothing            # at last pos on edge
#     @test next_eref(t, 2, 1) === nothing            # single endpoint on edge

#     # prev_eref
#     @test prev_eref(t, 1, 2) == EndpointRef(1, 1)  # pos 2 -> pos 1
#     @test prev_eref(t, 1, 3) == EndpointRef(2, 1)  # pos 3 -> pos 2
#     @test prev_eref(t, 1, 1) === nothing            # at first pos on edge
#     @test prev_eref(t, 2, 1) === nothing            # single endpoint on edge

#     # next_eref_wrap
#     @test next_eref_wrap(t, 1, 2) == EndpointRef(2, 2)  # same edge: pos 2 -> pos 3
#     @test next_eref_wrap(t, 1, 3) == EndpointRef(3, 1)  # end of edge 1 -> first on edge 2
#     @test next_eref_wrap(t, 2, 1) == EndpointRef(4, 2)  # end of edge 2 -> skips empty edge 3 -> first on edge 4
#     @test next_eref_wrap(t, 4, 2) == EndpointRef(1, 1)  # end of edge 4 -> skips empty edge 5 -> first on edge 1

#     # prev_eref_wrap
#     @test prev_eref_wrap(t, 1, 2) == EndpointRef(1, 1)  # same edge: pos 2 -> pos 1
#     @test prev_eref_wrap(t, 2, 1) == EndpointRef(2, 2)  # start of edge 2 -> last on edge 1
#     @test prev_eref_wrap(t, 4, 1) == EndpointRef(3, 1)  # start of edge 4 -> skips empty edge 3 -> last on edge 2
#     @test prev_eref_wrap(t, 1, 1) == EndpointRef(1, 2)  # start of edge 1 -> skips empty edge 5 -> last on edge 4
# end

# @testset "Tile anyon_count" begin
#     # e2a only (enters anyon): anyon_count = cp.anyon_count + 1
#     let t = Tile(4)
#         insert_curvepiece!(t, 1, 3, 2, 1, IN)
#         @test anyon_count(t) == 4
#     end
#     # a2e only (exits anyon): anyon_count = cp.anyon_count
#     let t = Tile(4)
#         insert_curvepiece!(t, 1, 5, 2, 1, OUT)
#         @test anyon_count(t) == 5
#     end
#     # both: anyon_count = a2e cp.anyon_count
#     let t = Tile(4)
#         insert_curvepiece!(t, 1, 7, 1, 1, IN)   # e2a, anyon_count=7
#         insert_curvepiece!(t, 1, 7, 2, 1, OUT)  # a2e, anyon_count=7
#         @test anyon_count(t) == 7
#     end
# end

# @testset "Tile u_turn_cp_ids" begin
#     let t = Tile(3)
#         insert_curvepiece!(t, 10, 1, 1, 1, OUT) # a2e curvepiece 1
#         insert_curvepiece!(t, 10, 2, 1, 2, 2, 1) # e2e curvepiece 2
#         insert_curvepiece!(t, 10, 2, 2, 2, 2, 3) # e2e curvepiece 3
#         insert_curvepiece!(t, 10, 2, 2, 2, 3, 1) # e2e curvepiece 4
#         insert_curvepiece!(t, 10, 3, 3, 2, 3, 3) # e2e curvepiece 5
#         insert_curvepiece!(t, 10, 3, 3, 3, 3, 3) # e2 curvepiece 6
#         @test Set(u_turn_cp_ids(t)) == Set((3, 5, 6))
#     end
# end

# @testset "Tile hugs_corner" begin
#     let t = Tile(6)
#         id1 = insert_curvepiece!(t, 10, 1, 1, 1, 2, 1)
#         id2 = insert_curvepiece!(t, 20, 2, 3, 1, IN)
#         id3 = insert_curvepiece!(t, 30, 3, 4, 1, 4, 2)
#         id4 = insert_curvepiece!(t, 40, 4, 4, 3, 6, 1)
#         @test hugs_corner(t, id1)
#         @test !hugs_corner(t, id2)
#         @test !hugs_corner(t, id3)
#         @test !hugs_corner(t, id4)
#         # slide another curvepiece in under id1
#         id5 = insert_curvepiece!(t, 50, 5, 2, 1, 1, 2)
#         @test hugs_corner(t, id5)
#         @test !hugs_corner(t, id1)
#     end
# end

# @testset "Tile nesting number" begin
#     # single e2e with endpoints on different edges: nesting 1, not enclosed by anything
#     let t = Tile(3)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 2, 1))
#         push!(t._edge_endpoints[1], EndpointRef(1, 1))
#         push!(t._edge_endpoints[2], EndpointRef(1, 2))
#         @test calculate_nesting_hierarchy(t) == Dict(1 => (1, 1))
#     end
#     # single a2e curvepiece: ignored by the algorithm, result is empty
#     let t = Tile(3)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), AnyonEndpoint(IN))
#         push!(t._edge_endpoints[1], EndpointRef(1, 1))
#         push!(t._anyon_endpoints, EndpointRef(1, 2))
#         @test isempty(calculate_nesting_hierarchy(t))
#     end
#     # A (nesting 2) encloses B (nesting 1) and is a sibling of C (nesting 1)
#     # clockwise boundary order: A, B, B, A, C, C
#     let t = Tile(3)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 2, 2))  # A
#         t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 2, 1))  # B
#         t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 2, 3), EdgeEndpoint(OUT, 3, 1))  # C
#         push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
#         push!(t._edge_endpoints[2], EndpointRef(1, 2))  # A.endpoint2
#         push!(t._edge_endpoints[2], EndpointRef(3, 1))  # C.endpoint1
#         push!(t._edge_endpoints[3], EndpointRef(3, 2))  # C.endpoint2
#         result = calculate_nesting_hierarchy(t)
#         @test result[1] == (2, 2)  # A: nesting 2, not enclosed
#         @test result[2] == (1, 2)  # B: nesting 1, enclosed by A
#         @test result[3] == (1, 1)  # C: nesting 1, not enclosed
#     end
#     # same case as before, but C is now on edges 3 and 1, meaning if the algorithm isn't wraparound
#     # -aware it will perceive it as enclosing A; clockwise boundary order: C, A, B, B, A, C
#     let t = Tile(3)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 2, 2))  # A
#         t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 3), EdgeEndpoint(OUT, 2, 1))  # B
#         t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 1, 1))  # C
#         push!(t._edge_endpoints[1], EndpointRef(3, 2))  # C.endpoint2
#         push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
#         push!(t._edge_endpoints[2], EndpointRef(1, 2))  # A.endpoint2
#         push!(t._edge_endpoints[3], EndpointRef(3, 1))  # C.endpoint1
#         result = calculate_nesting_hierarchy(t)
#         # note that here we're breaking an abstraction barrier somewhat by using knowledge about how
#         # the starting position affects the assignment of nesting numbers. an alternative viable
#         # assignment would have been for A to enclose C instead of B, but because of which edge the
#         # algorithm started on this doesn't happen
#         @test result[1] == (2, 2)  # A: nesting 2, not enclosed
#         @test result[2] == (1, 2)  # B: nesting 1, enclosed by A
#         @test result[3] == (1, 1)  # C: nesting 1, not enclosed
#     end
#     # clockwise boundary: A B C B A on edge 2
#     # C is a2e acting as a barrier; we make sure that A is enclosed by B rather than the other way around
#     let t = Tile(3)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 2, 1), EdgeEndpoint(OUT, 2, 5))  # A
#         t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 2, 2), EdgeEndpoint(OUT, 2, 4))  # B
#         t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 2, 3), AnyonEndpoint(IN))        # C
#         push!(t._edge_endpoints[2], EndpointRef(1, 1))  # A.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(2, 1))  # B.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(3, 1))  # C.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
#         push!(t._edge_endpoints[2], EndpointRef(1, 2))  # A.endpoint2
#         push!(t._anyon_endpoints, EndpointRef(3, 2))    # C.anyon endpoint
#         result = calculate_nesting_hierarchy(t)
#         @test !haskey(result, 3)        # C: anyon curvepiece, absent from result
#         @test result[1] == (1, 2)       # A: nesting 1, max_enc 2
#         @test result[2] == (2, 2)       # B: nesting 2, not enclosed
#     end
#     # pentagon with clockwise boundary: A, B, B, C, D, E, F, F, E, C, A
#     # A, B, F have nesting=1; C, E have nesting=2; D is a2e with no nesting
#     # A and B are siblings enclosed by C; F is enclosed by E
#     let t = Tile(5)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 5, 2))  # A
#         t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 2, 1))  # B
#         t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 2, 2), EdgeEndpoint(OUT, 5, 1))  # C
#         t._curvepieces[4] = Curvepiece(4, 1, EdgeEndpoint(IN, 2, 3), AnyonEndpoint(IN))        # D
#         t._curvepieces[5] = Curvepiece(5, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 4, 2))  # E
#         t._curvepieces[6] = Curvepiece(6, 1, EdgeEndpoint(IN, 3, 2), EdgeEndpoint(OUT, 4, 1))  # F
#         push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(2, 2))  # B.endpoint2
#         push!(t._edge_endpoints[2], EndpointRef(3, 1))  # C.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(4, 1))  # D.endpoint1
#         push!(t._edge_endpoints[3], EndpointRef(5, 1))  # E.endpoint1
#         push!(t._edge_endpoints[3], EndpointRef(6, 1))  # F.endpoint1
#         push!(t._edge_endpoints[4], EndpointRef(6, 2))  # F.endpoint2
#         push!(t._edge_endpoints[4], EndpointRef(5, 2))  # E.endpoint2
#         push!(t._edge_endpoints[5], EndpointRef(3, 2))  # C.endpoint2
#         push!(t._edge_endpoints[5], EndpointRef(1, 2))  # A.endpoint2
#         push!(t._anyon_endpoints, EndpointRef(4, 2))    # D.anyon endpoint
#         result = calculate_nesting_hierarchy(t)
#         @test !haskey(result, 4)        # D: anyon curvepiece, absent from result
#         @test result[1] == (1, 2)       # A: nesting 1, enclosed by C (nesting 2)
#         @test result[2] == (1, 2)       # B: nesting 1, enclosed by C (nesting 2)
#         @test result[3] == (2, 2)       # C: nesting 2, not enclosed
#         @test result[5] == (2, 2)       # E: nesting 2, not enclosed
#         @test result[6] == (1, 2)       # F: nesting 1, enclosed by E (nesting 2)
#     end
#     # triangle with clockwise boundary: (A, B, C, D, D, E), (F, F, G), (C, H, H, B, A)
#     # E, G are a2e; A, D, F, H have nesting 1, B has nesting 2, C has nesting 3
#     # D, F have max enclosing of 1, A, B, C, H have max enclosing of 3
#     let t = Tile(3)
#         t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 3, 5))  # A
#         t._curvepieces[2] = Curvepiece(2, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 3, 4))  # B
#         t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 1, 3), EdgeEndpoint(OUT, 3, 1))  # C
#         t._curvepieces[4] = Curvepiece(4, 1, EdgeEndpoint(IN, 1, 4), EdgeEndpoint(OUT, 1, 5))  # D
#         t._curvepieces[5] = Curvepiece(5, 1, EdgeEndpoint(IN, 1, 6), AnyonEndpoint(IN))        # E
#         t._curvepieces[6] = Curvepiece(6, 1, EdgeEndpoint(IN, 2, 1), EdgeEndpoint(OUT, 2, 2))  # F
#         t._curvepieces[7] = Curvepiece(5, 1, EdgeEndpoint(IN, 2, 3), AnyonEndpoint(IN))        # G
#         t._curvepieces[8] = Curvepiece(8, 1, EdgeEndpoint(IN, 3, 2), EdgeEndpoint(OUT, 3, 3))  # H
#         push!(t._edge_endpoints[1], EndpointRef(1, 1))  # A.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(2, 1))  # B.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(3, 1))  # C.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(4, 1))  # D.endpoint1
#         push!(t._edge_endpoints[1], EndpointRef(4, 2))  # D.endpoint2
#         push!(t._edge_endpoints[1], EndpointRef(5, 1))  # E.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(6, 1))  # F.endpoint1
#         push!(t._edge_endpoints[2], EndpointRef(6, 2))  # F.endpoint2
#         push!(t._edge_endpoints[2], EndpointRef(7, 1))  # G.endpoint1
#         push!(t._edge_endpoints[3], EndpointRef(3, 2))  # C.endpoint2
#         push!(t._edge_endpoints[3], EndpointRef(8, 1))  # H.endpoint1
#         push!(t._edge_endpoints[3], EndpointRef(8, 2))  # H.endpoint2
#         push!(t._edge_endpoints[3], EndpointRef(2, 2))  # B.endpoint2
#         push!(t._edge_endpoints[3], EndpointRef(1, 2))  # A.endpoint2
#         push!(t._anyon_endpoints, EndpointRef(5, 2))    # E.anyon endpoint
#         push!(t._anyon_endpoints, EndpointRef(7, 2))    # G.anyon endpoint
#         result = calculate_nesting_hierarchy(t)
#         @test !haskey(result, 5)        # E: anyon curvepiece, absent from result
#         @test !haskey(result, 7)        # G: anyon curvepiece, absent from result
#         @test result[1] == (1, 3)       # A: nesting 1, max_enc 3
#         @test result[2] == (2, 3)       # B: nesting 2, max_enc 3
#         @test result[3] == (3, 3)       # C: nesting 3, not enclosed
#         @test result[4] == (1, 1)       # D: nesting 1, not enclosed
#         @test result[6] == (1, 1)       # F: nesting 1, not enclosed
#         @test result[8] == (1, 3)       # H: nesting 1, max_enc 3
#     end
# end
