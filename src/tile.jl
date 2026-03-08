@enum EndpointDirection IN OUT
@enum EndpointType EDGE ANYON

struct CurvepieceEndpoint
    cp_id::Int
    etype::EndpointType
    direction::EndpointDirection
end

function _validate_curvepiece_endpoints(a::CurvepieceEndpoint, b::CurvepieceEndpoint)
    a.cp_id == b.cp_id ||
        throw(ArgumentError("curvepiece cannot have endpoints with different ids"))
    a.etype == b.etype == EDGE && a.direction != b.direction ||
        throw(ArgumentError("curvepiece cannot have two edge endpoints with same direction"))
    a.etype == b.etype == ANYON &&
        throw(ArgumentError("curvepiece cannot have two anyon endpoints"))
    (a.etype == ANYON || b.etype == ANYON) && a.direction != b.direction &&
        throw(ArgumentError("curvepiece cannot have edge and anyon endpoints with different directions"))
end

function Base.isless(a::CurvepieceEndpoint, b::CurvepieceEndpoint)
    _validate_curvepiece_endpoints(a, b)
    if a.etype == b.etype == EDGE
        # they must have opposing directions
        return a.direction == IN
    end
    # they must both have the same direction as there is one anyon endpoint
    if a.direction == IN
        return a.etype == EDGE
    end
    if a.direction == OUT
        return a.etype == ANYON
    end
end

order_curvepiece_endpoints(a::CurvepieceEndpoint, b::CurvepieceEndpoint) =
    a < b ? a, b : b, a

const CurvepieceEndpointIndex = Tuple{Int, Int}

struct CurvepieceData
    curve_id::Int
    position_in_curve::Int
    endpoint_indices::Vector{CurvepieceEndpointIndex}
end

struct Tile
    next_cp_id::Ref{Int}
    cp_endpoints::NTuple{7, Vector{CurvepieceEndpoint}}
    cp_data::Dict{Int, CurvepieceData}
    Tile() = new(Ref(1), Tuple(CurvepieceEndpoint[] for _ in 1:7), Dict())
end

get_curvepiece_ids(t::Tile) =
    sort(collect(keys(t.cp_data)))

get_curvepiece_endpoint(t::Tile, cp_endpt_idx::CurvepieceEndpointIndex) =
    t.cp_endpoints[cp_endpt_idx[1]][cp_endpt_idx[2]]

get_curvepiece_edge_endpoint(t::Tile, edge::Int, idx::Int) =
    get_curvepiece_endpoint(t, CurvepieceEndpointIndex((edge, idx)))

get_curvepiece_anyon_endpoint(t::Tile, idx::Int) =
    get_curvepiece_endpoint(t, CurvepieceEndpointIndex((7, idx)))

function get_curvepiece_endpoints(t::Tile, cp_id::Int)
    cpd = t.cp_data[cp_id]
    cpe1 = get_curvepiece_endpoint(t, first(cpd.endpoint_indices))
    cpe2 = get_curvepiece_endpoint(t, last(cpd.endpoint_indices))
    order_curvepiece_endpoints(cpe1, cpe2)
end

get_curvepiece_edge_endpoints(t::Tile, edge::Int) =
    t.cp_endpoints[edge][:]

get_curvepiece_edge_endpoints(t::Tile) =
    cat(t.cp_endpoints[1:6]...; dims=1)

get_curvepiece_anyon_endpoints(t::Tile) =
    t.cp_endpoints[7][:]

function get_other_curvepiece_endpoint(t::Tile, cp_endpt::CurvepieceEndpoint)
    cp_endpts = get_curvepiece_endpoints(t, cp_endpt.cp_id)
    cp_endpts[1] == cp_endpt ? cp_endpts[2] : cp_endpts[1]
end

function get_curvepiece_endpoint_index(t::Tile, cp_endpt::CurvepieceEndpoint)
    endpt_inds = t.cp_data[cp_endpt.cp_id].endpoint_indices
    get_curvepiece_endpoint(t, endpt_inds[1]) == cp_endpt ?
        endpt_inds[1] : endpt_inds[2]
end

function _allocate_cp_id!(t::Tile)
    id = t.next_cp_id[]
    t.next_cp_id[] += 1
    id
end

function _set_cpd_cpeis!(t::Tile)
    # empty endpoint indices array in curvepoint data
    for cp_id in get_curvepiece_ids(t::Tile)
        empty!(t.cp_data[cp_id].endpoint_indices)
    end
    # iterate through curvepiece endpoints, setting endpoint indices;
    # i is the edge num for i ∈ 1:6, i == 7 is anyon endpoints
    for i in 1:7
        for (n, cpe) in enumerate(t.cp_endpoints[i])
            cpei = CurvepieceEndpointIndex((i, n))
            push!(t.cp_data[cpe.cp_id].endpoint_indices, cpei)
        end
    end
    # iterate through curvepiece endpoint indices, making sure there are two per curvepiece;
    # next, order them in the same way the endpoints should be ordered
    for cp_id in get_curvepiece_ids(t)
        cpd = t.cp_data[cp_id]
        length(cpd.endpoint_indices) == 2 || error("curvepiece $cp_id doesn't have 2 endpoints, got $(cpd.endpoint_indices)")
        cpe1, cpe2 = get_curvepiece_endpoint.(t, cpd.endpoint_indices)
        cpe1 < cpe2 || cpd.endpoint_indices[:] = reverse(cpd.endpoint_indices)
    end
    nothing
end

function insert_curvepiece!(t::Tile, edge1::Int, idx1::Int, edge2::Int, idx2::Int, curve_id::Int, position_in_curve::Int)
    cp_id = _allocate_cp_id!(t)
    cpe1 = CurvepieceEndpoint(cp_id, EDGE, IN)
    cpe2 = CurvepieceEndpoint(cp_id, EDGE, OUT)
    cpd = CurvepieceData(curve_id, position_in_curve, []) # initially empty array will be filled in _set_cpd_cpeis
    insert!(t.cp_endpoints[edge1], idx1, cpe1)
    insert!(t.cp_endpoints[edge2], idx2, cpe2)
    t.cp_data[cp_id] = cpd
    _set_cpd_cpeis!(t)
end

function insert_curvepiece!(t::Tile, edge::Int, idx1::Int, idx2::Int, direction::EndpointDirection, curve_id::Int, position_in_curve::Int)
    cp_id = _allocate_cp_id!(t)
    cpe1 = CurvepieceEndpoint(cp_id, EDGE, direction)
    cpe2 = CurvepieceEndpoint(cp_id, ANYON, direction)
    cpd = CurvepieceData(curve_id, position_in_curve, [])
    insert!(t.cp_endpoints[edge], idx1, cpe1)
    insert!(t.cp_endpoints[7], idx2, cpe2)
    t.cp_data[cp_id] = cpd
    _set_cpd_cpeis!(t)
end
