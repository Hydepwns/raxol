defmodule Raxol.Plugin.ManifestTest do
  use ExUnit.Case, async: true

  alias Raxol.Plugin.Manifest

  @valid_opts [
    id: :test_plugin,
    name: "Test Plugin",
    version: "1.0.0",
    module: SomeModule
  ]

  describe "new/1" do
    test "builds manifest with required fields" do
      manifest = Manifest.new(@valid_opts)
      assert manifest.id == :test_plugin
      assert manifest.name == "Test Plugin"
      assert manifest.version == "1.0.0"
      assert manifest.module == SomeModule
    end

    test "applies defaults for optional fields" do
      manifest = Manifest.new(@valid_opts)
      assert manifest.author == ""
      assert manifest.api_version == "1.0"
      assert manifest.description == ""
      assert manifest.depends_on == []
      assert manifest.conflicts_with == []
      assert manifest.provides == []
      assert manifest.requires == []
      assert manifest.resource_budget == Manifest.default_budget()
    end

    test "allows overriding optional fields" do
      manifest =
        Manifest.new(
          @valid_opts ++
            [
              author: "Test Author",
              api_version: "2.0",
              description: "A test plugin",
              depends_on: [{:other_plugin, "~> 1.0"}],
              provides: [:logging],
              requires: [:networking]
            ]
        )

      assert manifest.author == "Test Author"
      assert manifest.api_version == "2.0"
      assert manifest.description == "A test plugin"
      assert manifest.depends_on == [{:other_plugin, "~> 1.0"}]
      assert manifest.provides == [:logging]
      assert manifest.requires == [:networking]
    end

    test "merges resource budget with defaults" do
      manifest = Manifest.new(@valid_opts ++ [resource_budget: %{max_memory_mb: 100}])
      assert manifest.resource_budget.max_memory_mb == 100
      assert manifest.resource_budget.max_processes == 20
    end

    test "returns map, not struct" do
      manifest = Manifest.new(@valid_opts)
      assert is_map(manifest)
      refute Map.has_key?(manifest, :__struct__)
    end
  end

  describe "validate/1" do
    test "returns :ok for valid manifest" do
      manifest = Manifest.new(@valid_opts)
      assert :ok = Manifest.validate(manifest)
    end

    test "returns error for missing id" do
      manifest = Manifest.new(Keyword.delete(@valid_opts, :id))
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "id is required"))
    end

    test "returns error for missing name" do
      manifest = Manifest.new(Keyword.delete(@valid_opts, :name))
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "name is required"))
    end

    test "returns error for missing version" do
      manifest = Manifest.new(Keyword.delete(@valid_opts, :version))
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "version is required"))
    end

    test "returns error for missing module" do
      manifest = Manifest.new(Keyword.delete(@valid_opts, :module))
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "module is required"))
    end

    test "returns error for invalid semver" do
      manifest = Manifest.new(Keyword.put(@valid_opts, :version, "not-semver"))
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "valid semver"))
    end

    test "returns error for unsupported api_version" do
      manifest = Manifest.new(@valid_opts ++ [api_version: "99.0"])
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "unsupported api_version"))
    end

    test "returns error for self-dependency" do
      manifest = Manifest.new(@valid_opts ++ [depends_on: [{:test_plugin, "~> 1.0"}]])
      assert {:error, errors} = Manifest.validate(manifest)
      assert Enum.any?(errors, &String.contains?(&1, "depend on itself"))
    end

    test "collects multiple errors" do
      manifest = Manifest.new(id: nil, name: nil, version: nil, module: nil)
      assert {:error, errors} = Manifest.validate(manifest)
      assert length(errors) >= 3
    end

    test "accepts all supported api versions" do
      for api <- Manifest.supported_api_versions() do
        manifest = Manifest.new(@valid_opts ++ [api_version: api])
        assert :ok = Manifest.validate(manifest)
      end
    end
  end

  describe "default_budget/0" do
    test "returns expected defaults" do
      budget = Manifest.default_budget()
      assert budget.max_memory_mb == 50
      assert budget.max_cpu_percent == 10
      assert budget.max_ets_tables == 2
      assert budget.max_processes == 20
    end
  end
end
