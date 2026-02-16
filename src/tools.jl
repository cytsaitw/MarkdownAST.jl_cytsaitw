"""
    copy_tree(root::Node)
    copy_tree(f, root::Node)

Creates a copy of the tree, starting from `node` as the root node, and  optionally calling `f`
on each of the nodes to determine the corresponding `.element` in the copied tree.

If `node` is not the root of its tree, its parent nodes are ignored, and the root node of the
copied node corresponds to `node`.

The function `f` should have the signature `(::Node, ::AbstractElement) -> AbstractElement`,
and it gets passed the current node being copied and its element. It must return an instance
of some [`AbstractElement`](@ref), which will then be assigned to the `.element` field of
the copied node. By default, `copy_tree` performs a `deepcopy` of both the element
(`.element`) and the node metadata (`.meta`).

# Extended help

For example, to perform a `copy` instead of `deepcopy` on the elements, `copy_tree` can be
called as follows

```julia
copy_tree((_, e) -> copy(e), node::Node)
```

Note that `copy_tree` does not allow the construction of invalid trees, and element
replacements that require invalid parent-child relationships (e.g. a block element as a child
to an element expecting inlines) will throw an error.
"""
function copy_tree end
function copy_tree(f, root::Node{M}) where M
    new_element = f(root, root.element)
    new_root = Node{M}(new_element, deepcopy(root.meta))
    for child in root.children
        new_child = copy_tree(f, child)
        push!(new_root.children, new_child)
    end
    return new_root
end
copy_tree(root::Node) = copy_tree((_, e) -> deepcopy(e), root)

# Helper functions for Table() elements

"""
    tablerows(node::Node)

Returns an iterable object containing the all the [`TableRow`](@ref) elements of a table,
bypassing the intermediate [`TableHeader`](@ref) and [`TableBody`](@ref) nodes. Requires
`node` to be a [`Table`](@ref) element.

The first element of the iterator should be interpreted to be the header of the table.
"""
function tablerows(node::Node)
    node.element isa Table || error("needs a Table() node")
    Iterators.flatten(child.children for child in node.children)
end

"""
    tablesize(node::Node, [dim])

Similar to `size`, returns the number of rows and/or columns of a [`Table`](@ref) element.
The optional `dim` argument can be passed to return just either the number of rows or columns,
and must be `1` to obtain the number of rows, and `2` to obtain the number of columns.

!!! note "Complexity"

    Determining the number of columns is an ``O(n \\times m)`` operation in the number of rows
    and columns, due to the required traversal of the linked nodes. Determining only the number
    of rows with `tablesize(node, 1)` is an ``O(n)`` operation.
"""
function tablesize end
tablesize(node::Node) = _tablesize(node, true)
function tablesize(node::Node, dim::Integer)
    if dim == 1
        _tablesize(node, false)[1]
    elseif dim == 2
        _tablesize(node, true)[2]
    else
        error("dimension out of range")
    end
end
function _tablesize(node::Node, countcols::Bool)
    node.element isa Table || error("needs a Table() node")
    nrows, ncols = 0, 0
    for row in tablerows(node)
        nrows += 1
        if countcols
            ncols = max(length(row.children), ncols)
        end
    end
    return nrows, ncols
end

# --- Tabs Admonition transformer -------------------------------------------------
"""
    transform_tabs_admonitions(root::Node)

Transforms `Admonition` nodes with `category == "tabs"` into a sequence of
`HTMLBlock` and original Markdown nodes so that the tab labels are emitted as
raw HTML while the tab panel contents remain as Markdown AST nodes. Keeping the
panel contents as Markdown nodes preserves code blocks and other elements for
Documenter syntax highlighting.
"""
function transform_tabs_admonitions(root::Node)
    escape_html(s::String) = replace(replace(replace(replace(s, "&" => "&amp;"), "<" => "&lt;"), ">" => "&gt;"), '"' => "&quot;")

    function collect_plain_text(n::Node)
        txt = ""
        # If the node itself is a leaf inline with textual content, include it
        el = n.element
        if el isa Text
            return el.text
        elseif el isa Code
            return el.code
        end
        for c in n.children
            txt *= collect_plain_text(c)
        end
        return txt
    end

    f = function(node::Node)
        el = node.element
        if el isa Admonition && el.category == "tabs"
            children = collect(node.children)

            # First pass: find headings (tab labels) and split panels
            labels = String[]
            panels = Vector{Vector{Node}}()
            current_panel = Vector{Node}()
            seen_heading = false

            for child in children
                if child.element isa Heading
                    # start a new panel
                    label = collect_plain_text(child)
                    push!(labels, escape_html(label))
                    if seen_heading
                        push!(panels, current_panel)
                        current_panel = Vector{Node}()
                    else
                        seen_heading = true
                    end
                else
                    push!(current_panel, child)
                end
            end

            if !seen_heading
                # nothing to transform: return original node
                return node
            end

            # push the final panel
            push!(panels, current_panel)

            result = Vector{Node}()

            push!(result, Node(HTMLBlock("<div class=\"doc-tabs\">")))

            # Labels container
            push!(result, Node(HTMLBlock("<div class=\"doc-tabs__labels\">")))
            for (i, label) in enumerate(labels)
                btn = "<button class=\"doc-tabs__label\" data-tab=\"$(i)\">$(label)</button>"
                push!(result, Node(HTMLBlock(btn)))
            end
            push!(result, Node(HTMLBlock("</div>")))

            # Panels: keep original Markdown nodes inside
            for (i, panel_nodes) in enumerate(panels)
                push!(result, Node(HTMLBlock("<div class=\"doc-tabs__panel\" data-tab=\"$(i)\">")))
                # append panel nodes (these are Node objects). They will be unlinked and
                # re-inserted by the parent caller when constructing the new tree.
                for pn in panel_nodes
                    push!(result, pn)
                end
                push!(result, Node(HTMLBlock("</div>")))
            end

            push!(result, Node(HTMLBlock("</div>")))

            return result
        else
            return node
        end
    end

    replace!(f, root)
    return root
end

