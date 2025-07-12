defmodule Raxol.Benchmarks.DataGenerator do
  @moduledoc """
  Shared data generation utilities for benchmarks.
  """

  @doc """
  Generates treemap data with varying depth based on size.
  """
  def generate_treemap_data(size) when size <= 10 do
    # Small dataset - flat structure
    %{
      name: "Root",
      value: size * 10,
      children:
        for i <- 1..size do
          %{
            name: "Item #{i}",
            value: :rand.uniform(100)
          }
        end
    }
  end

  def generate_treemap_data(size) when size <= 100 do
    # Medium dataset - two levels
    num_groups = min(10, div(size, 5))
    items_per_group = div(size, num_groups)

    %{
      name: "Root",
      value: size * 10,
      children:
        for g <- 1..num_groups do
          %{
            name: "Group #{g}",
            value: items_per_group * 10,
            children:
              for i <- 1..items_per_group do
                %{
                  name: "Item #{g}.#{i}",
                  value: :rand.uniform(100)
                }
              end
          }
        end
    }
  end

  def generate_treemap_data(size) do
    # Large dataset - three levels
    num_sections = min(10, div(size, 50))
    num_groups_per_section = min(10, div(size, 10))
    items_per_group = max(1, div(size, num_sections * num_groups_per_section))

    %{
      name: "Root",
      value: size * 10,
      children:
        for s <- 1..num_sections do
          %{
            name: "Section #{s}",
            value: div(size, num_sections) * 10,
            children:
              for g <- 1..num_groups_per_section do
                %{
                  name: "Group #{s}.#{g}",
                  value: items_per_group * 10,
                  children:
                    for i <- 1..items_per_group do
                      %{
                        name: "Item #{s}.#{g}.#{i}",
                        value: :rand.uniform(100)
                      }
                    end
                }
              end
          }
        end
    }
  end

  @doc """
  Counts nodes in a treemap structure.
  """
  def count_nodes(nil), do: 0
  def count_nodes(%{children: nil}), do: 1
  def count_nodes(%{children: []}), do: 1

  def count_nodes(%{children: children}) when list?(children) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end

  def count_nodes(_), do: 1

  @doc """
  Generates chart data.
  """
  def generate_chart_data(size) do
    for i <- 1..size do
      {"Item #{i}", :rand.uniform(100)}
    end
  end
end
