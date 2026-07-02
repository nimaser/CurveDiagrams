using Documenter, CurveDiagrams

makedocs(
    sitename="CurveDiagrams",
    modules=[CurveDiagrams],
    pages=[
        "Home" => "index.md",
        "User Guide" => [
            "Background" => "user_guide/background.md",
            "Motivation" => "user_guide/motivation.md",
            "Curve Diagrams" => "user_guide/curve_diagrams.md",
        ],
        "Developer Guide" => [
            "Internals" => [
                "Curvepiece" => "internals/curvepiece.md",
                "Tile" => "internals/tile.md",
                "Lattice" => "internals/lattice.md",
            ],
            "Testing" => [
                "Curvepiece" => "testing/curvepiece.md",
                "Tile" => "testing/tile.md",
                "Lattice" => "testing/lattice.md",
            ]
        ],
    ],
)
