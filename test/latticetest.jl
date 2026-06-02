import CurveDiagrams: _allocate_curve_id!, _insert_cref!,
    _remove_cref!, _shift_anyon_count!, _delete_curvediagram!,
    _relabel_curve!

# single hexagon on a sphere
# tile 1 edge n -> tile 2 edge n
# tile 2 edge n -> tile 1 edge n
const HEX = [
    [(2,1), (2,2), (2,3), (2,4), (2,5), (2,6)],
    [(1,1), (1,2), (1,3), (1,4), (1,5), (1,6)],
]

# 3-tile ring where each tile has 2 edges
# tile 1 edge 2 -> tile 2 edge 1
# tile 2 edge 2 -> tile 3 edge 1
# tile 3 edge 2 -> tile 1 edge 1
const RING3 = [
    [(3, 2), (2, 1)],
    [(1, 2), (3, 1)],
    [(2, 2), (1, 1)],
]

@testset "Lattice constructor" begin
    # constructors work
    l1 = Lattice(HEX)
    l2 = Lattice(RING3)
    # correct number of tiles
    @test num_tiles(l1) == 2
    @test num_tiles(l2) == 3
    # tiles have right number of edges
    @test num_edges(get_tile(l1, 1)) == 6
    @test num_edges(get_tile(l1, 2)) == 6
    @test num_edges(get_tile(l2, 1)) == 2
    @test num_edges(get_tile(l2, 2)) == 2
    @test num_edges(get_tile(l2, 3)) == 2
    # corresponding edge works
    @test corresponding_edge(l1, 1, 1) == TileEdgeRef(2, 1)
    @test corresponding_edge(l1, 2, 1) == TileEdgeRef(1, 1)
    # corresponding edge is self inverse
    ter1 = TileEdgeRef(1, 2)
    ter2 = corresponding_edge(l2, ter1.tile_id, ter1.edge)
    ter3 = corresponding_edge(l2, ter2.tile_id, ter2.edge)
    @test ter3 == ter1
    # shared edge works
    @test shared_edge(l2, 1, 2) == (2, 1)
    @test shared_edge(l2, 2, 3) == (2, 1)
    @test shared_edge(l2, 3, 1) == (2, 1)
    @test shared_edge(l2, 1, 3) == (1, 2)
    @test shared_edge(l2, 3, 2) == (1, 2)
    @test shared_edge(l2, 2, 1) == (1, 2)
    # no allocated curve diagrams
    @test num_curves(l1) == 0
    @test num_curves(l2) == 0
    @test curve_ids(l1) == Int[]
    @test curve_ids(l2) == Int[]
    # asymmetric 2-tile adjacency throws
    @test_throws ArgumentError Lattice([[(2,2)], [(1,1), (1, 2)]])
end

@testset "Lattice curve diagram allocation and deletion" begin
    l = Lattice(RING3)
    # dummy curvediagram and curvepiece
    cid1 = _allocate_curve_id!(l)
    _insert_cref!(l, cid1, 1, CurvepieceRef(1, 1))
    # basic operations
    @test cid1 == 1
    @test num_curves(l) == 1
    @test curve_ids(l) == [cid1]
    @test !is_deleted(l, cid1)
    # another dummy
    cid2 = _allocate_curve_id!(l)
    _insert_cref!(l, cid2, 1, CurvepieceRef(2, 1))
    # basic operations
    @test cid2 == 2
    @test num_curves(l) == 2
    @test curve_ids(l) == [cid1, cid2]
    @test !is_deleted(l, cid2)
    # delete curve diagram
    _remove_cref!(l, cid1, 1)
    _delete_curvediagram!(l, cid1)
    @test is_deleted(l, cid1)
    @test !is_deleted(l, cid2)
    @test curve_ids(l) == Int[cid2]
    # tiles_in
    @test tiles_in(l, cid2) == Set([2])
end

