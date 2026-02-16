# Tab Transformation Guide

## Overview

The tab transformation system in MarkdownAST provides a way to convert tab-based admonitions (syntax: `!!! tabs "Title"`) into HTMLBlocks while preserving the underlying markdown AST nodes for syntax highlighting and other downstream processing.

## Problem Statement

When using tabs in documentation:
1. **Original issue**: Simply converting Admonitions to HTML strings loses the AST information needed for syntax highlighting
2. **Solution**: Store both the HTML structure and preserve the original AST nodes through node metadata

## Architecture

### Node Metadata Strategy

The transformation uses Julia's node metadata system to store both:
1. HTML structure (for UI rendering)
2. Preserved AST content (for processing)

```
HTMLBlock {html}
├── meta["tab_title"] = "Python"
├── meta["tab_id"] = "tab-python"
└── meta["content"] = BlockQuote
    └── CodeBlock { info: "python", code: "..." }
```

### Data Flow

```
Original Admonition → transform_tabs() → HTMLBlock + Preserved Children
                                         │
                                         ├── HTML for UI rendering
                                         └── AST nodes for processing
                                              └── Syntax highlighting
                                              └── Cross-references
                                              └── Numbering
```

## Usage

### Basic Transformation

```julia
using MarkdownAST: MarkdownAST, Node, transform_tabs
using Markdown: @md_str

# Create markdown with tabs
doc = md"""
!!! tabs "Python"
    
    ```python
    print("Hello")
    ```

!!! tabs "Julia"
    
    ```julia
    println("Hello")
    ```
"""

# Convert to MarkdownAST
doc_mdast = convert(Node, doc)

# Transform tabs
transformed = transform_tabs(doc_mdast)
```

### Accessing Transformed Content

```julia
using MarkdownAST: preserve_tab_content

# Find HTMLBlocks created by transformation
for node in transformed.children
    if node.element isa HTMLBlock
        content = preserve_tab_content(node)
        if !isnothing(content)
            # Process tab content
            process_tab_content(content)
        end
    end
end
```

### In-Place Transformation

```julia
transform_tabs!(doc_mdast)  # Modifies doc_mdast directly
```

## Integration with Documenter.jl

### Recommended Implementation

To integrate with Documenter.jl:

```julia
# In your docs/make.jl

using Documenter, MarkdownAST

# Your documentation pages
pages = [...]

# Build documentation with custom preprocessor
makedocs(
    # ... other options ...
    pages = pages,
    format = HTML(
        # Custom JavaScript/CSS for tabs
        assets = ["assets/tabs.js", "assets/tabs.css"]
    ),
    # Use a custom pipeline that transforms tabs
)

# Or in your documentation process:
# 1. Load markdown document
# 2. Convert to MarkdownAST
# 3. Apply transform_tabs()
# 4. Convert back for rendering with content preservation
```

### Content Processing Pipeline

```
Markdown File
    ↓
Parse → MarkdownAST
    ↓
transform_tabs() → HTMLBlocks + Preserved AST
    ↓
┌─ HTML Rendering  ┬─ AST Processing ─┐
│ (UI Structure)   │ (Syntax Highlight) │
│                  │ (Cross-refs)       │
│                  │ (Numbering)        │
└─────────────────┰─────────────────────┘
                  │
            Final Output
```

## Content Preservation Details

### What is Preserved

- **Code blocks**: Language info and code content retained
  - Enables syntax highlighting
  - Allows language-specific processing

- **Lists**: Ordered/unordered structure maintained
  - Numbering can be applied per list
  - Nested structures supported

- **Links**: References preserved
  - Cross-references can be resolved
  - External links maintained

- **Formatting**: Bold, italic, code preserved
  - Inline formatting tags retained
  - Text nodes preserved

- **Nested blocks**: Quotes, admonitions, etc.
  - Full nesting supported
  - Can contain any valid markdown block

### Example: Code Block Preservation

```
Input Admonition:
  category: "tabs"
  title: "Python"
  children: [CodeBlock(info="python", code="print('hello')")]

After transformation:
HTMLBlock { html: "<div class='doc-tabs'>..." }
  meta["content"] = BlockQuote
    └── CodeBlock(info="python", code="print('hello')")
        ↑ Can still apply syntax highlighting!
```

## HTML Generation

### Generated Structure

Each tab creates this HTML structure:

