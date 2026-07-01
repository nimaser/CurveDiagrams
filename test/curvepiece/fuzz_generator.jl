function _fuzz_representative_endpoints()
    edge1, pos1 = rand(1:typemax(Int)), rand(1:typemax(Int))
    edge2, pos2 = rand(1:typemax(Int)), rand(1:typemax(Int))
    a_in = AnyonEndpoint(IN)
    a_out = AnyonEndpoint(OUT)
    e_in = EdgeEndpoint(IN, edge1, pos1)
    e_out = EdgeEndpoint(OUT, edge2, pos2)
    a_in, a_out, e_in, e_out
end