@testset "Lattice curve diagram curvepieces" begin
    l = Lattice(RING3)
    cid = _allocate_curve_id!(l)
    # curve diagram from tile 1 edge 2 -> tile 2 edge 1
    cp_id1 = insert_curvepiece!(get_tile(l, 1), 10, 1, 2, 1, OUT)
    cp_id2 = insert_curvepiece!(get_tile(l, 2), 10, 1, 1, 1, IN)
    ref1 = CurvepieceRef(1, cp_id1)
    ref2 = CurvepieceRef(2, cp_id2)
    # store and retrieve curvepiece reference
    _insert_cref!(l, cid, 1, ref1)
    _insert_cref!(l, cid, 2, ref2)
    @test get_curvediagram(l, cid) == [ref1, ref2]
    # sibling_endpoint
    siblingtile, siblingeref = sibling_eref(l, 1, EndpointRef(cp_id1, 2))
    @test siblingtile == 2
    @test siblingeref.cp_id == cp_id2
    ep = endpoint(get_tile(l, 2), siblingeref)::EdgeEndpoint
    @test ep.edge == 1 && ep.pos == 1
    # prev, next, curveposition
    @test prev_curvepiece(l, CurvepieceRef(1, cp_id1)) === nothing
    @test next_curvepiece(l, CurvepieceRef(1, cp_id1)) == CurvepieceRef(2, cp_id2)
    @test prev_curvepiece(l, CurvepieceRef(2, cp_id2)) == CurvepieceRef(1, cp_id1)
    @test next_curvepiece(l, CurvepieceRef(2, cp_id2)) === nothing
    @test find_cref_index(l, cid, CurvepieceRef(1, cp_id1)) == 1
    @test find_cref_index(l, cid, CurvepieceRef(2, cp_id2)) == 2
    @test find_cref_index(l, cid, CurvepieceRef(2, 3)) === nothing
    # anyon_curve_id and anyon_tiles
    @test anyon_curve_id(get_tile(l, 1)) == 10
    @test anyon_curve_id(get_tile(l, 2)) == 10
    @test anyon_curve_id(get_tile(l, 3)) === nothing
    @test anyon_tiles(l, cid) == [1, 2]
end

@testset "Lattice sibling functions" begin
    # one endpoint on tile 2 edge 1
    let l = Lattice(HEX)
        cid = _allocate_curve_id!(l)
        insert_curvepiece!(get_tile(l, 2), cid, 1, 1, 1, 2, 1)
        # sibling of pos 1 is pos 1, insert pos is 2
        @test sibling_location(l, 1, 1, 1) == (2, 1, 1)
        @test sibling_insert_pos(l, 1, 1, 1) == 2
    end
    # two endpoints on tile 2 edge 1
    let l = Lattice(HEX)
        cid = _allocate_curve_id!(l)
        insert_curvepiece!(get_tile(l, 2), cid, 1, 1, 1, 1, 2)
        # positions reverse (pos 1 <-> pos2), insert pos is sibling_pos + 1
        @test sibling_location(l, 1, 1, 1) == (2, 1, 2)
        @test sibling_location(l, 1, 1, 2) == (2, 1, 1)
        @test sibling_insert_pos(l, 1, 1, 1) == 3
    end
end

@testset "Lattice anyon functions" begin
    let l = Lattice(RING3)
        cid = _allocate_curve_id!(l)
        t1 = get_tile(l, 1)
        t2 = get_tile(l, 2)
        t3 = get_tile(l, 3)

        # 3-anyon curve from t2's anyon to t3's anyon to (through t2) t1's anyon
        # 5 curvepieces, a through e

        # t2e2 -> t3e1 crossing, curvepieces a and b
        pos_b = sibling_insert_pos(l, 2, 2, 1)
        cp_a = insert_curvepiece!(t2, cid, 1, 2, 1, OUT)
        cp_b = insert_curvepiece!(t3, cid, 1, 1, pos_b, IN)

        # t3e1 -> t2e2 and t2e1 -> t1e2 crossings, curvepieces c, d, and e
        pos_d_in = sibling_insert_pos(l, 3, 1, 2)
        pos_e    = sibling_insert_pos(l, 2, 1, 1)
        cp_c = insert_curvepiece!(t3, cid, 2, 1, 2, OUT)
        cp_d = insert_curvepiece!(t2, cid, 2, 2, pos_d_in, 1, 1)
        cp_e = insert_curvepiece!(t1, cid, 2, 2, pos_e, IN)

        # register curvepieces to curvediagram
        _insert_cref!(l, cid, 1, CurvepieceRef(2, cp_a))
        _insert_cref!(l, cid, 2, CurvepieceRef(3, cp_b))
        _insert_cref!(l, cid, 3, CurvepieceRef(3, cp_c))
        _insert_cref!(l, cid, 4, CurvepieceRef(2, cp_d))
        _insert_cref!(l, cid, 5, CurvepieceRef(1, cp_e))

        @test anyon_tiles(l, cid) == [2, 3, 1]

        @test next_anyon(l, 2) == 3
        @test next_anyon(l, 3) == 1
        @test next_anyon(l, 1) === nothing

        @test prev_anyon(l, 2) === nothing
        @test prev_anyon(l, 3) == 2
        @test prev_anyon(l, 1) == 3

        # throws when tile's anyon is not on any curve
        l2 = Lattice(RING3)
        @test_throws ArgumentError next_anyon(l2, 1)
        @test_throws ArgumentError prev_anyon(l2, 1)
    end
