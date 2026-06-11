@testset "EndpointRef" begin
    maxrandval = 6
    cp_id = rand(1:maxrandval)
    endpoint_idx = rand(1:maxrandval)
    # make an EndpointRef
    if endpoint_idx ∈ {1, 2}
        # valid endpoint_idx
        eref = EndpointRef(cp_id, endpoint_idx)
        @test eref.cp_id == cp_id
        @test eref.endpoint_idx == endpoint_idx
    else
        # invalid endpoint_idx
        @test_throws ArgumentError EndpointRef(cp_id, endpoint_idx)
    end
end

@testset "curvepiece_partner" begin
    maxrandval = 6
    cp_id = rand(1:maxrandval)
    eref1 = EndpointRef(cp_id, 1)
    eref2 = EndpointRef(cp_id, 2)
    # partners have endpoint_idx swapped
    part1 = curvepiece_partner(eref1)
    part2 = curvepiece_partner(eref2)
    @test part1 == eref2
    @test part2 == eref1
end

@testset "Tile; num_edges" begin
    maxrandval = 6
    n_edges = rand(1:maxrandval)
    # valid number of edges
    t = Tile(n_edges)
    @test num_edges(t) == n_edges
    # cannot have fractional, 0, or negative n_edges
    @test_throws ArgumentError Tile(0.5)
    @test_throws ArgumentError Tile(-3)
    @test_throws ArgumentError Tile(0)
end

@testset "_allocate_cp_id!" begin
    maxrandval = 6
    t = Tile(rand(1:maxrandval))
    # allocation starts from 1 and increments by 1
    @test _allocate_cp_id!(t) == 1
    @test _allocate_cp_id!(t) == 2
    @test _allocate_cp_id!(t) == 3
end

# TODO
@testset "_insert_edge_eref!; _remove_edge_eref!; num_edge_erefs; has_edge_erefs; edge_erefs" begin
    maxrandval = 6
    cp_id1, endpoint_idx1 = rand(1:maxrandval), rand(1:2)
    cp_id2, endpoint_idx2 = rand(1:maxrandval), rand(1:2)
    eref1 = EndpointRef(cp_id1, endpoint_idx1)
    eref2 = EndpointRef(cp_id2, endpoint_idx2)
    eref3 = EndpointRef(cp_id3, endpoint_idx3)
    t = Tile(rand(1:maxrandval))
    # no edge erefs
    for e in num_edges(t)
        @test num_edge_erefs(t, e) == 0
        @test !has_edge_erefs(t, e)
        @test isempty(edge_erefs(t, e))
    end
    # adding one succeeds
    edge1, pos1 = rand(1:maxrandval), 1
    _insert_edge_eref!(t, eref, edge1, pos1)
    for e in setminus(num_edges(t), [edge1])
        @test num_edge_erefs(t, e) == 0
        @test !has_edge_erefs(t, e)
        @test isempty(edge_erefs(t, e))
    end
    @test num_edge_erefs(t, edge1) == 1
    @test has_edge_erefs(t, edge1)
    @test only(edge_erefs(t, edge1)) == eref1


    # adding a second succeeds

    # invalid insertion fails with no changes to the tile

    # valid removal succeeds




end

@testset "_push_anyon_eref!; _remove_anyon_eref!; num_anyon_erefs; has_anyon_erefs; anyon_erefs; anyon_eref" begin
    maxrandval = 6
    cp_id1, endpoint_idx1 = rand(1:maxrandval), rand(1:2)
    cp_id2, endpoint_idx2 = rand(1:maxrandval), 3 -  endpoint_idx1
    eref1 = EndpointRef(cp_id1, endpoint_idx1)
    eref2 = EndpointRef(cp_id2, endpoint_idx2)
    t = Tile(rand(1:maxrandval))
    # no anyon erefs
    @test num_anyon_erefs(t) == 0
    @test !has_anyon_erefs(t)
    @test isempty(anyon_erefs(t))
    @test anyon_eref(t, cp_id1) === nothing
    @test anyon_eref(t, cp_id2) === nothing
    # adding one succeeds
    _push_anyon_eref!(t, eref1)
    @test num_anyon_erefs(t) == 1
    @test has_anyon_erefs(t)
    @test only(anyon_erefs(t)) == eref1
    @test anyon_eref(t, cp_id1) == eref1
    @test anyon_eref(t, cp_id2) === nothing
    # adding a second succeeds
    _push_anyon_eref!(t, eref2)
    @test num_anyon_erefs(t) == 2
    @test has_anyon_erefs(t)
    @test Set(anyon_erefs(t)) == Set(eref1, eref2)
    @test anyon_eref(t, cp_id1) == eref1
    @test anyon_eref(t, cp_id2) == eref2
    # adding a third fails with no changes to the tile
    @test_throws ArgumentError _push_anyon_eref!(t, eref1)
    @test num_anyon_erefs(t) == 2
    @test has_anyon_erefs(t)
    @test Set(anyon_erefs(t)) == Set(eref1, eref2)
    @test anyon_eref(t, cp_id1) == eref1
    @test anyon_eref(t, cp_id2) == eref2
    # valid removal succeeds
    _remove_anyon_eref!(t, eref1)
    @test num_anyon_erefs(t) == 1
    @test has_anyon_erefs(t)
    @test only(anyon_erefs(t)) == eref2
    @test anyon_eref(t, cp_id1) === nothing
    @test anyon_eref(t, cp_id2) == eref2
    # invalid removal fails with no changes to the tile
    @test_throws ArgumentError _remove_anyon_eref!(t, eref1)
    @test num_anyon_erefs(t) == 1
    @test has_anyon_erefs(t)
    @test only(anyon_erefs(t)) == eref2
    @test anyon_eref(t, cp_id1) === nothing
    @test anyon_eref(t, cp_id2) == eref2
    # valid removal succeeds
    _remove_anyon_eref!(t, eref2)
    @test num_anyon_erefs(t) == 0
    @test !has_anyon_erefs(t)
    @test isempty(anyon_erefs(t))
    @test anyon_eref(t, cp_id1) === nothing
    @test anyon_eref(t, cp_id2) === nothing
end

@testset "_move_eref!" begin

end
