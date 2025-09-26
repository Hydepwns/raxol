defmodule Raxol.Test.VisualizationTestData do
  @moduledoc """
  Provides test data for visualization edge cases to be used in testing.
  """

  @doc """
  Returns test data for bar charts with various edge cases.
  """
  def bar_chart_test_data do
    %{
      # Basic normal chart data
      normal: [
        %{label: "Item 1", value: 25},
        %{label: "Item 2", value: 40},
        %{label: "Item 3", value: 15},
        %{label: "Item 4", value: 35}
      ],

      # Empty dataset
      empty: [],

      # Single item dataset
      single_item: [
        %{label: "Only Item", value: 50}
      ],

      # Very large dataset (100+ items)
      large_dataset:
        Enum.map(1..100, fn i ->
          %{label: "Item #{i}", value: :rand.uniform(100)}
        end),

      # Dataset with very long labels
      long_labels: [
        %{
          label:
            "This is an extremely long label that should test text truncation capabilities",
          value: 30
        },
        %{
          label:
            "Another very long label that goes beyond reasonable display width in terminals",
          value: 45
        },
        %{label: "Short", value: 20},
        %{label: String.duplicate("Very long repeating text. ", 10), value: 60}
      ],

      # Dataset with unicode and emoji
      unicode_labels: [
        %{label: "[>] Rocket", value: 75},
        %{label: "[~] Rainbow", value: 45},
        %{label: "[*] Star [*] Star", value: 30},
        %{label: "Café München", value: 60}
      ],

      # Dataset with negative values
      negative_values: [
        %{label: "Profit Q1", value: 30},
        %{label: "Loss Q2", value: -20},
        %{label: "Profit Q3", value: 15},
        %{label: "Loss Q4", value: -40}
      ],

      # Dataset with zero values
      zero_values: [
        %{label: "Zero", value: 0},
        %{label: "Positive", value: 50},
        %{label: "Another Zero", value: 0},
        %{label: "Another Positive", value: 25}
      ],

      # Dataset with very large values
      large_values: [
        %{label: "Millions", value: 2_000_000},
        %{label: "Billions", value: 5_000_000_000},
        %{label: "Thousands", value: 50_000},
        %{label: "Normal", value: 100}
      ],

      # Dataset with very small values
      small_values: [
        %{label: "Tiny", value: 0.0001},
        %{label: "Very Small", value: 0.005},
        %{label: "Small", value: 0.1},
        %{label: "Normal", value: 10}
      ],

      # Dataset with all identical values
      identical_values: [
        %{label: "Same 1", value: 50},
        %{label: "Same 2", value: 50},
        %{label: "Same 3", value: 50},
        %{label: "Same 4", value: 50}
      ]
    }
  end

  @doc """
  Returns test data for treemaps with various edge cases.
  """
  def treemap_test_data do
    %{
      # Basic normal treemap data
      normal: %{
        name: "Root",
        value: 100,
        children: [
          %{
            name: "Group A",
            value: 40,
            children: [
              %{name: "A1", value: 25},
              %{name: "A2", value: 15}
            ]
          },
          %{
            name: "Group B",
            value: 60,
            children: [
              %{name: "B1", value: 30},
              %{name: "B2", value: 30}
            ]
          }
        ]
      },

      # Empty treemap
      empty: %{
        name: "Empty Root",
        value: 0,
        children: []
      },

      # Single node treemap
      single_node: %{
        name: "Single Node",
        value: 100,
        children: []
      },

      # Deep nesting (5+ levels)
      deep_nesting: %{
        name: "Level 1",
        value: 100,
        children: [
          %{
            name: "Level 2",
            value: 100,
            children: [
              %{
                name: "Level 3",
                value: 100,
                children: [
                  %{
                    name: "Level 4",
                    value: 100,
                    children: [
                      %{
                        name: "Level 5",
                        value: 100,
                        children: [
                          %{name: "Level 6", value: 100}
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },

      # Many siblings (breadth)
      many_siblings: %{
        name: "Root",
        value: 100,
        children:
          Enum.map(1..20, fn i ->
            %{name: "Child #{i}", value: 5}
          end)
      },

      # Uneven distribution (few large, many small)
      uneven_distribution: %{
        name: "Root",
        value: 100,
        children:
          [
            %{name: "Large A", value: 40},
            %{name: "Large B", value: 30}
          ] ++
            Enum.map(1..15, fn i ->
              %{name: "Tiny #{i}", value: 2}
            end)
      },

      # Unicode and emoji names
      unicode_names: %{
        name: "[WORLD] World",
        value: 100,
        children: [
          %{
            name: "🌎 Americas",
            value: 40,
            children: [
              %{name: "🇺🇸 USA", value: 25},
              %{name: "🇨🇦 Canada", value: 15}
            ]
          },
          %{
            name: "🌏 Asia",
            value: 60,
            children: [
              %{name: "🇯🇵 Japan", value: 30},
              %{name: "🇨🇳 China", value: 30}
            ]
          }
        ]
      },

      # Zero-value nodes
      zero_values: %{
        name: "Root",
        value: 100,
        children: [
          %{name: "Normal", value: 50},
          %{
            name: "Zero",
            value: 0,
            children: [
              %{name: "Child of Zero", value: 0}
            ]
          },
          %{name: "Another Normal", value: 50}
        ]
      },

      # Large dataset with mixed depths
      complex_mixed: %{
        name: "Organization",
        value: 5000,
        children: [
          %{
            name: "Engineering",
            value: 2000,
            children: [
              %{
                name: "Frontend",
                value: 600,
                children: [
                  %{name: "React", value: 400},
                  %{name: "Vue", value: 200}
                ]
              },
              %{
                name: "Backend",
                value: 800,
                children: [
                  %{name: "Java", value: 400},
                  %{name: "Python", value: 250},
                  %{name: "Go", value: 150}
                ]
              },
              %{name: "DevOps", value: 400}
            ]
          },
          %{
            name: "Marketing",
            value: 1000,
            children: [
              %{name: "Digital", value: 600},
              %{name: "Print", value: 400}
            ]
          },
          %{
            name: "Sales",
            value: 1500,
            children: [
              %{name: "North America", value: 800},
              %{name: "Europe", value: 400},
              %{name: "Asia", value: 300}
            ]
          },
          %{name: "HR", value: 500}
        ]
      }
    }
  end

  @doc """
  Generates a dataset suitable for testing rendering at different terminal sizes.
  The function accepts width and height parameters to allow testing different constraints.
  """
  def size_adaptive_test_data(width, height) do
    # Adapt bar chart - more bars for wider terminals
    num_bars = max(3, div(width, 10))

    bar_data =
      Enum.map(1..num_bars, fn i ->
        %{label: "Item #{i}", value: :rand.uniform(100)}
      end)

    # Adapt treemap - deeper nesting for larger area
    max_depth = max(2, div(min(width, height), 10))

    # Helper to create nested tree structure
    tree = build_nested_tree("Root", max_depth, max(2, div(width, 20)))

    %{
      bar_chart: bar_data,
      treemap: tree,
      width: width,
      height: height
    }
  end

  # Helper function to build a nested tree structure with given depth and branching factor
  defp build_nested_tree(name, depth, branching) when depth <= 1 do
    %{name: name, value: :rand.uniform(100)}
  end

  defp build_nested_tree(name, depth, branching) do
    children =
      Enum.map(1..branching, fn i ->
        # Reduce branching as we go deeper to avoid explosion
        next_branch = max(2, div(branching, 2))
        build_nested_tree("#{name}.#{i}", depth - 1, next_branch)
      end)

    # Sum the values of all children
    total_value =
      Enum.reduce(children, 0, fn child, acc ->
        acc + Map.get(child, :value, 0)
      end)

    %{name: name, value: total_value, children: children}
  end
end