end

@testset "Lattice internal mutators" begin
    # _insert_curvediagram_entry! and _remove_cref!
    let l = Lattice(RING3)
        cid = _allocate_curve_id!(l)
        # three piece curve diagram
        r1 = CurvepieceRef(1, 10)
        r2 = CurvepieceRef(2, 20)
        r3 = CurvepieceRef(3, 30)
        _insert_cref!(l, cid, 1, r1)
        _insert_cref!(l, cid, 2, r2)
        _insert_cref!(l, cid, 3, r3)
        @test get_curvediagram(l, cid) == [r1, r2, r3]
        # remove r3
        _remove_cref!(l, cid, 3)
        @test get_curvediagram(l, cid) == [r1, r2]
    end

    # _shift_anyon_count!
    let l = Lattice(RING3)
        cid = _allocate_curve_id!(l)
        t1 = get_tile(l, 1)
        t2 = get_tile(l, 2)
        cp1 = insert_curvepiece!(t1, cid, 1, 1, 1, OUT)
        cp2 = insert_curvepiece!(t2, cid, 1, 1, 1, IN)
        _insert_cref!(l, cid, 1, CurvepieceRef(1, cp1))
        _insert_cref!(l, cid, 2, CurvepieceRef(2, cp2))
        # shift by +1 from pos 2 onwards
        _shift_anyon_count!(l, cid, 2, 1)
        @test curvepiece(t1, cp1).anyon_count == 1
        @test curvepiece(t2, cp2).anyon_count == 2
        # shift both by -1
        _shift_anyon_count!(l, cid, 1, -1)
        @test curvepiece(t1, cp1).anyon_count == 0
        @test curvepiece(t2, cp2).anyon_count == 1
    end

    # _delete_curvediagram!
    let l = Lattice(RING3)
        cid = _allocate_curve_id!(l)
        r = CurvepieceRef(1, 1)
        _insert_cref!(l, cid, 1, r)
        # deleting a nonempty curve diagram throws
        @test_throws ArgumentError _delete_curvediagram!(l, cid)
        # deleting an empty curve diagram works
        _remove_cref!(l, cid, 1)
        _delete_curvediagram!(l, cid)
        @test is_deleted(l, cid)
    end

    # _relabel_curve!
    let l = Lattice(RING3)
        old_cid = _allocate_curve_id!(l)
        new_cid = _allocate_curve_id!(l)
        cp1 = insert_curvepiece!(get_tile(l, 1), old_cid, 1, 2, 1, OUT)
        cp2 = insert_curvepiece!(get_tile(l, 2), old_cid, 1, 1, 1, IN)
        # now register them as belonging to a different curve
        _insert_cref!(l, new_cid, 1, CurvepieceRef(1, cp1))
        _insert_cref!(l, new_cid, 2, CurvepieceRef(2, cp2))
        # make sure relabeling modifies the curvepieces
        _relabel_curve!(l, old_cid, new_cid)
        @test curvepiece(get_tile(l, 1), cp1).curve_id == new_cid
        @test curvepiece(get_tile(l, 2), cp2).curve_id == new_cid
    end
end
