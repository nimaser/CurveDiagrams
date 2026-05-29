# @testset "Lattice create_pair!" begin
#     # basic: creates curve, registers two curvepieces, returns curve_id and action
#     let l = Lattice(RING3_ADJ)
#         curve_id, action = create_pair!(l, 1, 2)
#         @test curve_id == 1
#         @test action == [0, curve_id, 1, 2]
#         @test num_curves(l) == 1
#         @test length(get_curvediagram(l, curve_id)) == 2
#         @test anyon_curve_id(l, 1) == curve_id
#         @test anyon_curve_id(l, 2) == curve_id
#         @test anyon_tiles(l, curve_id) == [1, 2]
#         # shared edge has exactly one endpoint on each tile
#         @test num_edge_erefs(get_tile(l, 1), 1) == 1
#         @test num_edge_erefs(get_tile(l, 2), 1) == 1
#     end

#     # sibling positions are consistent after create_pair!
#     let l = Lattice(RING3_ADJ)
#         curve_id, _ = create_pair!(l, 1, 2)
#         diagram = get_curvediagram(l, curve_id)
#         ref1 = diagram[1]
#         sib_tile, sib_eref = sibling_endpoint(l, ref1.tile_id, EndpointRef(ref1.cp_id, 1))
#         ref2 = diagram[2]
#         @test sib_tile == ref2.tile_id
#         @test sib_eref.cp_id == ref2.cp_id
#     end

#     # second call to create_pair! for a tile that already has an anyon → throws
#     let l = Lattice(RING3_ADJ)
#         create_pair!(l, 1, 2)
#         @test_throws ArgumentError create_pair!(l, 1, 3)
#         @test_throws ArgumentError create_pair!(l, 3, 2)
#     end

#     # non-neighboring tiles → throws
#     let l = Lattice(RING3_ADJ)
#         # tile 1 and tile 2 share an edge; tile 1 and a hypothetical tile 4 do not
#         # use a 4-tile lattice where tile1 and tile4 are not adjacent
#         l4 = Lattice([[(2,1),(3,1)], [(1,1),(3,2)], [(1,2),(2,2),(4,1)], [(3,3)]])
#         @test_throws ArgumentError create_pair!(l4, 1, 4)
#     end

#     # pos clamping: pos=0 is clamped to 1 (same result as default pos=1)
#     let l1 = Lattice(RING3_ADJ), l2 = Lattice(RING3_ADJ)
#         create_pair!(l1, 1, 2, 0)
#         create_pair!(l2, 1, 2, 1)
#         @test num_edge_erefs(get_tile(l1, 1), 1) == num_edge_erefs(get_tile(l2, 1), 1)
#     end
# end
