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
