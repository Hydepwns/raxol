defmodule Raxol.Benchmark.SuitesTest do
  use ExUnit.Case, async: true

  alias Raxol.Benchmark.{Apps, Formatter}
  alias Raxol.Benchmark.Suites.{Comparison, InputLatency, RenderThroughput, Startup, WidgetMemory}

  describe "Apps" do
    test "all returns 5 modules" do
      assert length(Apps.all()) == 5
    end

    test "as_map returns correct keys" do
      map = Apps.as_map()
      assert Map.has_key?(map, "empty")
      assert Map.has_key?(map, "simple_text")
      assert Map.has_key?(map, "table100")
      assert Map.has_key?(map, "nested_layout")
      assert Map.has_key?(map, "dashboard")
    end

    test "each app has init/1, update/2, view/1" do
      for mod <- Apps.all() do
        assert function_exported?(mod, :init, 1), "#{mod} missing init/1"
        assert function_exported?(mod, :update, 2), "#{mod} missing update/2"
        assert function_exported?(mod, :view, 1), "#{mod} missing view/1"
      end
    end

    test "each app init returns a map" do
      for mod <- Apps.all() do
        model = mod.init(nil)
        assert is_map(model), "#{mod}.init/1 should return a map"
      end
    end

    test "each app view returns a view tree" do
      for mod <- Apps.all() do
        model = mod.init(nil)
        view = mod.view(model)
        assert view != nil, "#{mod}.view/1 should return a view tree"
      end
    end

    test "each app update returns {model, commands}" do
      for mod <- Apps.all() do
        model = mod.init(nil)
        {new_model, commands} = mod.update(:tick, model)
        assert is_map(new_model), "#{mod}.update/2 should return a map"
        assert is_list(commands), "#{mod}.update/2 should return commands list"
      end
    end
  end

  describe "RenderThroughput" do
    test "returns non-empty job map" do
      jobs = RenderThroughput.jobs()
      assert map_size(jobs) == 5
      assert Enum.all?(jobs, fn {_name, fun} -> is_function(fun, 0) end)
    end

    test "quick mode returns fewer jobs" do
      jobs = RenderThroughput.jobs(quick: true)
      assert map_size(jobs) == 2
    end

    test "jobs produce valid output" do
      jobs = RenderThroughput.jobs(quick: true)

      for {_name, fun} <- jobs do
        result = fun.()
        assert is_list(result), "render job should return cell list"
      end
    end
  end

  describe "InputLatency" do
    test "returns non-empty job map" do
      jobs = InputLatency.jobs()
      assert map_size(jobs) == 5
    end

    test "jobs produce valid output" do
      jobs = InputLatency.jobs(quick: true)

      for {_name, fun} <- jobs do
        result = fun.()
        assert is_list(result)
      end
    end
  end

  describe "WidgetMemory" do
    test "returns jobs with scale variations" do
      jobs = WidgetMemory.jobs()
      assert map_size(jobs) > 5
      assert Map.has_key?(jobs, "memory_100_texts")
    end

    test "quick mode skips scale jobs" do
      jobs = WidgetMemory.jobs(quick: true)
      refute Map.has_key?(jobs, "memory_100_texts")
    end
  end

  describe "Startup" do
    test "returns non-empty job map" do
      jobs = Startup.jobs(quick: true)
      assert map_size(jobs) == 2
    end
  end

  describe "Comparison" do
    test "returns competitor list" do
      competitors = Comparison.competitors()
      assert length(competitors) == 3
      assert Enum.all?(competitors, &Map.has_key?(&1, :name))
    end

    test "comparison_table returns formatted lines" do
      lines = Comparison.comparison_table()
      assert length(lines) > 3
      assert hd(lines) =~ "Framework"
      assert Enum.any?(lines, &(&1 =~ "Raxol"))
    end
  end

  describe "Formatter" do
    test "console formats results" do
      result = Formatter.console(%{test: %{a: 1}})
      assert is_binary(result)
      assert result =~ "TEST"
    end

    test "json produces valid JSON" do
      result = Formatter.json(%{test: %{a: 1}})
      assert {:ok, _} = Jason.decode(result)
    end

    test "markdown produces valid markdown" do
      result = Formatter.markdown(%{test: %{a: 1}})
      assert result =~ "# Raxol Benchmark Results"
      assert result =~ "##"
    end

    test "write creates file" do
      path = Path.join(System.tmp_dir!(), "formatter_test_#{System.unique_integer([:positive])}.txt")
      assert :ok = Formatter.write("test content", path)
      assert File.read!(path) == "test content"
      File.rm(path)
    end
  end
end
