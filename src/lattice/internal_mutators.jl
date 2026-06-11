"""Returns the next curve_id to be assigned."""
function _allocate_curve_id!(l::Lattice)
    push!(l._curvediagrams, CurvepieceRef[])
    length(l._curvediagrams)
end

"""Inserts `ref` at position `pos` in the curve diagram with id `curve_id`."""
function _insert_cref!(l::Lattice, curve_id::Int, pos::Int, ref::CurvepieceRef)
    insert!(l._curvediagrams[curve_id], pos, ref)
end

"""Removes the entry at position `pos` from the curve diagram with id `curve_id`."""
function _remove_cref!(l::Lattice, curve_id::Int, pos::Int)
    deleteat!(l._curvediagrams[curve_id], pos)
end

"""
For every entry in the curve diagram at list-position >= `from_pos`, calls
`set_curvepiece_metadata!` on its tile to add `delta` to `anyon_count`.
Call with `delta=+1` after inserting an anyon, `delta=-1` after removing one.
"""
function _shift_anyon_count!(l::Lattice, curve_id::Int, from_pos::Int, delta::Int)
    diagram = l._curvediagrams[curve_id]
    for pos in from_pos:length(diagram)
        ref = diagram[pos]
        t = get_tile(l, ref.tile_id)
        cp = curvepiece(t, ref.cp_id)
        set_curvepiece_metadata!(t, ref.cp_id, cp.curve_id, cp.anyon_count + delta)
    end
end

"""
Empties `l._curvediagrams[curve_id]`, permanently retiring the id. All `CurvepieceRef`s in the
diagram must have been removed from their tiles before calling this.
"""
function _delete_curvediagram!(l::Lattice, curve_id::Int)
    isempty(l._curvediagrams[curve_id]) || throw(ArgumentError("curvediagram $curve_id not empty"))
    empty!(l._curvediagrams[curve_id])
end

"""
Updates the `curve_id` field on every `Curvepiece` in every tile that currently has `old_curve_id`,
replacing it with `new_curve_id`. Used in `merge!` after the two `CurveDiagram` vectors have been
concatenated into the surviving curve. Does not delete `old_curve_id`; call `_delete_curvediagram!`
separately.
"""
function _relabel_curve!(l::Lattice, old_curve_id::Int, new_curve_id::Int)
    for ref in l._curvediagrams[new_curve_id]
        t = get_tile(l, ref.tile_id)
        cp = curvepiece(t, ref.cp_id)
        cp.curve_id == old_curve_id || continue
        set_curvepiece_metadata!(t, ref.cp_id, new_curve_id, cp.anyon_count)
    end
end
