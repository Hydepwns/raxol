defmodule Raxol.Docs.ComponentCatalog do
  import Raxol.Guards

  @moduledoc """
  Visual component catalog for Raxol documentation.

  This module provides a comprehensive catalog of all UI components
  available in Raxol, with visual examples, code snippets, and interactive
  customization capabilities.

  Features:
  * Categorized components listing
  * Live examples with code snippets
  * Interactive property customization
  * Accessibility information
  * Related components suggestions
  * Search functionality
  """

  # Ensure all component source modules are located under `lib/raxol/ui/components/`
  # and are correctly referenced by the catalog data in `lib/raxol/docs/catalog_data/`.
  # (Original concern about `lib/raxol/components/` seems resolved as this path is not actively used).

  # Component category
  defmodule Category do
    @moduledoc false
    defstruct [
      :id,
      :name,
      :description,
      :components
    ]
  end

  # Component entry
  defmodule Component do
    @moduledoc false
    defstruct [
      :id,
      :name,
      :module,
      :description,
      :examples,
      :properties,
      :accessibility,
      :related_components,
      :tags,
      :metadata
    ]
  end

  # Component example
  defmodule Example do
    @moduledoc false
    defstruct [
      :id,
      :title,
      :description,
      :code,
      :preview_fn,
      :customizable_props
    ]
  end

  # Property definition
  defmodule Property do
    @moduledoc false
    defstruct [
      :name,
      :type,
      :description,
      :default_value,
      :required,
      :options,
      :examples
    ]
  end

  # Process dictionary key for catalog state
  @catalog_key :raxol_component_catalog

  # Import the DSL elements

  @doc """
  Initializes the component catalog.
  """
  def init do
    catalog = build_catalog()
    Process.put(@catalog_key, catalog)
    :ok
  end

  @doc """
  Lists all component categories.
  """
  def list_categories do
    catalog = get_catalog()
    Map.values(catalog)
  end

  @doc """
  Gets a specific category by ID.
  """
  def get_category(category_id) do
    catalog = get_catalog()
    Map.get(catalog, category_id)
  end

  @doc """
  Lists all components in a specific category.
  """
  def list_components(category_id) do
    catalog = get_catalog()

    case Map.get(catalog, category_id) do
      nil -> []
      category -> category.components
    end
  end

  @doc """
  Gets a specific component by ID.
  """
  def get_component(component_id) do
    catalog = get_catalog()

    Enum.find_value(catalog, fn {_, category} ->
      Enum.find(category.components, fn component ->
        component.id == component_id
      end)
    end)
  end

  @doc """
  Searches for components based on a query.
  """
  def search(query) do
    catalog = get_catalog()
    query_downcase = String.downcase(query)

    Enum.flat_map(catalog, fn {_, category} ->
      Enum.filter(category.components, fn component ->
        String.contains?(String.downcase(component.name), query_downcase) ||
          String.contains?(
            String.downcase(component.description),
            query_downcase
          ) ||
          tag_matches?(component, query_downcase)
      end)
    end)
  end

  defp tag_matches?(component, query_downcase) do
    Enum.any?(Map.get(component, :tags, []), fn tag ->
      String.contains?(String.downcase(tag), query_downcase)
    end)
  end

  @doc """
  Renders a component example.
  """
  def render_example(component_id, example_id, custom_props \\ %{}) do
    component = get_component(component_id)

    if component do
      example =
        Enum.find(component.examples, fn example ->
          example.id == example_id
        end)

      if example do
        # Call the preview function with custom props
        example.preview_fn.(custom_props)
      else
        {:error, "Example not found"}
      end
    else
      {:error, "Component not found"}
    end
  end

  @doc """
  Gets usage statistics for components.
  """
  def get_usage_stats do
    # This would typically be gathered from actual usage data
    %{
      most_used: [
        "button",
        "panel",
        "text_input",
        "dropdown",
        "table"
      ],
      recently_added: [
        "color_picker",
        "accordion",
        "progress_bar",
        "tabs",
        "toast"
      ],
      trending: [
        "card",
        "sidebar",
        "form",
        "modal",
        "menu"
      ]
    }
  end

  @doc """
  Generates code snippets for a component with the given properties.
  """
  def generate_code_snippet(component_id, props \\ %{}) do
    component = get_component(component_id)

    if component do
      props_str = build_props_str(props)
      main_arg = get_main_arg(props)
      dsl_call = build_dsl_call(component.id, main_arg, props_str)

      """
      view do
        #{dsl_call}
      end
      """
    else
      {:error, "Component not found"}
    end
  end

  @doc """
  Gets accessibility information for a component.
  """
  def get_accessibility_info(component_id) do
    component = get_component(component_id)

    if component do
      component.accessibility
    else
      {:error, "Component not found"}
    end
  end

  @doc """
  Suggests related components.
  """
  def suggest_related_components(component_id) do
    component = get_component(component_id)

    if component do
      # Get the related component IDs
      related_ids = component.related_components

      # Fetch the actual components
      related_ids
      |> Enum.map(&get_component/1)
      |> Enum.reject(&nil?/1)
    else
      []
    end
  end

  # Private helpers

  defp get_catalog do
    Process.get(@catalog_key) || build_catalog()
  end

  defp build_catalog do
    component_files = get_component_files()
    loaded_components = load_and_enrich_components(component_files)
    components_by_category = group_components_by_category(loaded_components)
    build_final_catalog_map(components_by_category)
  end

  defp get_component_files do
    catalog_data_path = Path.join(__DIR__, "catalog_data")
    Path.wildcard(Path.join(catalog_data_path, "*/*.exs"))
  end

  defp load_and_enrich_components(component_files) do
    Enum.map(component_files, fn file_path ->
      case Code.eval_file(file_path) do
        {static_component_data, _binding} ->
          # Attempt Introspection
          module = static_component_data.module
          introspected_data = fetch_introspected_data(module)

          # Extract descriptions from constructor docstring if possible
          constructor_doc = find_constructor_doc(introspected_data.fun_docs)

          prop_descriptions_from_doc =
            parse_prop_descriptions(constructor_doc)

          # Enrich static properties with introspected descriptions
          enriched_properties =
            enrich_properties(
              static_component_data.properties,
              prop_descriptions_from_doc
            )

          # Merge top-level description (prefer introspected moduledoc)
          merged_description =
            introspected_data.description || static_component_data.description

          # Build final component data, prioritizing static data except for enriched fields
          final_component_data =
            static_component_data
            |> Map.put(:description, merged_description)
            |> Map.put(:properties, enriched_properties)

          # Extract category name from directory path
          category_id =
            file_path
            |> Path.dirname()
            |> Path.basename()

          {category_id, final_component_data}
      end
    end)
  end

  defp group_components_by_category(loaded_components) do
    Enum.group_by(
      loaded_components,
      fn {category_id, _component} -> category_id end,
      fn {_category_id, component} -> component end
    )
  end

  defp build_final_catalog_map(components_by_category) do
    # Define category metadata (could also be loaded from files)
    category_definitions = %{
      "basic" => %{
        name: "Basic Components",
        description: "Fundamental UI components for building interfaces"
      },
      "layout" => %{
        name: "Layout Components",
        description: "Components for structuring and organizing content"
      },
      "display" => %{
        name: "Display Components",
        description: "Components for presenting data and information"
      }
      # Add more category definitions as needed
    }

    # Build the final catalog map
    category_definitions
    |> Map.new(fn {id, meta} ->
      components = Map.get(components_by_category, id, [])
      # Optionally sort components within category here
      # components = Enum.sort_by(components, & &1.name)

      category_struct = %Category{
        id: id,
        name: meta.name,
        description: meta.description,
        components: components
      }

      {id, category_struct}
    end)
  end

  # --- Introspection Helpers ---

  # Find the doc entry for the 'new/1' or similar constructor function
  defp find_constructor_doc(fun_docs) do
    Enum.find(fun_docs, fn {{_kind, name, arity}, _line, _sigs, _doc_map, _meta} ->
      # Look for 'new' with arity 0 or 1, common conventions
      name == :new && (arity == 0 || arity == 1)
    end)
  end

  # Simple parser for ## Options style docstrings (adjust regex as needed)
  # Example: "* `:label` - Text to display on the button"
  defp parse_prop_descriptions(nil), do: %{}

  defp parse_prop_descriptions({_, _line, _sigs, %{"en" => docstring}, _meta})
       when binary?(docstring) do
    Regex.scan(~r/^\s*\*\s*`:(?<name>\w+)`\s*-\s*(?<desc>.*)$/m, docstring)
    |> Enum.reduce(%{}, fn [_, name, desc], acc ->
      Map.put(acc, String.to_atom(name), String.trim(desc))
    end)
  end

  defp parse_prop_descriptions(_), do: %{}

  # Enrich properties from .exs with descriptions found via introspection
  defp enrich_properties(static_properties, introspected_descs) do
    Enum.map(
      static_properties,
      fn prop = %Raxol.Docs.ComponentCatalog.Property{} ->
        # Prefer introspected description if found and static one is missing/generic
        introspected_desc = Map.get(introspected_descs, prop.name)

        if introspected_desc &&
             (nil?(prop.description) || prop.description == "") do
          %{prop | description: introspected_desc}
        else
          # Keep the static property data
          prop
        end
      end
    )
  end

  # Helper to fetch introspectable data from a module
  defp fetch_introspected_data(module) when atom?(module) do
    # Ensure the module is loaded before fetching docs
    Code.ensure_loaded?(module)

    case Code.fetch_docs(module) do
      {:docs_v1, _annotation, _beam_language, _format, module_doc_map, _meta,
       docs} ->
        moduledoc = Map.get(module_doc_map, "en")
        # Extract function docs (focusing on :function type for now)
        fun_docs =
          Enum.filter(docs, fn {{kind, _name, _arity}, _line, _signatures,
                                _doc_map, _meta} ->
            kind == :function
          end)

        %{description: moduledoc, fun_docs: fun_docs}

      _ ->
        # Module not found or no docs available
        %{}
    end
  end

  defp fetch_introspected_data(_), do: %{}

  defp build_props_str(props) do
    Enum.map_join(props, ", ", fn {key, value} ->
      ":#{key}: #{inspect(value)}"
    end)
  end

  defp get_main_arg(props) do
    case props do
      %{content: content} -> content
      %{text: text} -> text
      %{label: label} -> label
      _ -> nil
    end
  end

  defp build_dsl_call(id, main_arg, props_str) do
    case main_arg do
      nil -> "#{id}(#{props_str})"
      arg -> "#{id}(#{inspect(arg)}, #{props_str})"
    end
  end
end
