function fuzz_boundary_curvepiece_insertions!(t::Tile, insertions::Int)
    inserted_cp_ids = Int[]
    tile_snapshots = Tile[]
    completed = 0
    while completed < insertions
        # random insertion location
        edge1, edge2 = rand(1:num_edges(t), 2)
        pos1 = rand(1:num_edge_erefs(t, edge1)+1)
        pos2 = if edge1 == edge2
            rand(1:num_edge_erefs(t, edge2) + 2)
        else
            rand(1:num_edge_erefs(t, edge2) + 1)
        end
        # try insertion, skip if it causes argument error (i.e. intersection)
        try
            cp_id = insert_curvepiece!(t, rand(Int), rand(UInt), edge1, pos1, edge2, pos2)
            push!(inserted_cp_ids, cp_id)
            push!(tile_snapshots, deepcopy(t))
            completed += 1
        catch e
            e isa ArgumentError || rethrow(e)
        end
    end
    inserted_cp_ids, tile_snapshots
end

function fuzz_central_curvepiece_insertions!(t::Tile, insertions::Int)
    inserted_cp_ids = Int[]
    tile_snapshots = Tile[]
    num_anyon_erefs(t) == 2 && return inserted_cp_ids, tile_snapshots
    completed = 0
    while completed < insertions
        # random insertion location
        edge = rand(1:num_edges(t))
        pos = rand(1:num_edge_erefs(t, edge))
        dir = rand((IN, OUT))
        # appropriate cid and acount values
        cid, acount = curve_id(t), anyon_count(t)
        cid = isnothing(cid) ? rand(Int) : cid
        if isnothing(acount)
            acount = rand(typemin(Int) + 1:typemax(Int) - 1)
        else
            incoming, outgoing = ordered_central_curvepieces(t)
            dir, acount = isnothing(outgoing) ? (OUT, incoming.anyon_count + 1) : (IN, outgoing.anyon_count - 1)
        end
        # try insertion, skip if it causes argument error (i.e. intersection)
        try
            cp_id = insert_curvepiece!(t, cid, acount, edge, pos, dir)
            push!(inserted_cp_ids, cp_id)
            push!(tile_snapshots, deepcopy(t))
            completed += 1
        catch e
            e isa ArgumentError || rethrow(e)
        end
    end
    inserted_cp_ids, tile_snapshots
end

function fuzz_curvepiece_removals!(t::Tile, removals::Int)
    removed_cp_ids = Int[]
    tile_snapshots = Tile[]
    completed = 0
    while completed < removals
        cp_id = rand(curvepiece_ids(t))
        remove_curvepiece!(t, cp_id)
        push!(removed_cp_ids, cp_id)
        push!(tile_snapshots, deepcopy(t))
        completed += 1
    end
    removed_cp_ids, tile_snapshots
end

function deterministic_curvepiece_removals!(t::Tile, removal_sequence::Vector{Int})
    tile_snapshots = Tile[]
    for cp_id in removal_sequence
        remove_curvepiece!(t, cp_id)
        push!(tile_snapshots, deepcopy(t))
    end
    tile_snapshots
end

function fuzz_endpoint_moves!(t::Tile, moves::Int)
    move_log = Tuple{EndpointRef, Int, Int}[]  # eref, original_edge, original_pos
    tile_snapshots = Tile[]
    completed = 0
    while completed < moves
        # random eref to move
        edge_src = rand(1:num_edges(t))
        !has_edge_erefs(t, edge_src) && continue
        pos_src = rand(1:num_edge_erefs(t, edge_src))
        eref = edge_eref(t, edge_src, pos_src)
        # random move location
        edge_tgt = rand(1:num_edges(t))
        pos_tgt = rand(1:num_edge_erefs(t, edge_tgt) + 1)
        try
            move_endpoint!(t, eref, edge_tgt, pos_tgt)
            push!(move_log, (eref, edge_src, pos_src))
            push!(tile_snapshots, deepcopy(t))
            completed += 1
        catch e
            e isa ArgumentError || rethrow(e)
        end
    end
    move_log, tile_snapshots
end
