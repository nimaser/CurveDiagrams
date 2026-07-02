"""
Function to get the tiles which contain anyons on a specific curve.

Returns a vector of `tile_id`s for tiles which contain anyons which are on the
curve with `curve_id`. Tiles are returned in path order.

If this function turns out to be bottlenecking, a slightly more efficient solution
would be to scan the curve diagram's curvepieces with a window size of two, and
any time two successive curvepieces had the same tile_id, add them to the set.
This is because the only time this condition can be met is when there are two
anyon-to-edge curvepieces, meaning that tile's anyon is on the curve diagram.
The first and last anyons' tiles would need to be in the initial set as a special
case.
"""
function anyon_tiles(l::Lattice, curve_id::Int)
    ids = Int[] # returned result, containing tile_ids
    seen = Set{Int}() # tile_ids for tiles with anyons which have already been added to ids
    # go through all of the CurvepieceRefs in the curve
    for ref in get_curve(l, curve_id)
        ref.tile_id ∈ seen && continue # only one anyon per tile, so we can just skip
        t = get_tile(l, ref.tile_id)
        if is_central_curvepiece(t, ref.cp_id)
            push!(ids, ref.tile_id)
            push!(seen, ref.tile_id)
        end
    end
    ids
end

"""
Returns the id of the tile whose anyon is just after `tile_id`s anyon on its curve diagram.

Returns `nothing` if this is the last anyon on its curve diagram.
Throws an error if `tile_id`s anyon is not on a curve diagram.
"""
function next_anyon(l::Lattice, tile_id::Int)
    cid = curve_id(get_tile(l, tile_id))
    cid === nothing && throw(ArgumentError("tile $tile_id's anyon not on a curve diagram"))
    tiles = anyon_tiles(l, cid)
    idx = findfirst(==(tile_id), tiles)
    idx == length(tiles) ? nothing : tiles[idx+1]
end

"""
Returns the id of the tile whose anyon is just before `tile_id`s anyon on its curve diagram.

Returns `nothing` if this is the first anyon on its curve diagram.
Throws an error if `tile_id`s anyon is not on a curve diagram.
"""
function prev_anyon(l::Lattice, tile_id::Int)
    cid = curve_id(get_tile(l, tile_id))
    cid === nothing && throw(ArgumentError("tile $tile_id's anyon not on a curve diagram"))
    tiles = anyon_tiles(l, cid)
    idx = findfirst(==(tile_id), tiles)
    idx == 1 ? nothing : tiles[idx-1]
end
