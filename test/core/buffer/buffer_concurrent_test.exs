defmodule Raxol.Core.Buffer.BufferConcurrentTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @moduledoc """
  Tests for concurrent buffer access and operations.
  These tests verify that the buffer operations are thread-safe
  and handle concurrent access correctly.
  """

  describe "Concurrent Write Operations" do
    test ~c"handles multiple concurrent writers" do
      buffer = Buffer.new({80, 24})

      # Create multiple writer processes
      writers =
        Enum.map(1..10, fn writer_id ->
          Task.async(fn ->
            # Each writer writes to a different region
            start_x = rem(writer_id, 8) * 10
            start_y = div(writer_id, 8) * 3

            Enum.reduce(0..2, buffer, fn y, acc ->
              Enum.reduce(0..9, acc, fn x, acc ->
                cell = Cell.new("W#{writer_id}", TextFormatting.new(fg: :red))
                Buffer.set_cell(acc, start_x + x, start_y + y, cell)
              end)
            end)
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(writers, 5000)

      # Verify all writers completed successfully
      assert Enum.all?(results, fn result ->
               case result do
                 {:ok, _} -> true
                 _ -> false
               end
             end)
    end

    test ~c"handles concurrent writes to same region" do
      buffer = Buffer.new({80, 24})

      # Create writers that write to the same region
      writers =
        Enum.map(1..5, fn writer_id ->
          Task.async(fn ->
            Enum.reduce(0..4, buffer, fn y, acc ->
              Enum.reduce(0..4, acc, fn x, acc ->
                cell = Cell.new("W#{writer_id}", TextFormatting.new(fg: :blue))
                Buffer.set_cell(acc, x, y, cell)
              end)
            end)
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(writers, 5000)

      # Verify all writers completed successfully
      assert Enum.all?(results, fn result ->
               case result do
                 {:ok, _} -> true
                 _ -> false
               end
             end)
    end
  end

  describe "Concurrent Read/Write Operations" do
    test ~c"handles concurrent reads and writes" do
      buffer = Buffer.new({80, 24})

      # Create reader and writer processes
      readers =
        Enum.map(1..5, fn reader_id ->
          Task.async(fn ->
            Enum.reduce(1..100, buffer, fn _, acc ->
              x = :rand.uniform(80) - 1
              y = :rand.uniform(24) - 1
              Buffer.get_cell(acc, x, y)
              acc
            end)
          end)
        end)

      writers =
        Enum.map(1..5, fn writer_id ->
          Task.async(fn ->
            Enum.reduce(1..100, buffer, fn i, acc ->
              x = :rand.uniform(80) - 1
              y = :rand.uniform(24) - 1
              cell = Cell.new("W#{writer_id}", TextFormatting.new(fg: :green))
              Buffer.set_cell(acc, x, y, cell)
            end)
          end)
        end)

      # Wait for all processes to complete
      results = Task.await_many(readers ++ writers, 5000)

      # Verify all processes completed successfully
      assert Enum.all?(results, fn result ->
               case result do
                 {:ok, _} -> true
                 _ -> false
               end
             end)
    end
  end

  describe "Concurrent Buffer Operations" do
    test ~c"handles concurrent buffer operations" do
      buffer = Buffer.new({80, 24})

      # Create processes that perform different operations
      operations = [
        # Reader
        Task.async(fn ->
          Enum.reduce(1..100, buffer, fn _, acc ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            Buffer.get_cell(acc, x, y)
            acc
          end)
        end),

        # Writer
        Task.async(fn ->
          Enum.reduce(1..100, buffer, fn i, acc ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            cell = Cell.new("W", TextFormatting.new(fg: :yellow))
            Buffer.set_cell(acc, x, y, cell)
          end)
        end),

        # Scroller
        Task.async(fn ->
          Enum.reduce(1..20, buffer, fn _, acc ->
            Buffer.scroll(acc, 1)
          end)
        end),

        # Region filler
        Task.async(fn ->
          Enum.reduce(1..10, buffer, fn i, acc ->
            x = rem(i, 8) * 10
            y = div(i, 8) * 3
            cell = Cell.new("F", TextFormatting.new(fg: :red))
            Buffer.fill_region(acc, x, y, 10, 3, cell)
          end)
        end)
      ]

      # Wait for all operations to complete
      results = Task.await_many(operations, 5000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               case result do
                 {:ok, _} -> true
                 _ -> false
               end
             end)
    end
  end

  describe "Stress Testing" do
    test ~c"handles high concurrency stress test" do
      buffer = Buffer.new({80, 24})

      # Create many concurrent operations
      operations =
        Enum.flat_map(1..20, fn i ->
          [
            # Reader
            Task.async(fn ->
              Enum.reduce(1..50, buffer, fn _, acc ->
                x = :rand.uniform(80) - 1
                y = :rand.uniform(24) - 1
                Buffer.get_cell(acc, x, y)
                acc
              end)
            end),

            # Writer
            Task.async(fn ->
              Enum.reduce(1..50, buffer, fn j, acc ->
                x = :rand.uniform(80) - 1
                y = :rand.uniform(24) - 1
                cell = Cell.new("W#{i}", TextFormatting.new(fg: :blue))
                Buffer.set_cell(acc, x, y, cell)
              end)
            end)
          ]
        end)

      # Wait for all operations to complete
      results = Task.await_many(operations, 10000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               case result do
                 {:ok, _} -> true
                 _ -> false
               end
             end)
    end
  end
end
