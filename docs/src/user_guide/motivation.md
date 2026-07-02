# Introduction
Consider any compact and orientable 2D manifold $\Sigma$, and a tailed lattice
$L'$ embedded in $\Sigma$. Let $L$ be $L'$ but with the tails removed, meaning
every vertix in $L$ is of degree 2 or 3. A lattice model realization of an
anyon theory can be defined on $L'$, where each plaquette of $L'$ (face of $L$)
is capable of carrying topological charge.

As a concrete example, let's consider that $\Sigma$ is the unit 2-sphere $S^2$,
and $L$ is a 3x3 honeycomb lattice with one additional [TODO]-edge face on the
'back side' of the sphere (blue plaquette number 10 in the image below):

[TODO INSERT IMAGE]

Suppose we want to classically store and manipulate a quantum state (written in
an anyonic fusion tree basis) of this lattice model. Then we need to first
choose a specific basis by choosing a fusion order and creating the associated
fusion tree with one leaf per plaquette. Each basis state is then some labeling
of the tree's leaves/branches with anyon sectors, and the entire quantum state
can be represented with a mapping from those labelings to quantum amplitudes:

[TODO INSERT IMAGE]

Because the Hilbert space grows exponentially with the size of the lattice,
memory constraints will make storing a generic quantum state infeasible for
large lattices. However, if we know that the quantum state we want to store
lives in a particular smaller subspace of the full Hilbert space, then an
efficient representation may be possible. We consider two structures the state
could have that restrict the size of the Hilbert space: when we have both of
them together, classical representation of the state becomes tractable.

### Tensor Product Structure
Consider a

Consider the basis set of

Suppose that the quantum state, expressed in some anyonic fusion tree basis,
has a definite label $l$ for some internal branch, or in other words all of the
basis elements with nonzero amplitude

In other words, suppose that all
of the basis elements with nonzero amplitude in
the quantum state, all of the basis elements with a nonzero amplitude are have
that branch taking that label. A final restatement: the projection operator

Suppose that only the basis states with a 
Suppose that every basis state with nonzero amplitude in a quantum state shares
the same label for one specific branch.

![TODO ALT TEXT](assets/factorizability.svg)

### Sparsity
Suppose that most plaquettes in the lattice have a trivial topological charge.
If our basis is the left-handed fusion tree where we fuse all of the trivial
plaquettes together first (resulting in a trivial branch), and then fuse in
the nontrivial plaquettes,
If we choose a basis where all of those plaquettes.
Omitting those trivial plaquettes from our fusion tree reduces its number of
leaves and branches, exponentially reducing the number of labelings and
therefore quantum amplitudes that need to be stored. This exponential saving
in memory also leads to savings in processing time when manipulating the tree.


suppose we know
that the quantum states we want to store are highly factorizable? This means
that every basis state with a nonzero amplitude is one wh


If most plaquettes on the lattice carry a trivial charge for the quantum state
we are interested in computationally
If the quantum state on the lattice is mostly 
In the case that the quantum state on the latticek



of $L$, $D$.https://en.wikipedia.org/wiki/Combinatorial_map

anyon models, tailed lattices, plaquettes, topological charge, anyonic fusion tree basis

For convenience
We choose to work with 'left-handed' fusion trees as our standard basis. A
left-handed fusion tree is one where, after the initial first two leaves are
fused into a branch, every other leaf is fused into an existing branch in
sequence, until only the root is left: 

[TODO INSERT IMAGE]
