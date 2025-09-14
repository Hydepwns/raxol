defmodule Raxol.Docs.FormatterTest do
  @moduledoc """
  Tests for the documentation formatter used in command palette and interactive docs.
  """
  use ExUnit.Case, async: true

  alias Raxol.Docs.Formatter

  describe "function documentation formatting" do
    test "formats function docs with English content" do
      doc_content = %{"en" => "This function does something useful.\n\nMore details here."}
      
      result = Formatter.format_function_docs(MyModule, :my_function, 2, doc_content)
      
      assert String.contains?(result, "MyModule.my_function/2")
      assert String.contains?(result, "This function does something useful.")
      assert String.contains?(result, "More details here.")
      assert String.contains?(result, "═")  # Header border
      assert String.contains?(result, "─")  # Section divider
    end
    
    test "formats function docs with missing English content" do
      doc_content = %{"de" => "German documentation"}
      
      result = Formatter.format_function_docs(TestModule, :test_func, 1, doc_content)
      
      assert String.contains?(result, "TestModule.test_func/1")
      assert String.contains?(result, "No documentation available")
      assert String.contains?(result, "Use h(TestModule.test_func) in IEx")
    end
    
    test "formats function docs with nil content" do
      result = Formatter.format_function_docs(SomeModule, :some_func, 0, nil)
      
      assert String.contains?(result, "SomeModule.some_func/0")
      assert String.contains?(result, "No documentation available")
    end
    
    test "formats function docs with empty content" do
      result = Formatter.format_function_docs(EmptyModule, :empty_func, 3, %{})
      
      assert String.contains?(result, "EmptyModule.empty_func/3")
      assert String.contains?(result, "No documentation available")
    end
    
    test "extracts and formats examples from documentation" do
      doc_with_examples = %{
        "en" => """
        This function processes data.
        
        ## Examples
        
        ```elixir
        iex> MyModule.process([1, 2, 3])
        {:ok, [2, 4, 6]}
        ```
        
        Another example:
        
        ```
        MyModule.process([])
        # => {:ok, []}
        ```
        """
      }
      
      result = Formatter.format_function_docs(MyModule, :process, 1, doc_with_examples)
      
      assert String.contains?(result, "Examples:")
      assert String.contains?(result, "iex> MyModule.process([1, 2, 3])")
      assert String.contains?(result, "{:ok, [2, 4, 6]}")
      assert String.contains?(result, "```elixir")
    end
  end

  describe "API reference formatting" do
    test "formats module reference for atom input" do
      result = Formatter.format_api_reference(String)
      
      assert String.contains?(result, "Module: String")
      assert String.contains?(result, "═")  # Header formatting
    end
    
    test "formats topic reference for string input" do
      result = Formatter.format_api_reference("ui")
      
      assert String.contains?(result, "Ui API Reference")
      assert String.contains?(result, "Raxol.UI module")
      assert String.contains?(result, "Multi-framework support")
    end
    
    test "formats terminal topic reference" do
      result = Formatter.format_api_reference("terminal")
      
      assert String.contains?(result, "Terminal API Reference")
      assert String.contains?(result, "ANSI/VT100 compatible")
      assert String.contains?(result, "Raxol.Terminal.Emulator")
    end
    
    test "formats components topic reference" do
      result = Formatter.format_api_reference("components")
      
      assert String.contains?(result, "Components API Reference")
      assert String.contains?(result, "Built-in component library")
      assert String.contains?(result, "Button - Interactive buttons")
    end
    
    test "formats unknown topic reference" do
      result = Formatter.format_api_reference("unknown_topic")
      
      assert String.contains?(result, "Unknown_topic API Reference")
      assert String.contains?(result, "Reference documentation for unknown_topic not available")
    end
  end

  describe "example formatting" do
    test "formats example with ID and content" do
      example_content = """
      This is an example of how to use the feature.
      
      ```elixir
      use Raxol.UI
      
      def render do
        "Hello World"
      end
      ```
      """
      
      result = Formatter.format_example("basic_usage", example_content)
      
      assert String.contains?(result, "Example: basic_usage")
      assert String.contains?(result, "This is an example")
      assert String.contains?(result, "```elixir")
      assert String.contains?(result, "use Raxol.UI")
      assert String.contains?(result, "─")  # Section divider
    end
    
    test "formats empty example content" do
      result = Formatter.format_example("empty_example", "")
      
      assert String.contains?(result, "Example: empty_example")
      assert String.contains?(result, "─")
    end
  end

  describe "guide formatting" do
    test "formats guide with underscore ID transformation" do
      guide_content = "This is a comprehensive guide about terminal usage."
      
      result = Formatter.format_guide("terminal_usage", guide_content)
      
      assert String.contains?(result, "Guide: Terminal usage")
      assert String.contains?(result, "This is a comprehensive guide")
    end
    
    test "formats guide with multiple underscores" do
      guide_content = "Advanced component development patterns."
      
      result = Formatter.format_guide("advanced_component_development", guide_content)
      
      assert String.contains?(result, "Guide: Advanced component development")
      assert String.contains?(result, "Advanced component development patterns")
    end
    
    test "formats guide with empty content" do
      result = Formatter.format_guide("empty_guide", "")
      
      assert String.contains?(result, "Guide: Empty guide")
    end
  end

  describe "search results formatting" do
    test "formats multiple search results with different scores" do
      results = [
        %{
          title: "High Score Result",
          description: "This matches very well",
          category: :function,
          score: 0.9
        },
        %{
          title: "Medium Score Result", 
          description: "This is a decent match",
          category: :module,
          score: 0.7
        },
        %{
          title: "Low Score Result",
          description: "This barely matches",
          category: :guide,
          score: 0.3
        }
      ]
      
      result = Formatter.format_search_results(results, "test query")
      
      assert String.contains?(result, "Search Results for \"test query\"")
      assert String.contains?(result, "🎯")  # High score indicator
      assert String.contains?(result, "✅")  # Medium score indicator  
      assert String.contains?(result, "💡")  # Low score indicator
      assert String.contains?(result, "[FUNCTION]")
      assert String.contains?(result, "[MODULE]")
      assert String.contains?(result, "[GUIDE]")
      # Use regex patterns to handle ANSI formatting codes - match across ANSI escapes
      assert result =~ ~r/1\..*High Score Result/
      assert result =~ ~r/2\..*Medium Score Result/
      assert result =~ ~r/3\..*Low Score Result/
    end
    
    test "formats empty search results" do
      result = Formatter.format_search_results([], "empty query")
      
      assert String.contains?(result, "Search Results for \"empty query\"")
      assert String.contains?(result, "─")
    end
    
    test "formats search results with edge case scores" do
      results = [
        %{title: "Perfect Match", description: "Exact match", category: :function, score: 1.0},
        %{title: "Good Match", description: "Almost there", category: :module, score: 0.8},
        %{title: "OK Match", description: "Borderline", category: :guide, score: 0.6},
        %{title: "Fair Match", description: "Acceptable", category: :example, score: 0.4},
        %{title: "Poor Match", description: "Barely relevant", category: :other, score: 0.1}
      ]
      
      result = Formatter.format_search_results(results, "edge cases")
      
      # Test all score indicators are present
      assert String.contains?(result, "🎯")  # score > 0.8
      assert String.contains?(result, "✅")  # score > 0.6  
      assert String.contains?(result, "⚡")  # score > 0.4
      assert String.contains?(result, "💡")  # score <= 0.4
    end
  end

  describe "component preview formatting" do
    test "formats component with properties and example" do
      component = %{
        name: "Button",
        description: "An interactive button component",
        properties: %{
          text: %{type: "string", default: "Click me"},
          variant: %{type: "atom", default: :primary},
          disabled: %{type: "boolean", default: false}
        },
        example_code: """
        <Button text="%PROPS%" variant={:secondary}>
          Custom button
        </Button>
        """
      }
      
      props = %{text: "Custom Text", variant: :secondary}
      
      result = Formatter.format_component_preview(component, props)
      
      assert String.contains?(result, "Component: Button")
      assert String.contains?(result, "An interactive button component")
      assert String.contains?(result, "Properties:")
      # Use regex patterns to handle ANSI formatting and property ordering
      assert result =~ ~r/text.*string.*Custom Text/
      assert result =~ ~r/variant.*atom.*:secondary/
      assert result =~ ~r/disabled.*boolean.*false/
      assert String.contains?(result, "Example:")
      assert String.contains?(result, "```elixir")
      assert String.contains?(result, "Custom button")
    end
    
    test "formats component without properties" do
      component = %{
        name: "SimpleComponent",
        description: "A component without properties"
      }
      
      result = Formatter.format_component_preview(component)
      
      assert String.contains?(result, "Component: SimpleComponent")
      assert String.contains?(result, "A component without properties")
      refute String.contains?(result, "Properties:")
      refute String.contains?(result, "Example:")
    end
    
    test "formats component without example code" do
      component = %{
        name: "NoExampleComponent",
        description: "No example provided",
        properties: %{
          value: %{type: "any", default: nil}
        }
      }
      
      result = Formatter.format_component_preview(component)
      
      assert String.contains?(result, "Properties:")
      assert result =~ ~r/value.*any.*nil/
      refute String.contains?(result, "Example:")
    end
  end

  describe "text processing and formatting" do
    test "processes markdown-style formatting in doc text" do
      # This tests the private format_doc_text function indirectly
      doc_content = %{
        "en" => """
        This function uses `code blocks`, **bold text**, and *italic text*.
        
        More content with `another code` reference.
        """
      }
      
      result = Formatter.format_function_docs(TestModule, :test, 1, doc_content)
      
      # Check that ANSI escape codes are present (indicating formatting was applied)
      assert String.contains?(result, IO.ANSI.yellow())    # Code formatting
      assert String.contains?(result, IO.ANSI.bright())    # Bold formatting  
      assert String.contains?(result, IO.ANSI.italic())    # Italic formatting
      assert String.contains?(result, IO.ANSI.reset())     # Reset codes
    end
    
    test "extracts summary and rest content correctly" do
      doc_content = %{
        "en" => """
        This is the first paragraph summary.
        It continues on this line.
        
        This is the second paragraph with more details.
        And additional information here.
        
        Final paragraph.
        """
      }
      
      result = Formatter.format_function_docs(TestModule, :test, 1, doc_content)
      
      # Both summary and rest should be present in output
      assert String.contains?(result, "This is the first paragraph summary")
      assert String.contains?(result, "This is the second paragraph with more details")
      assert String.contains?(result, "Final paragraph")
    end
  end

  describe "terminal formatting helpers" do
    test "header creates bordered box" do
      # Testing via component preview which uses header
      component = %{name: "TestComponent", description: "Test"}
      result = Formatter.format_component_preview(component)
      
      assert String.contains?(result, "╔")  # Top-left corner
      assert String.contains?(result, "╗")  # Top-right corner  
      assert String.contains?(result, "╚")  # Bottom-left corner
      assert String.contains?(result, "╝")  # Bottom-right corner
      assert String.contains?(result, "═")  # Horizontal border
      assert String.contains?(result, "║")  # Vertical border
    end
    
    test "section divider creates line" do
      result = Formatter.format_example("test", "content")
      
      assert String.contains?(result, String.duplicate("─", 60))
      assert String.contains?(result, IO.ANSI.light_black())
    end
  end

  describe "error handling and edge cases" do
    test "handles modules that cannot be introspected" do
      # Test with a non-existent module atom
      result = Formatter.format_api_reference(:NonExistentModule)
      
      # Module is formatted with inspect(), so it shows as :NonExistentModule
      assert result =~ ~r/Module:.*NonExistentModule/
      # Should handle gracefully without crashing
      assert is_binary(result)
    end
    
    test "handles function documentation extraction failures gracefully" do
      # Test basic function info when specs cannot be fetched
      result = Formatter.format_function_docs(NonExistentModule, :func, 1, nil)
      
      assert String.contains?(result, "NonExistentModule.func/1")
      assert String.contains?(result, "No documentation available")
    end
    
    test "formats typespec correctly" do
      # This tests the format_typespec function indirectly
      # Since it's simple (just inspect), we verify it doesn't crash
      doc_content = %{"en" => "Simple function"}
      result = Formatter.format_function_docs(String, :length, 1, doc_content)
      
      # Should not crash and should produce valid output
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  describe "arithmetic and boolean operations for mutation testing" do
    test "string length calculations in formatting" do
      # Test arithmetic in header width calculation
      component = %{name: "A", description: "Short"}
      result = Formatter.format_component_preview(component)
      
      # Header should be calculated as text length + 4, not - 4
      assert String.contains?(result, "Component: A")
      assert String.contains?(result, "═══════════")  # Should be correct length
    end
    
    test "index arithmetic in search results" do
      results = [
        %{title: "First", description: "Test", category: :function, score: 0.9},
        %{title: "Second", description: "Test", category: :module, score: 0.8}
      ]
      
      result = Formatter.format_search_results(results, "test")
      
      # Indices should be 1-based (index + 1), not 0-based
      assert result =~ ~r/1\..*First/
      assert result =~ ~r/2\..*Second/
      refute String.contains?(result, "0. First")
    end
    
    test "score comparison logic in search result indicators" do
      # Test different score ranges for correct boolean comparisons
      test_cases = [
        {0.9, "🎯"},   # > 0.8, not <= 0.8
        {0.7, "✅"},   # > 0.6, not <= 0.6
        {0.5, "⚡"},   # > 0.4, not <= 0.4
        {0.2, "💡"}    # <= 0.4, not > 0.4
      ]
      
      for {score, expected_indicator} <- test_cases do
        results = [%{title: "Test", description: "Test", category: :test, score: score}]
        result = Formatter.format_search_results(results, "test")
        assert String.contains?(result, expected_indicator)
      end
    end
    
    test "boolean logic in conditional formatting" do
      # Test conditions with logical operators
      component_with_props = %{
        name: "TestComponent",
        description: "Test",
        properties: %{test: %{type: "string", default: "test"}}
      }
      
      component_without_props = %{
        name: "TestComponent", 
        description: "Test"
      }
      
      # Component WITH properties should show Properties section
      result_with = Formatter.format_component_preview(component_with_props)
      assert String.contains?(result_with, "Properties:")  # properties != nil AND not empty
      
      # Component WITHOUT properties should NOT show Properties section  
      result_without = Formatter.format_component_preview(component_without_props)
      refute String.contains?(result_without, "Properties:")  # properties == nil OR empty
    end
    
    test "string operations and comparisons" do
      # Test string equality vs inequality
      doc_content = %{"en" => "Test content"}
      result = Formatter.format_function_docs(TestModule, :test, 1, doc_content)
      
      # Should format when content == "Test content", not != "Test content"
      assert String.contains?(result, "Test content")
      
      # Test empty string vs non-empty comparisons
      empty_result = Formatter.format_example("test", "")
      non_empty_result = Formatter.format_example("test", "content")
      
      # Both should contain example header (regardless of content == "" or != "")
      assert String.contains?(empty_result, "Example: test")
      assert String.contains?(non_empty_result, "Example: test")
      assert String.contains?(non_empty_result, "content")
    end
    
    test "list operations and enumeration" do
      # Test list length and enumeration operations
      results = [
        %{title: "Item 1", description: "First", category: :test, score: 0.5},
        %{title: "Item 2", description: "Second", category: :test, score: 0.6},
        %{title: "Item 3", description: "Third", category: :test, score: 0.7}
      ]
      
      result = Formatter.format_search_results(results, "test")
      
      # Should enumerate all items (length == 3, not != 3)
      assert result =~ ~r/1\..*Item 1/
      assert result =~ ~r/2\..*Item 2/
      assert result =~ ~r/3\..*Item 3/
      
      # Test empty list handling (length == 0, not > 0)
      empty_result = Formatter.format_search_results([], "test")
      refute String.contains?(empty_result, "1.")  # No items should be listed
    end
  end
end