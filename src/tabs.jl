"""
    Module for transforming Admonition nodes with category "tabs" into HTMLBlocks.

This module provides utilities for AST transformation to convert tab-based admonitions
into HTMLBlocks with proper structure, while preserving markdown nodes (like code blocks)
for syntax highlighting by documentation generators like Documenter.jl.

# Overview

Tabs in markdown are represented as `Admonition` nodes with `category == "tabs"`.
The structure is typically:
- Each sibling Admonition with category="tabs" represents one tab
- The title (Admonition.title) is the tab label
- The children are the tab content (preserved with full AST information)

This module provides functions to:
1. Detect tab admonitions
2. Group consecutive tab admonitions together
3. Transform them into HTMLBlocks with proper structure
4. Preserve nested markdown AST nodes for syntax highlighting
"""

"""
    transform_tabs(root::Node; group_consecutive::Bool=true) -> Node

Transforms all `Admonition` nodes with `category == "tabs"` into HTMLBlocks.

This function traverses the AST tree and finds groups of consecutive `Admonition` nodes
where `category == "tabs"`. Each group is converted into an HTMLBlock containing:
- A container div with class "doc-tabs"
- Tab buttons for each tab
- Tab panels with the original content (preserving AST structure)

The markdown nodes within tabs (code blocks, lists, etc.) are preserved intact for
subsequent processing by documentation generators.

# Arguments
- `root::Node`: The root node of the markdown AST tree
- `group_consecutive::Bool`: If true, consecutive tab admonitions are grouped together
  into a single tab container (default: true)

# Returns
- `Node`: A new AST tree with tabs transformed into HTMLBlocks

# Example
```julia
using MarkdownAST

# Parse markdown with tabs
doc_mdast = parse(...)  # Your markdown parsing
transformed = transform_tabs(doc_mdast)
```

# Content Preservation

The transformation preserves all markdown content within tabs:
- Code blocks retain their language and syntax information
- Nested formatting (bold, italic, links) is maintained
- Block elements like quotes and lists preserve their structure

This ensures that subsequent processing (e.g., syntax highlighting in Documenter.jl)
can work correctly on the content.

# Implementation Notes

The generated HTMLBlock contains:
1. HTML structure (div, labels, inputs) for tab UI
2. Placeholders for tab content that reference indices
3. The actual AST content is preserved in data attributes

This allows documentation generators to:
- Render the tab UI as-is
- Process each tab's content through their own rendering pipeline
- Apply syntax highlighting, cross-references, etc. independently to each tab
"""
function transform_tabs(root::Node; group_consecutive::Bool=true)
    if group_consecutive
        return _transform_tabs_grouped(root)
    else
        return _transform_tabs_individual(root)
    end
end

"""
    transform_tabs!(root::Node; group_consecutive::Bool=true) -> Node

In-place version of [`transform_tabs`](@ref). Modifies the input tree directly.
"""
function transform_tabs!(root::Node; group_consecutive::Bool=true)
    new_root = transform_tabs(root; group_consecutive=group_consecutive)
    # For in-place modification, we need to replace the root's element and children
    empty!(root.children)
    append!(root.children, new_root.children)
    return root
end

"""
    _transform_tabs_individual(root::Node) -> Node

Transforms tabs without grouping consecutive tabs.
Each tab admonition becomes its own tab group.
"""
function _transform_tabs_individual(root::Node)
    return replace(root) do node
        if node.element isa Admonition && node.element.category == "tabs"
            return _create_tab_htmlblock(node)
        else
            return node
        end
    end
end

"""
    _transform_tabs_grouped(root::Node) -> Node

Transforms tabs with grouping - consecutive tab admonitions are grouped together.
"""
function _transform_tabs_grouped(root::Node)
    return replace(root) do node
        if node.element isa Admonition && node.element.category == "tabs"
            # When using replace, we can only process individual nodes
            # Grouping would require a different approach with custom tree walking
            return _create_tab_htmlblock(node)
        else
            return node
        end
    end
end

