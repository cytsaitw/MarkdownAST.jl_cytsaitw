# Tests for tab transformation functionality

using Test
using MarkdownAST: MarkdownAST, Node, Admonition, HTMLBlock, CodeBlock, BlockQuote,
                    Heading, Paragraph, Text, Document, Code, transform_tabs_admonitions
using Markdown: @md_str

@testset "Tab Transformation Tests" begin
    
    @testset "Basic tabs admonition transformation" begin
        # Create markdown with tabs admonition containing headings
        md = md"""
!!! tabs "Python"
    ## Python Label
    
    ```python
    print('hello')
    ```
    
!!! tabs "JavaScript"
    ## JavaScript Label
    
    ```javascript
    console.log('test');
    ```
        """
        
        # Convert to MarkdownAST (transformation happens automatically)
        ast = convert(Node, md)
        
        # Find HTMLBlock elements that indicate transformation occurred
        found_div_open = false
        found_labels = false
        found_panels = false
        
        for child in ast.children
            if child.element isa HTMLBlock
                html = child.element.html
                if occursin("doc-tabs\"", html)
                    found_div_open = true
                end
                if occursin("doc-tabs__labels", html)
                    found_labels = true
                end
                if occursin("doc-tabs__panel", html)
                    found_panels = true
                end
            end
        end
        
        @test found_div_open
        @test found_labels
        @test found_panels
    end
    
    @testset "Tab label extraction from headings" begin
        md = md"""
!!! tabs "Tab Container"
    ## Label One
    
    Content for tab one
    
    ## Label Two
    
    Content for tab two
        """
        
        ast = convert(Node, md)
        
        # Check that labels are extracted and put in buttons
        found_label_one = false
        found_label_two = false
        
        for child in ast.children
            if child.element isa HTMLBlock
                html = child.element.html
                if occursin("Label One", html)
                    found_label_one = true
                end
                if occursin("Label Two", html)
                    found_label_two = true
                end
            end
        end
        
        @test found_label_one
        @test found_label_two
    end
    
    @testset "Content preservation with code blocks" begin
        md = md"""
!!! tabs "Programming"
    ## Python
    
    ```python
    def hello():
        print("Hello")
    ```
        """
        
        ast = convert(Node, md)
        
        # Find code block within the tree
        found_code_block = false
        function find_code_blocks(node)
            if node.element isa CodeBlock
                if node.element.info == "python"
                    found_code_block = true
                end
            end
            for child in node.children
                find_code_blocks(child)
            end
        end
        
        find_code_blocks(ast)
        @test found_code_block
    end
    
    @testset "HTML escaping in tab labels" begin
        md = md"""
!!! tabs "Test"
    ## C++ <dangerous>
    
    Content here
        """
        
        ast = convert(Node, md)
        
        # Check that angle brackets are escaped
        found_escaped = false
        for child in ast.children
            if child.element isa HTMLBlock
                html = child.element.html
                if occursin("&lt;dangerous&gt;", html)
                    found_escaped = true
                end
                # Should NOT contain unescaped version
                @test !occursin("<dangerous>", html) || !occursin("C++ <dangerous>", html)
            end
        end
        
        @test found_escaped
    end
    
    @testset "Non-tabs admonitions pass through unchanged" begin
        md = md"""
!!! note "Important Note"
    This is a note, not tabs
    
    ```julia
    x = 1
    ```
        """
        
        ast = convert(Node, md)
        
        # Find admonition node
        found_admonition = false
        found_code_block = false
        
        function check_admonitions(node)
            if node.element isa Admonition
                if node.element.category == "note"
                    found_admonition = true
                end
            end
            if node.element isa CodeBlock
                found_code_block = true
            end
            for child in node.children
                check_admonitions(child)
            end
        end
        
        check_admonitions(ast)
        
        @test found_admonition
        @test found_code_block
    end
    
    @testset "Multiple tab panels with content" begin
        md = md"""
!!! tabs "Languages"
    ## Rust
    
    Rust is systems programming.
    
    ```rust
    fn main() {
        println!("Hello");
    }
    ```
    
    ## Go
    
    Go is concurrent.
    
    ```go
    func main() {
        fmt.Println("Hello")
    }
    ```
        """
        
        ast = convert(Node, md)
        
        # Verify both panels exist
        panel_count = 0
        for child in ast.children
            if child.element isa HTMLBlock
                html = child.element.html
                if occursin("doc-tabs__panel", html)
                    panel_count += 1
                end
            end
        end
        
        @test panel_count >= 2
    end
    
    @testset "Tab labels have data-tab attributes" begin
        md = md"""
!!! tabs "Test"
    ## First Tab
    
    Content
    
    ## Second Tab
    
    More content
        """
        
        ast = convert(Node, md)
        
        # Check for data-tab attributes on buttons and panels
        button_tabs = 0
        panel_tabs = 0
        
        for child in ast.children
            if child.element isa HTMLBlock
                html = child.element.html
                if occursin("data-tab=", html)
                    if occursin("doc-tabs__label", html)
                        button_tabs += 1
                    elseif occursin("doc-tabs__panel", html)
                        panel_tabs += 1
                    end
                end
            end
        end
        
        @test button_tabs >= 2
        @test panel_tabs >= 2
    end
    
    @testset "Empty tabs admonition handling" begin
        md = md"""
!!! tabs "Empty"
    No headings here, just content.
        """
        
        # Should not crash, either transforms or leaves as-is
        ast = convert(Node, md)
        @test ast.element isa Document
    end

end

println("All tabs transformation tests completed!")
