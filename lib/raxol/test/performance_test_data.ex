defmodule Raxol.Test.PerformanceTestData do
  @moduledoc """
  Provides large sample data and data generation helpers for performance tests.
  """

  @large_data Enum.map(1..1000, fn i ->
                %{
                  id: i,
                  name: "Product #{i}",
                  sales: Enum.map(1..12, fn _ -> :rand.uniform(1000) end),
                  trend: Enum.random([:up, :down, :stable])
                }
              end)

  def large_data, do: @large_data

  def generate_columns(count) do
    # Generate column definitions for a table
    for i <- 1..count do
      %{
        header: "Column #{i}",
        # Assuming :id is the primary key for data mapping
        key: :id,
        # Default width, can be overridden
        width: 15,
        # Default alignment
        align: :left,
        # Example formatter, can be customized per column
        format: fn id_val -> "Value #{id_val}-#{i}" end
      }
    end
  end

  def generate_data(rows, columns, start_offset \\ 0) do
    # Generate data for a table
    Enum.map(1..rows, fn i ->
      %{
        # Use offset for unique IDs
        id: i + start_offset,
        name: "Product #{i + start_offset}",
        sales: Enum.map(1..columns, fn _ -> :rand.uniform(1000) end),
        trend: Enum.random([:up, :down, :stable])
      }
    end)
  end
end
