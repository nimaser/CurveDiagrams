"""
Draws lattice `l` onto `ax`, using `tile_vertices` to supply the polygon vertex list for each tile.

`tile_vertices` is a `Dict` from `tile_id` to a clockwise vertex list. Tiles whose `tile_id` is
not a key in `tile_vertices` are silently skipped (useful for omitting e.g. a virtual outer
plaquette).

Returns a `Dict{Int, Any}` mapping each visualized `tile_id` to the plot-handle tuple returned
by the per-tile `visualize!` call.
"""
function CurveDiagrams.visualize!(
    ax::Axis,
    l::Lattice,
    tile_vertices::Dict{Int, <:Vector{<:Point2}};
    sharpness::Real = 0.3
)
    tile_plots = Dict{Int, Any}()
    for tile_id in 1:num_tiles(l)
        haskey(tile_vertices, tile_id) || continue
        t = get_tile(l, tile_id)
        v = tile_vertices[tile_id]
        tile_plots[tile_id] = visualize!(ax, t, v; sharpness=sharpness)
    end
    tile_plots
end

"""
Visualizes lattice `l` using `tile_vertices` to supply per-tile polygon vertices.

Creates a new `Figure` and `Axis`, draws all tiles present in `tile_vertices`, attaches a
`DataInspector` for curvepiece tooltips, and returns the figure.
"""
function CurveDiagrams.visualize(
    l::Lattice,
    tile_vertices::Dict{Int, <:Vector{<:Point2}};
    sharpness::Real = 0.3
)
    f  = Figure()
    ax = Axis(f[1, 1]; aspect=DataAspect())
    visualize!(ax, l, tile_vertices; sharpness=sharpness)
    DataInspector(f)
    hidespines!(ax)
    hidedecorations!(ax)
    resize_to_layout!(f)
    f
end