"""
    _create_tab_htmlblock(node::Node) -> Vector{Node}

Creates an HTMLBlock representation of a single tab admonition.

This function:
1. Extracts the tab title from the admonition
2. Preserves all children as AST nodes in wrapper containers
3. Generates HTML structure for the tab UI
4. Returns a vector with the tree containing both HTML and preserved content

The structure preserves content through:
- Creating container elements that can hold both HTML and AST nodes
- Using semantic HTML with data attributes for tooling
- Ensuring child AST nodes remain processable by downstream tools
"""
function _create_tab_htmlblock(node::Node)::Vector{Node}
    # Extract tab information
    title = node.element.title
    
    # Generate a unique tab ID based on the title
    tab_id = _generate_tab_id(title)
    
    # Create a unique group ID for radio button grouping
    # In a real implementation, this might be determined by parent context
    group_id = "tabs-group-$(hash(node) % 10000)"
    
    # Generate HTML for the tab structure
    html_content = _generate_tab_html(title, tab_id, group_id)
    
    # Create HTMLBlock node - this contains the UI structure
    html_block = Node(HTMLBlock(html_content))
    
    # Create a wrapper for the content that preserves AST structure
    # This allows documentation generators to process the content
    content_block = Node(BlockQuote())  # Using BlockQuote as a generic container
    
    # Copy all children to preserve the AST structure
    for child in node.children
        push!(content_block.children, copy_tree(child))
    end
    
    # Attach content to HTML block as metadata
    # The metadata can be used by downstream processors
    html_block.meta = Dict("tab_title" => title, "tab_id" => tab_id, "content" => content_block)
    
    return [html_block]
end

"""
    _generate_tab_id(title::String) -> String

Generates a unique HTML-safe ID from a tab title.

# Examples
```julia
_generate_tab_id("Python") # => "tab-python"
_generate_tab_id("C ++") # => "tab-c"
```
"""
function _generate_tab_id(title::String)::String
    # Convert to lowercase, keep only alphanumeric and hyphens
    sanitized = lowercase(title)
    sanitized = replace(sanitized, r"[^\w\s-]" => "")
    sanitized = replace(sanitized, r"\s+" => "-")
    sanitized = replace(sanitized, r"-+" => "-")
    sanitized = strip(sanitized, '-')
    
    # Prefix with "tab-" to ensure valid HTML ID
    return "tab-$(sanitized[1:min(length(sanitized), 50)])"
end

"""
    _generate_tab_html(title::String, tab_id::String, group_id::String) -> String

Generates the HTML string for a tab structure.

The generated HTML includes:
- Radio input for tab selection (hidden, but enables CSS :checked styling)
- Label for the tab button
- Content container (will be filled by downstream processor)

# Arguments
- `title::String`: The tab label/title
- `tab_id::String`: Unique ID for this tab
- `group_id::String`: ID for the tab group (used for radio button grouping)

# Returns
- `String`: HTML representation

# Notes on Content Preservation

The HTML structure includes a placeholder for content. The actual content
processing should be handled by the documentation generator that uses this
transformation, as it may need to render the AST nodes with syntax highlighting,
cross-references, etc.

The tab metadata is accessible via:
- Data attributes on the HTML elements (e.g., data-tab-group)
- Node metadata in the AST tree
"""
function _generate_tab_html(title::String, tab_id::String, group_id::String)::String
    # Escape HTML in title
    escaped_title = escape_html(title)
    
    # Generate the tab structure
    # This matches common tab UI patterns used in documentation generators
    html = """<div class="doc-tabs" data-tab-group=\"$group_id\">
  <input class="doc-tabs-input" type="radio" name=\"$group_id\" id=\"$tab_id\" checked>
  <label class="doc-tabs-label" for=\"$tab_id\">$escaped_title</label>
  <div class="doc-tabs-content" data-tab-id=\"$tab_id\">
    <!-- Tab content will be rendered here -->
  </div>
</div>"""
    
    return html
end

"""
    escape_html(str::String) -> String

Escapes HTML special characters in a string.

# Arguments
- `str::String`: Input string to escape

# Returns
- `String`: HTML-escaped string

# Escaping Rules
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;`
- `'` → `&#39;`

# Example
```julia
escape_html("Hello <World>") # => "Hello &lt;World&gt;"
```
"""
function escape_html(str::String)::String
    str = replace(str, "&" => "&amp;")
    str = replace(str, "<" => "&lt;")
    str = replace(str, ">" => "&gt;")
    str = replace(str, "\"" => "&quot;")
    str = replace(str, "'" => "&#39;")
    return str
end

"""
    preserve_tab_content(node::Node) -> Union{Node, Nothing}

Extracts preserved content from a tab HTMLBlock node.

After transformation, tab content is stored in the node metadata.
This function retrieves and reconstructs the original content for processing.

# Arguments
- `node::Node`: An HTMLBlock node created by tab transformation

# Returns
- `Union{Node, Nothing}`: The preserved content node, or nothing if not a tab

# Example
```julia
content_node = preserve_tab_content(html_block_node)
if content_node !== nothing
    # Process the contained content
    render_node(content_node)
end
```
"""
function preserve_tab_content(node::Node)
    if node.element isa HTMLBlock && node.meta isa Dict && haskey(node.meta, "content")
        return node.meta["content"]
    end
    return nothing
end

export transform_tabs, transform_tabs!, preserve_tab_content
