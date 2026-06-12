@testset "CurvepieceEndpoint; Curvepiece" begin
    # random filler values that shouldn't affect test results
    maxrandval = 6
    curve_id, anyon_count = rand(1:maxrandval), rand(1:maxrandval)
    edge1, pos1 = rand(1:maxrandval), rand(1:maxrandval)
    edge2, pos2 = rand(1:maxrandval), rand(1:maxrandval)
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
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ae_in, ae_in)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ae_in, ae_out)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ae_out, ae_in)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ae_out, ae_out)
    # check that two edge endpoints on a curvepiece cannot have the same direction
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ee_in, ee_in)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ee_out, ee_out)
    # check that an edge and anyon endpoint in the same curvepiece cannot have different directions
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ae_in, ee_out)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ae_out, ee_in)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ee_in, ae_out)
    @test_throws ArgumentError Curvepiece(curve_id, anyon_count, ee_out, ae_in)
    # check that endpoints are automatically correctly ordered for the three valid cases
    @test Curvepiece(curve_id, anyon_count, ee_in, ae_in)      == Curvepiece(curve_id, anyon_count, ae_in, ee_in)
    @test Curvepiece(curve_id, anyon_count, ee_out, ae_out)    == Curvepiece(curve_id, anyon_count, ae_out, ee_out)
    @test Curvepiece(curve_id, anyon_count, ee_in, ee_out)     == Curvepiece(curve_id, anyon_count, ee_out, ee_in)
end

@testset "change_endpoint_location" begin
    maxrandval = 6
    curve_id, anyon_count = rand(1:maxrandval), rand(1:maxrandval)
    # initial edge endpoint locations
    edge1, pos1 = rand(1:maxrandval), rand(1:maxrandval)
    edge2, pos2 = rand(1:maxrandval), rand(1:maxrandval)
    # new edge endpoint location
    edge3, pos3 = rand(1:maxrandval), rand(1:maxrandval)
    # boundary curvepiece's edge endpoint moved to another edge
    let changed_idx = rand(1:2) # choose endpoint to change
        eps = EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2)
        cp = Curvepiece(curve_id, anyon_count, eps...)
        # change chosen endpoint's location
        new_cp = change_endpoint_location(cp, changed_idx, edge3, pos3)
        # fetch new endpoints
        changed_ep = new_cp.endpoints[changed_idx]
        unchanged_ep = new_cp.endpoints[3-changed_idx]
        # check that they're correct
        dir3 = changed_idx == 1 ? IN : OUT
        @test changed_ep == EdgeEndpoint(dir3, edge3, pos3)
        @test unchanged_ep == (changed_idx == 1 ? EdgeEndpoint(OUT, edge2, pos2) : EdgeEndpoint(IN, edge1, pos1))
    end
    # boundary curvepiece's edge endpoint moved to anyon
    let changed_idx = rand(1:2) # choose which endpoint to chnage
        eps = EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2)
        cp = Curvepiece(curve_id, anyon_count, eps...)
        # change chosen endpoint's location
        new_cp = change_endpoint_location(cp, changed_idx, nothing, nothing)
        # fetch new endpoints
        changed_ep = new_cp.endpoints[changed_idx]
        unchanged_ep = new_cp.endpoints[3-changed_idx]
        # check that they're correct
        dir3 = changed_idx == 1 ? OUT : IN
        @test changed_ep == AnyonEndpoint(dir3)
        @test unchanged_ep == (changed_idx == 1 ? EdgeEndpoint(OUT, edge2, pos2) : EdgeEndpoint(IN, edge1, pos1))
    end
    # central curvepiece's anyon endpoint moved to edge
    let anyon_idx = rand(1:2) # choose curvepiece direction
        eps = anyon_idx == 1 ? (AnyonEndpoint(OUT), EdgeEndpoint(OUT, edge2, pos2)) : (EdgeEndpoint(IN, edge1, pos1), AnyonEndpoint(IN))
        cp = Curvepiece(curve_id, anyon_count, eps...)
        # change anyon endpoint's location
        new_cp = change_endpoint_location(cp, anyon_idx, edge3, pos3)
        # fetch new endpoints
        changed_ep = new_cp.endpoints[anyon_idx]
        unchanged_ep = new_cp.endpoints[3-anyon_idx]
        # check that they're correct
        dir3 = anyon_idx == 1 ? IN : OUT
        @test changed_ep == EdgeEndpoint(dir3, edge3, pos3)
        @test unchanged_ep == (anyon_idx == 1 ? EdgeEndpoint(OUT, edge2, pos2) : EdgeEndpoint(IN, edge1, pos1))
    end
    # central curvepiece's anyon endpoint moved to anyon
    let anyon_idx = rand(1:2) # choose curvepiece direction
        eps = anyon_idx == 1 ? (AnyonEndpoint(OUT), EdgeEndpoint(OUT, edge2, pos2)) : (EdgeEndpoint(IN, edge1, pos1), AnyonEndpoint(IN))
        cp = Curvepiece(curve_id, anyon_count, eps...)
        # change anyon endpoint's location
        new_cp = change_endpoint_location(cp, anyon_idx, nothing, nothing)
        # fetch new endpoints
        anyon_ep = new_cp.endpoints[anyon_idx]
        edge_ep = new_cp.endpoints[3-anyon_idx]
        # check that they're correct
        dir3 = anyon_idx == 1 ? OUT : IN
        @test anyon_ep == AnyonEndpoint(dir3)
        @test edge_ep == (anyon_idx == 1 ? EdgeEndpoint(OUT, edge2, pos2) : EdgeEndpoint(IN, edge1, pos1))
    end
    # TODO add two other cases
end