```html
<div class="doc-tabs" data-tab-group="tabs-group-{id}">
  <input class="doc-tabs-input" type="radio" name="tabs-group-{id}" id="tab-{title}" checked>
  <label class="doc-tabs-label" for="tab-{title}">{title}</label>
  <div class="doc-tabs-content" data-tab-id="tab-{title}">
    <!-- Content will be rendered here -->
  </div>
</div>
```

### Styling with CSS

```css
.doc-tabs {
    border: 1px solid #ddd;
    border-radius: 4px;
}

.doc-tabs-input {
    display: none;
}

.doc-tabs-label {
    display: inline-block;
    padding: 10px 20px;
    border-bottom: 2px solid transparent;
    cursor: pointer;
}

.doc-tabs-input:checked + .doc-tabs-label {
    border-bottom-color: #0066cc;
}

.doc-tabs-content {
    display: none;
    padding: 20px;
}

.doc-tabs-input:checked + .doc-tabs-label + .doc-tabs-content {
    display: block;
}
```

### Tab Event Handling with JavaScript

```javascript
// For grouped tabs with synchronized switching
document.querySelectorAll('.doc-tabs-input').forEach(input => {
    input.addEventListener('change', function() {
        const groupName = this.name;
        const selectedId = this.id;
        
        // Update all tabs in the group
        document.querySelectorAll(`input[name="${groupName}"]`).forEach(tab => {
            tab.checked = (tab.id === selectedId);
        });
    });
});
```

## Advanced Features

### Grouping Consecutive Tabs

When `group_consecutive=true` (default):
```julia
transform_tabs(root; group_consecutive=true)
```

Consecutive tabs with the same category are grouped:
```
Tab 1 ─┐
Tab 2  ├─→ Single Tab Group
Tab 3 ─┘
```

### Custom ID Generation

IDs are generated from titles:
- "Python" → "tab-python"
- "C++" → "tab-c"
- "Foo Bar" → "tab-foo-bar"

Special characters are removed/replaced for HTML safety.

### Metadata Access

```julia
# Access tab metadata
node.meta["tab_title"]  # Original title
node.meta["tab_id"]     # Generated HTML ID
node.meta["content"]    # BlockQuote with children

# Check if a node is a transformed tab
if node.element isa HTMLBlock && haskey(node.meta, "tab_title")
    # This is a transformed tab
end
```

## Best Practices

### 1. Always Preserve Content

✅ **Good**: Content stored in metadata
```julia
# Automatically done by transform_tabs()
html_node.meta["content"] = BlockQuote(children...)
```

❌ **Bad**: Content lost as HTML string
```julia
# Avoid this pattern
html_string = "<div>" * string(content) * "</div>"
```

### 2. Process After Transformation

```julia
# Transform first
transformed = transform_tabs(doc)

# Then process nodes
for node in transformed.children
    if node.element isa HTMLBlock
        content = preserve_tab_content(node)
        apply_syntax_highlighting(content)
    end
end
```

### 3. Handle Multiple Languages

```julia
# Each tab content is independent
for child in tab_content.children
    if child.element isa CodeBlock
        highlight_code(child.element.info, child.element.code)
    end
end
```

## Troubleshooting

### Issue: Content not preserved

**Solution**: Check node metadata
```julia
if node.element isa HTMLBlock
    content = preserve_tab_content(node)
    @assert !isnothing(content)
end
```

### Issue: HTML is escaped twice

**Solution**: escaping is done once at generation
```julia
# Don't re-escape when rendering
render_html(node.element.html)  # Already safe
```

### Issue: Tabs not grouped

**Solution**: Use `group_consecutive=true` parameter
```julia
transform_tabs(root; group_consecutive=true)
```

## API Reference

### Main Functions

```julia
transform_tabs(root::Node; group_consecutive::Bool=true) -> Node
transform_tabs!(root::Node; group_consecutive::Bool=true) -> Node
preserve_tab_content(node::Node) -> Union{Node, Nothing}
```

### Internal Functions

```julia
_generate_tab_id(title::String) -> String
_generate_tab_html(title::String, tab_id::String, group_id::String) -> String
escape_html(str::String) -> String
```

## Examples

See `examples/tabs_transformation.jl` for complete working examples.

## See Also

- [AST Macro Documentation](astmacro.md)
- [Node Documentation](node.md)
- [MarkdownAST Elements](elements.md)
