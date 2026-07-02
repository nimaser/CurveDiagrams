"""
Curvepieces can only start or end at anyons, so being made up of curvepieces, any `CurveDiagram`
can also only start or end on an anyon. This means that any curvepiece endpoint on a tile edge
must have a 'sibling' endpoint which lives on the corresponding edge in the adjacent tile. For
any edge with N endpoints on it, its corresponding edge also has N endpoints.

Given a position `n` of an endpoint on an edge `edge` in `tile_id`, this function returns the
`(neighbor_tile_id, neighbor_edge, neighbor_pos)` of its sibling endpoint. Because endpoint
positions on edges are assigned clockwise and 1-indexed, if an endpoint has position `n` out of
`N` total endpoints on an edge, its sibling endpoint has position `N - n + 1` on the corresponding
edge.

This function cannot be relied upon when the lattice is in an incorrect state, i.e. when the
number of endpoints on an edge of one tile is different than the number on its corresponding edge.
This means that its use near tile mutation methods such as `insert_curvepiece!` must be cautious.

Similarly, note that using this function to get an insertion position will lead to wrong behavior
if used naively: getting the sibling location in tile t2 of (edge, pos) in tile t1, then inserting
at t1, edge, pos and t2, sibling_edge, sibling_pos, will not lead to aligned curvepieces. This is
because insertions on either side shift everything clockwise locally which are opposite directions
on either side of the edge. So the sibling insertion must be done at sibling_pos + 1.
"""
function sibling_location(l::Lattice, tile_id::Int, edge::Int, n::Int)
    cedge = corresponding_edge(l, tile_id, edge)
    neighbortile = get_tile(l, cedge.tile_id)
    N = num_edge_erefs(neighbortile, cedge.edge)
    sibling_pos = N - n + 1
    cedge.tile_id, cedge.edge, sibling_pos
end

"""
Given an edge endpoint in `tile_id`, this function returns `(neighbor_tile_id, EndpointRef)` of its
sibling endpoint, using `sibling_location` internally.
"""
function sibling_eref(l::Lattice, tile_id::Int, eref::EndpointRef)
    ep::EdgeEndpoint = endpoint(get_tile(l, tile_id), eref)
    neighbor_tile_id, neighbor_edge, neighbor_pos = sibling_location(l, tile_id, ep.edge, ep.pos)
    neighbortile = get_tile(l, neighbor_tile_id)
    neighbor_tile_id, edge_eref(neighbortile, neighbor_edge, neighbor_pos)
end
