# Tutorial

This tutorial shows how to use `MarkdownAST`'s tab transformation step by step,
based on the example in `examples/tabs_transformation.jl`.

## 1. Create a markdown document with tab admonitions

Tab admonitions use the `!!! tabs` category. Each `##` heading inside becomes a tab label.

```@example tabs
using MarkdownAST: MarkdownAST, Node, transform_tabs_admonitions
using Markdown: @md_str

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
```

## 2. Convert to a MarkdownAST tree

`transform_tabs_admonitions` is automatically called during `convert`, turning
each `!!! tabs` admonition into a series of `HTMLBlock` nodes while preserving
the child AST nodes (code blocks, paragraphs, etc.) for downstream processing
such as syntax highlighting.

```@example tabs
doc_mdast = convert(Node, doc)
println(doc_mdast)
```

## 3. Inspect the transformed tree

We can walk the tree and identify the `HTMLBlock` nodes produced by the
transformation as well as the preserved `CodeBlock` nodes inside them.

```@example tabs
function analyze_tabs(node::Node, depth=0)
    indent = "  " ^ depth

    if node.element isa MarkdownAST.HTMLBlock
        html = node.element.html
        if occursin("doc-tabs\"", html)
            println("$(indent)Found tab container")
        elseif occursin("doc-tabs__labels", html)
            println("$(indent)Found labels container")
        elseif occursin("doc-tabs__label", html)
            m = match(r">([^<]+)</button>", html)
            m !== nothing && println("$(indent)✓ Tab label: \"$(m[1])\"")
        elseif occursin("doc-tabs__panel", html)
            m = match(r"data-tab=\"(\d+)\"", html)
            m !== nothing && println("$(indent)✓ Panel (tab #$(m[1]))")
        elseif occursin("</div>", html)
            println("$(indent)✓ Closing div tag")
        end
    end

    if node.element isa MarkdownAST.CodeBlock
        println("$(indent)✓ Preserved CodeBlock: language='$(node.element.info)'")
    elseif node.element isa MarkdownAST.Heading
        println("$(indent)✓ Preserved Heading: level=$(node.element.level)")
    elseif node.element isa MarkdownAST.Paragraph && !isempty(node.children)
        println("$(indent)✓ Preserved Paragraph with content")
    end

    for child in node.children
        analyze_tabs(child, depth + 1)
    end
end

analyze_tabs(doc_mdast)
```

## Summary

After the transformation:

- `!!! tabs` admonitions are converted to `HTMLBlock` nodes (for UI rendering).
- Tab labels (the `##` headings) become `<button>` elements.
- Code blocks and other content remain as AST nodes for syntax highlighting and
  further processing.
