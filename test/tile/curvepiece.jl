@testset "CurvepieceEndpoint; Curvepiece; first; last" begin
    # random fillers
    cid, acount = rand(Int), rand(UInt)
    edge1, pos1 = rand(UInt), rand(UInt)
    edge2, pos2 = rand(UInt), rand(UInt)
    # construct four representative curvepiece endpoints
    a_in  = AnyonEndpoint(IN)
    a_out = AnyonEndpoint(OUT)
    e_in  = EdgeEndpoint(IN, edge1, pos1)
    e_out = EdgeEndpoint(OUT, edge2, pos2)
    # check that they have the right type hierarchy
    for ep in (a_in, a_out, e_in, e_out) @test ep isa CurvepieceEndpoint end
    # check that two anyon endpoints cannot be on the same curvepiece
    @test_throws ArgumentError Curvepiece(cid, acount, a_in , a_in )
    @test_throws ArgumentError Curvepiece(cid, acount, a_in , a_out)
    @test_throws ArgumentError Curvepiece(cid, acount, a_out, a_in )
    @test_throws ArgumentError Curvepiece(cid, acount, a_out, a_out)
    # check that two edge endpoints on a curvepiece cannot have the same direction
    @test_throws ArgumentError Curvepiece(cid, acount, e_in , e_in )
    @test_throws ArgumentError Curvepiece(cid, acount, e_out, e_out)
    # check that an edge and anyon endpoint in the same curvepiece cannot have different directions
    @test_throws ArgumentError Curvepiece(cid, acount, a_in , e_out)
    @test_throws ArgumentError Curvepiece(cid, acount, a_out, e_in )
    @test_throws ArgumentError Curvepiece(cid, acount, e_in , a_out)
    @test_throws ArgumentError Curvepiece(cid, acount, e_out, a_in )
    # check that endpoints are automatically, consistently, and correctly ordered
    cp1 = Curvepiece(cid, acount, e_in , a_in )
    cp2 = Curvepiece(cid, acount, a_out, e_out)
    cp3 = Curvepiece(cid, acount, e_in , e_out)
    @test cp1 == Curvepiece(cid, acount, a_in , e_in )
    @test cp2 == Curvepiece(cid, acount, e_out, a_out)
    @test cp3 == Curvepiece(cid, acount, e_out, e_in )
    @test first(cp1) == cp1.endpoints[1] == e_in
    @test first(cp2) == cp2.endpoints[1] == a_out
    @test first(cp3) == cp3.endpoints[1] == e_in
    @test last(cp1) == cp1.endpoints[2] == a_in
    @test last(cp2) == cp2.endpoints[2] == e_out
    @test last(cp3) == cp3.endpoints[2] == e_out
end

@testset "change_endpoint_location" begin
    # random fillers
    cid, acount = rand(Int), rand(UInt)
    # initial edge endpoint locations
    edge1, pos1 = rand(UInt), rand(UInt)
    edge2, pos2 = rand(UInt), rand(UInt)
    # new edge endpoint location
    edge3, pos3 = rand(UInt), rand(UInt)

    # we just test every possibility

    ### CASE 1: E, E -> E ###
    let eps = EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2)
        cp = Curvepiece(cid, acount, eps...)
        let # changed_idx = 1
            new_cp = change_endpoint_location(cp, 1, edge3, pos3)
            @test first(new_cp) == EdgeEndpoint(IN, edge3, pos3) # changed
            @test last(new_cp) == last(cp) # unchanged
        end
        let # changed_idx = 2
            new_cp = change_endpoint_location(cp, 2, edge3, pos3)
            @test first(new_cp) == first(cp) # unchanged
            @test last(new_cp) == EdgeEndpoint(OUT, edge3, pos3) # changed
        end
    end

    ### CASE 2: E, A -> E ###
    let eps = AnyonEndpoint(OUT), EdgeEndpoint(OUT, edge2, pos2) # changed_idx = 1
        cp = Curvepiece(cid, acount, eps...)
        new_cp = change_endpoint_location(cp, 1, edge3, pos3)
        @test first(new_cp) == EdgeEndpoint(IN, edge3, pos3) # changed
        @test last(new_cp) == last(cp) # unchanged
    end
    let eps = EdgeEndpoint(IN, edge1, pos1), AnyonEndpoint(IN) # changed_idx = 2
        cp = Curvepiece(cid, acount, eps...)
        new_cp = change_endpoint_location(cp, 2, edge3, pos3)
        @test first(new_cp) == first(cp) # unchanged
        @test last(new_cp) == EdgeEndpoint(OUT, edge3, pos3) # changed
    end

    ### CASE 3: E, E -> A ###
    let eps = EdgeEndpoint(IN, edge1, pos1), EdgeEndpoint(OUT, edge2, pos2)
        cp = Curvepiece(cid, acount, eps...)
        let # changed_idx = 1
            new_cp = change_endpoint_location(cp, 1, nothing, nothing)
            @test first(new_cp) == AnyonEndpoint(OUT) # changed
            @test last(new_cp) == last(cp) # unchanged
        end
        let # changed_idx = 2
            new_cp = change_endpoint_location(cp, 2, nothing, nothing)
            @test first(new_cp) == first(cp) # unchanged
            @test last(new_cp) == AnyonEndpoint(IN) # changed
        end
    end

    ### CASE 4: A, E -> E ###
    let eps = EdgeEndpoint(IN, edge1, pos1), AnyonEndpoint(IN) # changed_idx = 1
        cp = Curvepiece(cid, acount, eps...)
        new_cp = change_endpoint_location(cp, 1, edge3, pos3)
        @test first(new_cp) == EdgeEndpoint(IN, edge3, pos3) # changed
        @test last(new_cp) == last(cp) # unchanged
    end
    let eps = AnyonEndpoint(OUT), EdgeEndpoint(OUT, edge2, pos2) # changed_idx = 2
        cp = Curvepiece(cid, acount, eps...)
        new_cp = change_endpoint_location(cp, 2, edge3, pos3)
        @test first(new_cp) == first(cp) # unchanged
        @test last(new_cp) == EdgeEndpoint(OUT, edge3, pos3) # changed
    end

    ### CASE 5: E, A -> A ###
    let eps = AnyonEndpoint(OUT), EdgeEndpoint(OUT, edge2, pos2) # changed_idx = 1
        cp = Curvepiece(cid, acount, eps...)
        new_cp = change_endpoint_location(cp, 1, nothing, nothing)
        @test first(new_cp) == first(cp) # unchanged
        @test last(new_cp) == last(cp) # unchanged
    end
    let eps = EdgeEndpoint(IN, edge1, pos1), AnyonEndpoint(IN) # changed_idx = 2
        cp = Curvepiece(cid, acount, eps...)
        new_cp = change_endpoint_location(cp, 2, nothing, nothing)
        @test first(new_cp) == first(cp) # unchanged
        @test last(new_cp) == last(cp) # unchanged
    end

    ### CASE 6: A, E -> A ###
    let eps = EdgeEndpoint(IN, edge1, pos1), AnyonEndpoint(IN) # changed_idx = 1
        cp = Curvepiece(cid, acount, eps...)
        @test_throws ArgumentError new_cp = change_endpoint_location(cp, 1, nothing, nothing)
    end
    let eps = AnyonEndpoint(OUT), EdgeEndpoint(OUT, edge2, pos2) # changed_idx = 2
        cp = Curvepiece(cid, acount, eps...)
        @test_throws ArgumentError new_cp = change_endpoint_location(cp, 2, nothing, nothing)
    end
end
