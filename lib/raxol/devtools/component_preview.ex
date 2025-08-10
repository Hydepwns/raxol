defmodule Raxol.DevTools.ComponentPreview do
  @moduledoc """
  Interactive component preview and playground for Raxol UI components.

  This module provides a development environment for previewing, testing, and
  iterating on UI components in isolation. It offers:

  - Component isolation and preview
  - Interactive prop manipulation
  - Visual component browser
  - Example/story management
  - Responsive testing
  - Theme switching
  - Performance profiling

  ## Usage

      # Register component stories
      ComponentPreview.register_story(Button, "default", %{
        props: %{label: "Click me", variant: :primary},
        description: "Default button with primary styling"
      })
      
      # Start preview server
      ComponentPreview.start_server(port: 4001)
      
      # Generate preview for component
      ComponentPreview.preview_component(Button, %{
        label: "Test Button",
        on_click: fn -> IO.puts("Clicked!") end
      })
  """

  alias Raxol.UI.State.{Context, Hooks}
  alias Raxol.DevTools.PropsValidator
  require Logger

  defmodule Story do
    @enforce_keys [:component, :name, :props]
    defstruct [
      :component,
      :name,
      :props,
      :description,
      :category,
      :tags,
      :viewport,
      :theme,
      :interactive_props,
      :code_example
    ]

    def new(component, name, props, opts \\ []) do
      %__MODULE__{
        component: component,
        name: name,
        props: props,
        description: Keyword.get(opts, :description),
        category: Keyword.get(opts, :category, "General"),
        tags: Keyword.get(opts, :tags, []),
        viewport: Keyword.get(opts, :viewport),
        theme: Keyword.get(opts, :theme),
        interactive_props: Keyword.get(opts, :interactive_props, []),
        code_example: Keyword.get(opts, :code_example)
      }
    end
  end

  defmodule PreviewState do
    defstruct [
      :stories,
      :current_story,
      :prop_overrides,
      :viewport_size,
      :theme,
      :performance_mode,
      :server_pid
    ]

    def new do
      %__MODULE__{
        stories: %{},
        current_story: nil,
        prop_overrides: %{},
        viewport_size: {800, 600},
        theme: :light,
        performance_mode: false,
        server_pid: nil
      }
    end
  end

  # Global state for preview system
  @preview_agent :component_preview_state

  ## Public API

  @doc """
  Initializes the component preview system.
  """
  def init do
    Agent.start_link(fn -> PreviewState.new() end, name: @preview_agent)
  end

  @doc """
  Registers a component story for the preview system.

  ## Examples

      ComponentPreview.register_story(Button, "primary", %{
        label: "Primary Button",
        variant: :primary
      }, 
        description: "A primary action button",
        category: "Actions",
        interactive_props: [:label, :disabled]
      )
  """
  def register_story(component, story_name, props, opts \\ []) do
    story = Story.new(component, story_name, props, opts)
    story_key = {component, story_name}

    Agent.update(@preview_agent, fn state ->
      new_stories = Map.put(state.stories, story_key, story)
      %{state | stories: new_stories}
    end)

    Logger.info("Registered story: #{component}.#{story_name}")
    :ok
  end

  @doc """
  Gets all registered stories, optionally filtered by category or component.
  """
  def get_stories(filter \\ :all) do
    Agent.get(@preview_agent, fn state ->
      case filter do
        :all ->
          state.stories

        {:component, component} ->
          Enum.filter(state.stories, fn {{comp, _name}, _story} ->
            comp == component
          end)

        {:category, category} ->
          Enum.filter(state.stories, fn {_key, story} ->
            story.category == category
          end)

        {:tag, tag} ->
          Enum.filter(state.stories, fn {_key, story} -> tag in story.tags end)
      end
    end)
  end

  @doc """
  Sets the current story for preview.
  """
  def set_current_story(component, story_name) do
    story_key = {component, story_name}

    Agent.update(@preview_agent, fn state ->
      case Map.get(state.stories, story_key) do
        nil ->
          Logger.warning("Story not found: #{component}.#{story_name}")
          state

        story ->
          %{state | current_story: story, prop_overrides: %{}}
      end
    end)
  end

  @doc """
  Updates prop overrides for the current story.
  """
  def update_props(prop_overrides) when is_map(prop_overrides) do
    Agent.update(@preview_agent, fn state ->
      new_overrides = Map.merge(state.prop_overrides, prop_overrides)
      %{state | prop_overrides: new_overrides}
    end)
  end

  @doc """
  Sets the viewport size for responsive testing.
  """
  def set_viewport({width, height})
      when is_integer(width) and is_integer(height) do
    Agent.update(@preview_agent, fn state ->
      %{state | viewport_size: {width, height}}
    end)
  end

  @doc """
  Sets the preview theme.
  """
  def set_theme(theme) when theme in [:light, :dark, :auto] do
    Agent.update(@preview_agent, fn state ->
      %{state | theme: theme}
    end)
  end

  @doc """
  Renders the current story with current overrides.
  """
  def render_current_story do
    Agent.get(@preview_agent, fn state ->
      case state.current_story do
        nil ->
          %{type: :text, attrs: %{content: "No story selected"}}

        story ->
          merged_props = Map.merge(story.props, state.prop_overrides)
          render_story_with_wrapper(story, merged_props, state)
      end
    end)
  end

  @doc """
  Previews a component directly with given props.
  """
  def preview_component(component, props \\ %{}, opts \\ []) do
    viewport = Keyword.get(opts, :viewport, {800, 600})
    theme = Keyword.get(opts, :theme, :light)
    performance_mode = Keyword.get(opts, :performance, false)

    context = build_preview_context(theme, viewport, performance_mode)

    # Validate props if validation is available
    validated_props =
      case PropsValidator.validate_props(component, props) do
        {:ok, valid_props} -> valid_props
        # Use original props if validation fails
        {:error, _errors} -> props
      end

    # Render component with preview wrapper
    render_component_with_preview_wrapper(component, validated_props, context)
  end

  @doc """
  Generates a component gallery showing all stories.
  """
  def generate_gallery(opts \\ []) do
    stories = get_stories()
    columns = Keyword.get(opts, :columns, 3)
    theme = Keyword.get(opts, :theme, :light)

    # Group stories by category
    categories =
      stories
      |> Enum.group_by(fn {_key, story} -> story.category end)
      |> Enum.sort_by(fn {category, _stories} -> category end)

    %{
      type: :column,
      attrs: %{
        style: %{
          padding: 20,
          background: theme_background(theme),
          min_height: "100vh"
        }
      },
      children:
        [
          gallery_header(),
          gallery_controls(theme)
        ] ++
          Enum.flat_map(categories, fn {category, category_stories} ->
            [
              category_header(category),
              stories_grid(category_stories, columns, theme)
            ]
          end)
    }
  end

  @doc """
  Creates an interactive props panel for a component.
  """
  def create_props_panel(component, current_props) do
    case get_component_prop_schema(component) do
      nil ->
        simple_props_panel(current_props)

      schema ->
        interactive_props_panel(schema, current_props)
    end
  end

  @doc """
  Starts a development server for the component preview.
  """
  def start_server(opts \\ []) do
    port = Keyword.get(opts, :port, 4001)

    server_pid =
      spawn_link(fn ->
        preview_server_loop(port)
      end)

    Agent.update(@preview_agent, fn state ->
      %{state | server_pid: server_pid}
    end)

    Logger.info("Component preview server started on port #{port}")
    {:ok, server_pid}
  end

  @doc """
  Auto-discovers components and generates stories.
  """
  def auto_discover_components(paths \\ ["lib/raxol/ui/components/"]) do
    paths
    |> Enum.flat_map(&discover_components_in_path/1)
    |> Enum.each(&register_auto_story/1)
  end

  ## Private Implementation

  defp render_story_with_wrapper(story, props, state) do
    context =
      build_preview_context(
        state.theme,
        state.viewport_size,
        state.performance_mode
      )

    %{
      type: :column,
      attrs: %{
        style: %{
          width: elem(state.viewport_size, 0),
          height: elem(state.viewport_size, 1),
          padding: 20,
          background: theme_background(state.theme),
          border: "1px solid #e0e0e0"
        }
      },
      children: [
        story_header(story),
        component_wrapper(story.component, props, context),
        story_footer(story, props)
      ]
    }
  end

  defp render_component_with_preview_wrapper(component, props, context) do
    %{
      type: :column,
      attrs: %{gap: 10, padding: 20},
      children: [
        %{
          type: :text,
          attrs: %{
            content: "Preview: #{component}",
            style: %{font_size: 18, font_weight: :bold}
          }
        },
        component_wrapper(component, props, context),
        props_display(props)
      ]
    }
  end

  defp build_preview_context(theme, viewport, performance_mode) do
    base_context = %{
      theme: theme,
      viewport: viewport,
      preview_mode: true,
      performance_monitoring: performance_mode
    }

    # Add theme context
    Context.create_context(base_context, :preview_context)
  end

  defp component_wrapper(component, props, context) do
    %{
      type: :box,
      attrs: %{
        style: %{
          border: "2px dashed #ccc",
          border_radius: 4,
          padding: 15,
          background: "#fafafa"
        }
      },
      children: [
        try do
          cond do
            function_exported?(component, :render, 2) ->
              component.render(props, context)

            function_exported?(component, :component, 1) ->
              component.component(props)

            true ->
              error_component(
                "Component #{component} does not export render/2 or component/1"
              )
          end
        catch
          kind, reason ->
            error_component(
              "Error rendering #{component}: #{inspect(kind)} - #{inspect(reason)}"
            )
        end
      ]
    }
  end

  defp story_header(story) do
    %{
      type: :column,
      attrs: %{gap: 5, margin_bottom: 10},
      children:
        [
          %{
            type: :text,
            attrs: %{
              content: "#{story.component} - #{story.name}",
              style: %{font_size: 16, font_weight: :bold}
            }
          },
          if story.description do
            %{
              type: :text,
              attrs: %{
                content: story.description,
                style: %{font_size: 14, color: :secondary}
              }
            }
          end
        ]
        |> Enum.filter(&(&1 != nil))
    }
  end

  defp story_footer(story, props) do
    %{
      type: :column,
      attrs: %{gap: 10, margin_top: 15},
      children:
        [
          if story.code_example do
            code_example_section(story.code_example)
          end,
          props_display(props)
        ]
        |> Enum.filter(&(&1 != nil))
    }
  end

  defp props_display(props) do
    %{
      type: :column,
      attrs: %{gap: 5},
      children: [
        %{
          type: :text,
          attrs: %{
            content: "Props:",
            style: %{font_weight: :bold, font_size: 12}
          }
        },
        %{
          type: :text,
          attrs: %{
            content: inspect(props, pretty: true),
            style: %{
              font_family: :monospace,
              font_size: 10,
              background: "#f5f5f5",
              padding: 5,
              border_radius: 3
            }
          }
        }
      ]
    }
  end

  defp error_component(message) do
    %{
      type: :text,
      attrs: %{
        content: message,
        style: %{
          color: :error,
          font_weight: :bold,
          background: "#ffebee",
          padding: 10,
          border_radius: 4
        }
      }
    }
  end

  defp gallery_header do
    %{
      type: :text,
      attrs: %{
        content: "Component Gallery",
        style: %{
          font_size: 24,
          font_weight: :bold,
          margin_bottom: 20,
          text_align: :center
        }
      }
    }
  end

  defp gallery_controls(theme) do
    %{
      type: :row,
      attrs: %{gap: 10, margin_bottom: 30, justify_content: :center},
      children: [
        %{
          type: :button,
          attrs: %{
            label: if(theme == :light, do: "Dark", else: "Light"),
            on_click: fn ->
              set_theme(if theme == :light, do: :dark, else: :light)
            end
          }
        },
        viewport_selector(),
        %{
          type: :button,
          attrs: %{
            label: "Refresh",
            on_click: fn -> auto_discover_components() end
          }
        }
      ]
    }
  end

  defp category_header(category) do
    %{
      type: :text,
      attrs: %{
        content: category,
        style: %{
          font_size: 20,
          font_weight: :bold,
          margin: %{top: 30, bottom: 15},
          border_bottom: "2px solid #e0e0e0",
          padding_bottom: 5
        }
      }
    }
  end

  defp stories_grid(stories, columns, theme) do
    %{
      type: :row,
      attrs: %{
        wrap: true,
        gap: 20,
        margin_bottom: 30
      },
      children:
        stories
        |> Enum.map(fn {_key, story} ->
          story_card(story, theme)
        end)
        |> Enum.chunk_every(columns)
        |> List.flatten()
    }
  end

  defp story_card(story, theme) do
    %{
      type: :column,
      attrs: %{
        style: %{
          width: 250,
          border: "1px solid #e0e0e0",
          border_radius: 8,
          padding: 15,
          background: theme_card_background(theme),
          cursor: :pointer
        },
        on_click: fn -> set_current_story(story.component, story.name) end
      },
      children:
        [
          %{
            type: :text,
            attrs: %{
              content: "#{story.component}",
              style: %{font_weight: :bold, margin_bottom: 5}
            }
          },
          %{
            type: :text,
            attrs: %{
              content: story.name,
              style: %{font_size: 14, color: :primary, margin_bottom: 10}
            }
          },
          component_wrapper(
            story.component,
            story.props,
            build_preview_context(theme, {200, 100}, false)
          ),
          if story.description do
            %{
              type: :text,
              attrs: %{
                content: story.description,
                style: %{font_size: 12, color: :secondary, margin_top: 10}
              }
            }
          end
        ]
        |> Enum.filter(&(&1 != nil))
    }
  end

  defp viewport_selector do
    %{
      type: :select,
      attrs: %{
        options: [
          {"Mobile", {375, 667}},
          {"Tablet", {768, 1024}},
          {"Desktop", {1200, 800}},
          {"Custom", :custom}
        ],
        on_change: fn size -> set_viewport(size) end
      }
    }
  end

  defp simple_props_panel(props) do
    %{
      type: :column,
      attrs: %{gap: 10, padding: 15},
      children:
        [
          %{
            type: :text,
            attrs: %{
              content: "Props",
              style: %{font_weight: :bold}
            }
          }
        ] ++
          Enum.map(props, fn {key, value} ->
            prop_editor(key, value)
          end)
    }
  end

  defp interactive_props_panel(schema, current_props) do
    %{
      type: :column,
      attrs: %{gap: 15, padding: 15},
      children:
        [
          %{
            type: :text,
            attrs: %{
              content: "Interactive Props",
              style: %{font_weight: :bold}
            }
          }
        ] ++
          Enum.map(schema, fn {prop_name, prop_config} ->
            prop_interactive_editor(
              prop_name,
              prop_config,
              Map.get(current_props, prop_name)
            )
          end)
    }
  end

  defp prop_editor(key, value) do
    %{
      type: :row,
      attrs: %{gap: 10, align_items: :center},
      children: [
        %{
          type: :text,
          attrs: %{content: "#{key}:", style: %{min_width: 80}}
        },
        %{
          type: :text_input,
          attrs: %{
            value: inspect(value),
            on_change: fn new_value ->
              update_props(%{key => parse_value(new_value)})
            end
          }
        }
      ]
    }
  end

  defp prop_interactive_editor(prop_name, prop_config, current_value) do
    case prop_config[:type] do
      :boolean ->
        boolean_editor(prop_name, current_value)

      :string ->
        string_editor(prop_name, current_value, prop_config)

      :number ->
        number_editor(prop_name, current_value, prop_config)

      :select ->
        select_editor(prop_name, current_value, prop_config)

      _ ->
        prop_editor(prop_name, current_value)
    end
  end

  defp boolean_editor(prop_name, current_value) do
    %{
      type: :row,
      attrs: %{gap: 10, align_items: :center},
      children: [
        %{
          type: :text,
          attrs: %{content: "#{prop_name}:", style: %{min_width: 100}}
        },
        %{
          type: :checkbox,
          attrs: %{
            checked: !!current_value,
            on_change: fn checked ->
              update_props(%{prop_name => checked})
            end
          }
        }
      ]
    }
  end

  defp string_editor(prop_name, current_value, _config) do
    %{
      type: :column,
      attrs: %{gap: 5},
      children: [
        %{
          type: :text,
          attrs: %{content: "#{prop_name}:"}
        },
        %{
          type: :text_input,
          attrs: %{
            value: to_string(current_value || ""),
            on_change: fn new_value ->
              update_props(%{prop_name => new_value})
            end
          }
        }
      ]
    }
  end

  defp number_editor(prop_name, current_value, config) do
    min_val = config[:min] || 0
    max_val = config[:max] || 100

    %{
      type: :column,
      attrs: %{gap: 5},
      children: [
        %{
          type: :text,
          attrs: %{content: "#{prop_name}:"}
        },
        %{
          type: :slider,
          attrs: %{
            value: current_value || min_val,
            min: min_val,
            max: max_val,
            on_change: fn new_value ->
              update_props(%{prop_name => new_value})
            end
          }
        }
      ]
    }
  end

  defp select_editor(prop_name, current_value, config) do
    options = config[:options] || []

    %{
      type: :column,
      attrs: %{gap: 5},
      children: [
        %{
          type: :text,
          attrs: %{content: "#{prop_name}:"}
        },
        %{
          type: :select,
          attrs: %{
            value: current_value,
            options: options,
            on_change: fn new_value ->
              update_props(%{prop_name => new_value})
            end
          }
        }
      ]
    }
  end

  defp code_example_section(code) do
    %{
      type: :column,
      attrs: %{gap: 5},
      children: [
        %{
          type: :text,
          attrs: %{
            content: "Code Example:",
            style: %{font_weight: :bold, font_size: 12}
          }
        },
        %{
          type: :text,
          attrs: %{
            content: code,
            style: %{
              font_family: :monospace,
              font_size: 11,
              background: "#2d2d2d",
              color: "#f8f8f8",
              padding: 10,
              border_radius: 4
            }
          }
        }
      ]
    }
  end

  defp discover_components_in_path(path) do
    Path.wildcard(Path.join(path, "**/*.ex"))
    |> Enum.map(&extract_component_from_file/1)
    |> Enum.filter(&(&1 != nil))
  end

  defp extract_component_from_file(file_path) do
    try do
      content = File.read!(file_path)

      # Simple pattern matching for component modules
      case Regex.run(~r/defmodule\s+([\w\.]+).*?do/, content) do
        [_, module_name] ->
          module = Module.concat([module_name])

          if Code.ensure_loaded?(module) and is_component_module?(module) do
            module
          else
            nil
          end

        _ ->
          nil
      end
    catch
      _, _ -> nil
    end
  end

  defp is_component_module?(module) do
    try do
      functions = module.__info__(:functions)

      Enum.any?(functions, fn {func, arity} ->
        func in [:render, :component] and arity in [1, 2]
      end)
    catch
      _, _ -> false
    end
  end

  defp register_auto_story(component) do
    # Generate a basic story for discovered components
    register_story(component, "default", %{},
      description: "Auto-generated story for #{component}",
      category: "Auto-discovered"
    )
  end

  defp get_component_prop_schema(component) do
    try do
      if function_exported?(component, :__props__, 0) do
        component.__props__()
      else
        nil
      end
    catch
      _, _ -> nil
    end
  end

  defp parse_value(string_value) do
    try do
      {value, _} = Code.eval_string(string_value)
      value
    catch
      _, _ -> string_value
    end
  end

  defp theme_background(:light), do: "#ffffff"
  defp theme_background(:dark), do: "#1e1e1e"
  defp theme_background(_), do: "#ffffff"

  defp theme_card_background(:light), do: "#fafafa"
  defp theme_card_background(:dark), do: "#2d2d2d"
  defp theme_card_background(_), do: "#fafafa"

  defp preview_server_loop(port) do
    # Simplified HTTP server for component preview
    # In real implementation, would use Plug/Cowboy
    :timer.sleep(1000)
    Logger.debug("Preview server running on port #{port}")
    preview_server_loop(port)
  end
end
