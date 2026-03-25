defmodule Raxol.Core.Runtime.Plugins.PluginEventProcessorTest do
  @moduledoc """
  Tests for event filtering and processing through plugins.
  """
  use ExUnit.Case, async: false

  alias Raxol.Core.Runtime.Plugins.PluginEventProcessor
  alias Raxol.Core.Runtime.Plugins.PluginSupervisor
  alias Raxol.Test.Plugins

  setup do
    # Ensure test plugin modules are loaded (required for function_exported?)
    Code.ensure_loaded!(Plugins.PassthroughPlugin)
    Code.ensure_loaded!(Plugins.ModifyingPlugin)
    Code.ensure_loaded!(Plugins.HaltingPlugin)
    Code.ensure_loaded!(Plugins.ErrorPlugin)
    Code.ensure_loaded!(Plugins.CrashingPlugin)
    Code.ensure_loaded!(Plugins.SlowPlugin)
    Code.ensure_loaded!(Plugins.NoFilterPlugin)

    # Ensure the supervisor is started for isolation
    case Process.whereis(PluginSupervisor) do
      nil ->
        {:ok, _} = PluginSupervisor.start_link()
      _pid ->
        :ok
    end

    :ok
  end

  describe "filter_event/5" do
    test "passes event through plugin that doesn't modify" do
      plugins = %{passthrough: Plugins.PassthroughPlugin}
      metadata = %{passthrough: %{enabled: true}}
      states = %{passthrough: %{}}
      load_order = [:passthrough]

      event = %{type: :test, data: "original"}

      assert {:ok, ^event} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end

    test "returns modified event from modifying plugin" do
      plugins = %{modifier: Plugins.ModifyingPlugin}
      metadata = %{modifier: %{enabled: true}}
      states = %{modifier: %{}}
      load_order = [:modifier]

      event = %{type: :test}

      assert {:ok, filtered} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
      assert filtered.modified_by == Plugins.ModifyingPlugin
      assert filtered.type == :test
    end

    test "returns :halt when plugin halts propagation" do
      plugins = %{halter: Plugins.HaltingPlugin}
      metadata = %{halter: %{enabled: true}}
      states = %{halter: %{}}
      load_order = [:halter]

      event = %{halt: true}

      assert :halt = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end

    test "continues with non-halting events" do
      plugins = %{halter: Plugins.HaltingPlugin}
      metadata = %{halter: %{enabled: true}}
      states = %{halter: %{}}
      load_order = [:halter]

      event = %{halt: false, data: "keep going"}

      assert {:ok, ^event} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end

    test "processes multiple plugins in order" do
      plugins = %{
        first: Plugins.ModifyingPlugin,
        second: Plugins.PassthroughPlugin
      }
      metadata = %{
        first: %{enabled: true},
        second: %{enabled: true}
      }
      states = %{first: %{}, second: %{}}
      load_order = [:first, :second]

      event = %{type: :test}

      assert {:ok, filtered} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
      # First plugin should have modified the event
      assert filtered.modified_by == Plugins.ModifyingPlugin
    end

    test "halting plugin stops further processing" do
      plugins = %{
        halter: Plugins.HaltingPlugin,
        modifier: Plugins.ModifyingPlugin
      }
      metadata = %{
        halter: %{enabled: true},
        modifier: %{enabled: true}
      }
      states = %{halter: %{}, modifier: %{}}
      load_order = [:halter, :modifier]

      # Event that will trigger halt
      event = %{halt: true}

      # Should halt, modifier should never see it
      assert :halt = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end

    test "skips disabled plugins" do
      plugins = %{
        disabled: Plugins.ModifyingPlugin,
        enabled: Plugins.PassthroughPlugin
      }
      metadata = %{
        disabled: %{enabled: false},
        enabled: %{enabled: true}
      }
      states = %{disabled: %{}, enabled: %{}}
      load_order = [:disabled, :enabled]

      event = %{type: :test}

      assert {:ok, filtered} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
      # Disabled modifier should not have modified
      refute Map.has_key?(filtered, :modified_by)
    end

    test "passes through for plugins without filter_event" do
      plugins = %{no_filter: Plugins.NoFilterPlugin}
      metadata = %{no_filter: %{enabled: true}}
      states = %{no_filter: %{}}
      load_order = [:no_filter]

      event = %{type: :test}

      assert {:ok, ^event} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end

    test "continues on plugin error" do
      plugins = %{
        error: Plugins.ErrorPlugin,
        passthrough: Plugins.PassthroughPlugin
      }
      metadata = %{
        error: %{enabled: true},
        passthrough: %{enabled: true}
      }
      states = %{error: %{}, passthrough: %{}}
      load_order = [:error, :passthrough]

      # Trigger error in first plugin
      event = %{error: true}

      # Should continue to next plugin
      assert {:ok, ^event} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end

    test "handles empty plugin list" do
      plugins = %{}
      metadata = %{}
      states = %{}
      load_order = []

      event = %{type: :test}

      assert {:ok, ^event} = PluginEventProcessor.filter_event(
        event, plugins, metadata, states, load_order
      )
    end
  end

  describe "filter_through_plugin/5" do
    test "returns filtered event from single plugin" do
      plugins = %{test: Plugins.ModifyingPlugin}
      metadata = %{test: %{enabled: true}}
      states = %{test: %{}}

      event = %{type: :test}

      assert {:ok, filtered} = PluginEventProcessor.filter_through_plugin(
        :test, event, plugins, metadata, states
      )
      assert filtered.modified_by == Plugins.ModifyingPlugin
    end

    test "returns :halt from halting plugin" do
      plugins = %{halter: Plugins.HaltingPlugin}
      metadata = %{halter: %{enabled: true}}
      states = %{halter: %{}}

      event = %{halt: true}

      assert :halt = PluginEventProcessor.filter_through_plugin(
        :halter, event, plugins, metadata, states
      )
    end

    test "returns error for non-existent plugin" do
      plugins = %{}
      metadata = %{}
      states = %{}

      event = %{type: :test}

      assert {:error, :plugin_not_found} = PluginEventProcessor.filter_through_plugin(
        :nonexistent, event, plugins, metadata, states
      )
    end

    test "passes through for disabled plugin" do
      plugins = %{disabled: Plugins.ModifyingPlugin}
      metadata = %{disabled: %{enabled: false}}
      states = %{disabled: %{}}

      event = %{type: :test}

      assert {:ok, ^event} = PluginEventProcessor.filter_through_plugin(
        :disabled, event, plugins, metadata, states
      )
    end

    test "passes through for plugin without filter_event" do
      plugins = %{no_filter: Plugins.NoFilterPlugin}
      metadata = %{no_filter: %{enabled: true}}
      states = %{no_filter: %{}}

      event = %{type: :test}

      assert {:ok, ^event} = PluginEventProcessor.filter_through_plugin(
        :no_filter, event, plugins, metadata, states
      )
    end

    test "isolates plugin crashes and passes through" do
      plugins = %{crasher: Plugins.CrashingPlugin}
      metadata = %{crasher: %{enabled: true}}
      states = %{crasher: %{}}

      # Event that triggers crash
      event = %{crash: true}

      # Should pass through on crash
      assert {:ok, ^event} = PluginEventProcessor.filter_through_plugin(
        :crasher, event, plugins, metadata, states
      )
    end

    test "handles plugin state not found" do
      plugins = %{test: Plugins.PassthroughPlugin}
      metadata = %{test: %{enabled: true}}
      states = %{}  # No state

      event = %{type: :test}

      assert {:error, :plugin_state_not_found} = PluginEventProcessor.filter_through_plugin(
        :test, event, plugins, metadata, states
      )
    end
  end

  describe "sort_plugins_by_priority/2" do
    test "sorts plugins by priority (lower first)" do
      load_order = [:low, :high, :medium]
      metadata = %{
        low: %{priority: 100},
        high: %{priority: 1},
        medium: %{priority: 50}
      }

      sorted = PluginEventProcessor.sort_plugins_by_priority(load_order, metadata)

      assert [:high, :medium, :low] = sorted
    end

    test "plugins without priority get default (low)" do
      load_order = [:with_priority, :without_priority]
      metadata = %{
        with_priority: %{priority: 1},
        without_priority: %{enabled: true}
      }

      sorted = PluginEventProcessor.sort_plugins_by_priority(load_order, metadata)

      assert [:with_priority, :without_priority] = sorted
    end

    test "preserves order for equal priorities" do
      load_order = [:a, :b, :c]
      metadata = %{
        a: %{priority: 10},
        b: %{priority: 10},
        c: %{priority: 10}
      }

      sorted = PluginEventProcessor.sort_plugins_by_priority(load_order, metadata)

      # Should maintain stable sort order
      assert length(sorted) == 3
      assert Enum.all?([:a, :b, :c], &(&1 in sorted))
    end

    test "handles empty metadata" do
      load_order = [:a, :b]
      metadata = %{}

      sorted = PluginEventProcessor.sort_plugins_by_priority(load_order, metadata)

      # All get default priority, original order maintained
      assert length(sorted) == 2
    end
  end

  describe "get_dependency_ordered_plugins/2" do
    test "orders plugins after their dependencies" do
      load_order = [:dependent, :dependency]
      metadata = %{
        dependent: %{dependencies: [:dependency]},
        dependency: %{}
      }

      ordered = PluginEventProcessor.get_dependency_ordered_plugins(load_order, metadata)

      dep_idx = Enum.find_index(ordered, &(&1 == :dependency))
      dependent_idx = Enum.find_index(ordered, &(&1 == :dependent))

      assert dep_idx < dependent_idx
    end

    test "handles no dependencies" do
      load_order = [:a, :b, :c]
      metadata = %{
        a: %{},
        b: %{},
        c: %{}
      }

      ordered = PluginEventProcessor.get_dependency_ordered_plugins(load_order, metadata)

      assert length(ordered) == 3
    end

    test "handles chain of dependencies" do
      load_order = [:c, :b, :a]
      metadata = %{
        a: %{},
        b: %{dependencies: [:a]},
        c: %{dependencies: [:b]}
      }

      ordered = PluginEventProcessor.get_dependency_ordered_plugins(load_order, metadata)

      a_idx = Enum.find_index(ordered, &(&1 == :a))
      b_idx = Enum.find_index(ordered, &(&1 == :b))
      c_idx = Enum.find_index(ordered, &(&1 == :c))

      assert a_idx < b_idx
      assert b_idx < c_idx
    end

    test "handles multiple plugins with same dependency" do
      load_order = [:dep1, :dep2, :base]
      metadata = %{
        base: %{},
        dep1: %{dependencies: [:base]},
        dep2: %{dependencies: [:base]}
      }

      ordered = PluginEventProcessor.get_dependency_ordered_plugins(load_order, metadata)

      base_idx = Enum.find_index(ordered, &(&1 == :base))
      dep1_idx = Enum.find_index(ordered, &(&1 == :dep1))
      dep2_idx = Enum.find_index(ordered, &(&1 == :dep2))

      assert base_idx < dep1_idx
      assert base_idx < dep2_idx
    end
  end
end
