using Documenter, CurveDiagrams

makedocs(
    sitename = "CurveDiagrams",
    modules = [CurveDiagrams],
    pages = [
        "Home" => "index.md",
        "Introduction" => "introduction.md",
    ],
)
