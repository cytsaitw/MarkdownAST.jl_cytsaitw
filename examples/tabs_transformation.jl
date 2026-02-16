# Example: Tab Transformation
#
# This example demonstrates how tab-based admonitions are automatically transformed
# into HTMLBlocks during conversion, while preserving markdown content (like code blocks)
# for syntax highlighting.
#
# Tab admonitions use the "tabs" category with headings as tab labels:
# !!! tabs "Container Title"
#     ## Tab Label 1
#     ```python
#     print("Hello")
#     ```
#     
#     ## Tab Label 2
#     ```julia
#     println("Hello")
#     ```

using MarkdownAST: MarkdownAST, Node, transform_tabs_admonitions
using Markdown: @md_str

# Create a markdown document with tabs
doc = md"""
# Tab Examples

## Python vs Julia

!!! tabs "Language Comparison"

    ## Python

    Python's simple syntax:

    ```python
    def hello():
        print("Hello from Python")
    ```

    ## Julia

    Julia's performance-oriented syntax:

    ```julia
    function hello()
        println("Hello from Julia")
    end
    ```

## Installation Instructions

!!! tabs "Install"

    ## Windows

    Download from the official website:

    ```bash
    choco install mypackage
    ```

    ## Linux

    Use your package manager:

    ```bash
    sudo apt-get install mypackage
    ```

    ## macOS

    Using Homebrew:

    ```bash
    brew install mypackage
    ```
"""

# Convert the standard library AST into MarkdownAST
# NOTE: transform_tabs_admonitions is automatically called during convert()
doc_mdast = convert(Node, doc)

println("=" ^ 70)
println("Transformed AST (tabs → HTMLBlocks with preserved Markdown content):")
println("=" ^ 70)
println(doc_mdast)

# Analyze the transformed tree
println("\n" ^ 2)
println("=" ^ 70)
println("Tab Transformation Analysis:")
println("=" ^ 70)

function analyze_tabs(node::Node, depth=0)
    indent = "  " ^ depth
    
    if node.element isa MarkdownAST.HTMLBlock
        html = node.element.html
        
        # Check for different components of tab structure
        if occursin("doc-tabs\"", html)
            println("- Found tab container")
        elseif occursin("doc-tabs__labels", html)
            println("  - Found labels container")
        elseif occursin("doc-tabs__label", html)
            # Extract the label text from the button
            label_match = match(r">([^<]+)</button>", html)
            if label_match !== nothing
                println("$(indent)✓ Tab label: \"$(label_match[1])\"")
            end
        elseif occursin("doc-tabs__panel", html)
            # Extract panel ID
            panel_match = match(r"data-tab=\"(\d+)\"", html)
            if panel_match !== nothing
                println("$(indent)✓ Panel (tab #$(panel_match[1]))")
            end
        elseif occursin("</div>", html)
            # Closing div
            println("$(indent)✓ Closing div tag")
        end
    end
    
    # Check for preserved Markdown elements
    if node.element isa MarkdownAST.CodeBlock
        println("$(indent)✓ Preserved CodeBlock: language='$(node.element.info)'")
    elseif node.element isa MarkdownAST.Heading
        println("$(indent)✓ Preserved Heading: level=$(node.element.level)")
    elseif node.element isa MarkdownAST.Paragraph
        # Just show that we found a preserved paragraph
        if length(node.children) > 0
            println("$(indent)✓ Preserved Paragraph with content")
        end
    end
    
    # Recursively analyze children
    for child in node.children
        analyze_tabs(child, depth + 1)
    end
end

analyze_tabs(doc_mdast)

println("\n" ^ 2)
println("=" ^ 70)
println("Summary:")
println("=" ^ 70)
println("✓ Tab admonitions have been converted to HTMLBlocks")
println("✓ Tab labels (headings) are now in button elements")
println("✓ Tab content remains as Markdown AST for syntax highlighting")
println("✓ Code blocks, paragraphs, and other elements are preserved")
println("=" ^ 70)
