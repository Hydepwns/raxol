defmodule Raxol.Core.Runtime.Plugins.ManifestTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.Manifest

  defmodule GoodPlugin do
    def manifest do
      %{
        id: :good_plugin,
        name: "Good Plugin",
        version: "1.0.0",
        author: "Test",
        api_version: "1.0",
        description: "A good plugin",
        depends_on: [{:other_plugin, ">= 1.0.0"}],
        conflicts_with: [:bad_plugin],
        provides: [:navigation],
        requires: [],
        resource_budget: %{max_memory_mb: 25}
      }
    end
  end

  defmodule MinimalPlugin do
    def manifest do
      %{
        id: :minimal,
        name: "Minimal",
        version: "0.1.0"
      }
    end
  end

  defmodule CapabilitiesPlugin do
    def manifest do
      %{
        id: :caps_plugin,
        name: "Caps",
        version: "1.0.0",
        capabilities: [:ui_status_line, :system_info]
      }
    end
  end

  defmodule MapDepsPlugin do
    def manifest do
      %{
        id: :map_deps,
        name: "MapDeps",
        version: "1.0.0",
        dependencies: %{"raxol-core" => "~> 1.5", "other" => ">= 0.1.0"}
      }
    end
  end

  defmodule NoManifestPlugin do
  end

  defmodule SelfDepPlugin do
    def manifest do
      %{
        id: :self_dep,
        name: "SelfDep",
        version: "1.0.0",
        depends_on: [{:self_dep, ">= 0.0.0"}]
      }
    end
  end

  describe "from_module/1" do
    test "builds manifest from module with full manifest" do
      assert {:ok, %Manifest{} = m} = Manifest.from_module(GoodPlugin)
      assert m.id == :good_plugin
      assert m.name == "Good Plugin"
      assert m.version == "1.0.0"
      assert m.author == "Test"
      assert m.module == GoodPlugin
      assert m.depends_on == [{:other_plugin, ">= 1.0.0"}]
      assert m.conflicts_with == [:bad_plugin]
      assert m.provides == [:navigation]
      assert m.resource_budget.max_memory_mb == 25
    end

    test "builds manifest with defaults for minimal manifest" do
      assert {:ok, %Manifest{} = m} = Manifest.from_module(MinimalPlugin)
      assert m.id == :minimal
      assert m.api_version == "1.0"
      assert m.depends_on == []
      assert m.provides == []
      assert m.resource_budget.max_memory_mb == 50
    end

    test "normalizes capabilities key to provides" do
      assert {:ok, %Manifest{} = m} = Manifest.from_module(CapabilitiesPlugin)
      assert m.provides == [:ui_status_line, :system_info]
    end

    test "normalizes map-style dependencies" do
      assert {:ok, %Manifest{} = m} = Manifest.from_module(MapDepsPlugin)
      assert length(m.depends_on) == 2
      assert Enum.all?(m.depends_on, fn {id, _v} -> is_atom(id) end)
    end

    test "returns error for module without manifest/0" do
      assert {:error, :no_manifest} = Manifest.from_module(NoManifestPlugin)
    end
  end

  describe "validate/1" do
    test "validates a correct manifest" do
      {:ok, m} = Manifest.from_module(GoodPlugin)
      assert :ok = Manifest.validate(m)
    end

    test "rejects manifest missing required fields" do
      m = %Manifest{id: nil, name: nil, version: nil, module: nil}
      assert {:error, errors} = Manifest.validate(m)
      assert Enum.any?(errors, &String.contains?(&1, "id"))
      assert Enum.any?(errors, &String.contains?(&1, "name"))
      assert Enum.any?(errors, &String.contains?(&1, "module"))
    end

    test "rejects invalid semver" do
      m = %Manifest{id: :test, name: "Test", version: "not.semver", module: Foo}
      assert {:error, errors} = Manifest.validate(m)
      assert Enum.any?(errors, &String.contains?(&1, "semver"))
    end

    test "rejects unsupported api_version" do
      m = %Manifest{
        id: :test,
        name: "Test",
        version: "1.0.0",
        module: Foo,
        api_version: "99.0"
      }

      assert {:error, errors} = Manifest.validate(m)
      assert Enum.any?(errors, &String.contains?(&1, "api_version"))
    end

    test "rejects self-dependency" do
      {:ok, m} = Manifest.from_module(SelfDepPlugin)
      assert {:error, errors} = Manifest.validate(m)
      assert Enum.any?(errors, &String.contains?(&1, "itself"))
    end
  end

  describe "compatible?/2" do
    test "compatible plugins with no conflicts" do
      a = %Manifest{id: :a, conflicts_with: []}
      b = %Manifest{id: :b, conflicts_with: []}
      assert Manifest.compatible?(a, b)
    end

    test "incompatible when a conflicts with b" do
      a = %Manifest{id: :a, conflicts_with: [:b]}
      b = %Manifest{id: :b, conflicts_with: []}
      refute Manifest.compatible?(a, b)
    end

    test "incompatible when b conflicts with a" do
      a = %Manifest{id: :a, conflicts_with: []}
      b = %Manifest{id: :b, conflicts_with: [:a]}
      refute Manifest.compatible?(a, b)
    end
  end
end
