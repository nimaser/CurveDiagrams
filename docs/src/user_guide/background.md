# Background
Fully understanding the motivations behind curve diagrams requires understanding
lattice anyon models and some background on TQFTs (Topological Quantum Field
Theories). A short introduction is provided below, based on [^1], TODO, and TODO.

That being said, it is possible to understand the mechanistic implementation
details of curve diagrams without any such background. Readers who want to
start with the technical details of curve diagrams can skip to TODO.

### Big Picture
A TQFT (TQFT) 
Given a surface $\Sigma$, a TQFT (Topological Quantum Field Theory) generates a
Hilbert space $H_\Sigma$
A TQFT (Topological Quantum Field Theory) generates
Consider any closed manifold

So in the abstract, I can choose a compact, closed 2D manifold optionally with boundary, sigma. I can then choose another compact, closed 2D manifold optionally with boundary, sigma'. I can then choose a cobordism C that maps from sigma to sigma', creating a 2+1D manifold W. Marked boundary points on sigma trace out worldlines in W based on the action of C. To clarify terminology, let's say that if two boundary points fuse as a result of C, the result is considered a new marked boundary point. All of this is just mathematical construction/setup. I can then choose a 2+1D TQFT, perhaps doubled Fibonacci for example. This TQFT then says that I can label each marked boundary point with an anyon type, giving a quantum state in space, and that I can interpret the cobordism C as a topological spacetime process involving moving the anyons around, possibly doing braids, fusions, splits, etc. The TQFT then tells me, given my initial labeling (quantum state), what I should expect the resulting state to be, as in superpositions of anyon types on the marked boundary points of sigma'. Is this correct?



#### Motivation
One naive way to describe the quantum state on the lattice would be to make a monolithic
fusion tree which included every plaquette in the lattice. This 

In a lattice model of an anyon theory, a closed manifold may have some number of
punctures 


overlaid with a
trivalent lattice, where at the center of each lattice plaquette is a puncture
in the manifold. These punctures can each carry a topological charge.

A curve diagram is a way of representing the basis

A curve diagram is used to keep track of the anyonic fusion basis used to
express the quantum state of a lattice anyon model, when the state is
extremeley 'factorizable'.

# References
[^1]: [Quantum computation with Turaev-Viro codes](https://arxiv.org/pdf/1002.2816)
