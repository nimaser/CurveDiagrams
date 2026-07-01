"""
Return a `Dict{Int, Tuple{Int, Int}}` mapping curvepiece ids to a (nesting level,
max enclosing number) tuple for each curvepiece.

Boundary curvepieces in a tile may be nested inside each other, in the sense that
their endpoints may enclose both endpoints of another curvepiece. In other words,
each boundary curvepiece partitions the tile into two parts, and all other boundary
curvepieces will lay entirely inside one of those parts. The 'nesting level' of a
boundary curvepiece is the number of nested layers of boundary curvepieces enclosed
within it.

To be clear, the nesting level is not the total number of curvepieces enclosed
within a curvepiece. Consider two situations, each with three curvepieces A, B,
and C. First:
- C encloses nothing
- B encloses C's endpoints
- A encloses B's endpoints
In this case, C, B, and A have nesting numbers of 1, 2, and 3 respectively. Next:
- C encloses nothing
- B encloses nothing
- A encloses both B and C's endpoints
In this case, B and C are akin to 'siblings', both having nesting numbers of 1,
while A has a nesting number of 2. So nesting level counts nested layers, not
total enclosed curvpeieces.

Because the endpoints live on a circle, there are two ways to do the nesting level
assignment, depending on which partition part you consider "inside" vs "outside"
for any particular curvepiece's partition. In the extreme case, two endpoints
which are directly adjacent could either be said to enclose all other curvepieces,
or no other curvepieces.

We choose to assign nesting levels in a way that is globally self-consistent for
all curvepieces within a tile and, loosely speaking, minimizes the nesting levels
assigned across all curvepieces in the tile. To do this, we start by scanning the
tile's endpoints, assigning all curvepieces with adjacent endpoints a nesting level
of 1. We then do this scan again, ignoring the already assigned endpoints when
determining adjacency, and this time assign curvepieces with adjacent endpoints a
nesting level of 2. We continue scanning, increasing the assigned value each pass,
until all boundary curvepiece endpoints are assigned.

Because of this scheme, nesting levels tend to 'meet' in the 'middle' of the tile,
and the assignments may depend on which endpoint around the tile the adjacency
scans are started.

We also make the choice that no curvepiece is allowed to 'enclose' a central
curvepiece's edge endpoint, meaning if a boundary curvepiece has its endpoints on
either side of a central curvepiece's edge endpoint, it is considered to enclose
every other endpoint on the tile other than those three already mentioned. The
result of this is that nesting level assignment starts from the 'other side' of
the tile, ending at that boundary curvepiece.

The maximum enclosing number for a curvepiece is:
- the largest nesting level of any curvepiece which encloses it
- its own nesting level, if no curvepiece encloses it

The complexity of this function is as follows:
- in the worst case, with `n` edge endpoints, all curvepieces are nested, requiring
`n/2` passes through the outer loop to assign all `n/2` curvepieces
- the inner loop is `O(n)` on each pass, considering building `unassigned`, iterating
through 1:m, and iterating through the `between` loop are all `O(n)`
- therefore, it is `O(n^2)` in time complexity
- in terms of space complexity, `all_edge_erefs`, `assigned`, `nesting`, `max_enc`,
`ee_ids` are all `O(n)` persistent datastructures in the function
- `unassigned`, `consumed`, and `newly_assigned` are also all `O(n)` datastructures,
whose memory is reallocated at the beginning of each loop
- therefore, it is `O(n)` in space complexity
I'm not exactly sure how memory allocations play into things, but there may be
some significant effects there...hopefully not.
"""
function nesting_hierarchy(t::Tile)
    # get all boundary curvepiece ids
    boundary_ids = setdiff(curvepiece_ids(t), central_curvepiece_ids(t))

    # get ordered list of all erefs on the edges, including those belonging to central curvepieces
    tile_edge_erefs = collect(all_edge_erefs(t))
    N = length(tile_edge_erefs)

    # mask for if endpoint has been assigned a nesting level
    # cp_id -> nesting level
    # cp_id -> max enclosing number, set to -1 by default
    assigned = falses(N)
    nesting = Dict{Int,Int}()
    max_enc = Dict{Int,Int}(id => -1 for id in boundary_ids)

    # keep track of the nesting level to assign during each scan
    nesting_level = 1
    while true
        # (idx, eref) tuples for boundary curvepiece erefs lacking an assigned
        # nesting level along with central curvepiece edge erefs, which act as
        # barriers during the adjacency check; this prevents two erefs on
        # opposite sides of a central curvepiece from being immediately assigned
        # nesting level 1
        unassigned = [(i, tile_edge_erefs[i]) for i in 1:N if !assigned[i]]
        length(nesting) == length(boundary_ids) && break # all boundary curvepieces assigned

        # walk through the initially unassigned erefs, assigning adjacent pairs
        M = length(unassigned)
        newly_assigned_mask = falses(M) # whether we assigned this initially unassigned eref during this scan
        newly_assigned = Int[]     # erefs which were assigned this scan
        for m in 1:M
            # skip if we already assigned this or the next initially unassigned erefs
            newly_assigned_mask[m] && continue
            n = mod1(m + 1, M)
            newly_assigned_mask[n] && continue
            # if the two consecutive unassigned erefs are not on the same curvepiece, skip
            # idx_ indexes into tile_edge_erefs, while m and n index into unassigned
            idx_m, eref_m = unassigned[m]
            idx_n, eref_n = unassigned[n]
            eref_m.cp_id == eref_n.cp_id || continue
            # set the nesting level for this curvepiece
            nesting[eref_m.cp_id] = nesting_level
            # get indices between n and m going clockwise, with wraparound, and
            # update the max enclosing number for all of those enclosed curvepieces
            between = idx_m < idx_n ? ((idx_m+1):(idx_n-1)) : Iterators.flatten(((idx_m+1):N, 1:(idx_n-1)))
            for idx in between
                between_id = tile_edge_erefs[idx].cp_id
                if haskey(nesting, between_id)
                    max_enc[between_id] = nesting_level
                end
            end
            # mark these two erefs as assigned
            newly_assigned_mask[m] = newly_assigned_mask[n] = true
            push!(newly_assigned, idx_m, idx_n)
        end

        for i in newly_assigned
            assigned[i] = true
        end
        nesting_level += 1
    end

    # update maximally enclosing curvepiece values from the -1 initial value
    max_enc = Dict(id => max_enc[id] == -1 ? nesting[id] : max_enc[id] for id in boundary_ids)

    # dictionary mapping curvepiece_id to nesting and max enclosing numbers
    Dict(id => (nesting[id], max_enc[id]) for id in boundary_ids)
end
