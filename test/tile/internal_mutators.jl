
@testset "_insert_edge_eref!" begin
    # _insert_edge_eref! - inserts eref and shifts existing ones up
        let t = Tile(3)
            # cp1 has both endpoints on edge 1 at initial positions 1 and 2
            t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 1), EdgeEndpoint(OUT, 1, 2))
            _insert_edge_eref!(t, EndpointRef(1, 1), 1, 1)
            _insert_edge_eref!(t, EndpointRef(1, 2), 1, 2)
            # cp3's edge-1 endpoint (EndpointRef(3,2)) will be inserted at pos 1, shifting cp1 to pos 2 and 3
            t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 1, 1))
            _insert_edge_eref!(t, EndpointRef(3, 1), 3, 1)
            _insert_edge_eref!(t, EndpointRef(3, 2), 1, 1)
            # check that EndpointRefs are correct
            @test edge_eref(t, 1, 1) == EndpointRef(3, 2)
            @test edge_eref(t, 1, 2) == EndpointRef(1, 1)
            @test edge_eref(t, 1, 3) == EndpointRef(1, 2)
            # check that Endpoints are correct
            @test (endpoint(t, EndpointRef(1, 1))).pos == 2  # shifted
            @test (endpoint(t, EndpointRef(1, 2))).pos == 3  # shifted
        end
end

@testset "_remove_edge_eref!" begin
    # _remove_edge_eref! — removes eref and shifts existing ones down
        let t = Tile(3)
            # cp1 has endpoints at positions 2 and 3 on edge 1, cp3 has an endpoint at pos 1 on edge 1
            t._curvepieces[1] = Curvepiece(1, 1, EdgeEndpoint(IN, 1, 2), EdgeEndpoint(OUT, 1, 3))
            t._curvepieces[3] = Curvepiece(3, 1, EdgeEndpoint(IN, 3, 1), EdgeEndpoint(OUT, 1, 1))
            _insert_edge_eref!(t, EndpointRef(3, 2), 1, 1)
            _insert_edge_eref!(t, EndpointRef(1, 1), 1, 2)
            _insert_edge_eref!(t, EndpointRef(1, 2), 1, 3)
            # remove pos 1 on edge 1, shifting curvepiece 1's endpoints over
            _remove_edge_eref!(t, 1, 1)
            @test num_edge_erefs(t, 1) == 2
            @test edge_eref(t, 1, 1) == EndpointRef(1, 1)
            @test edge_eref(t, 1, 2) == EndpointRef(1, 2)
            @test (endpoint(t, EndpointRef(1, 1))::EdgeEndpoint).pos == 1  # shifted
            @test (endpoint(t, EndpointRef(1, 2))::EdgeEndpoint).pos == 2  # shifted
        end
end
