defmodule Raxol.Core.Runtime.Plugins.DependencyManager.VersionTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.DependencyManager.Version

  describe "check_version/2" do
    test "returns :ok for matching versions" do
      assert :ok = Version.check_version("1.0.0", ">= 1.0.0")
      assert :ok = Version.check_version("2.0.0", ">= 1.0.0")
      assert :ok = Version.check_version("1.0.0", "== 1.0.0")
      assert :ok = Version.check_version("1.0.0", "~> 1.0.0")
    end

    test "returns error for non-matching versions" do
      assert {:error, :version_mismatch} = Version.check_version("0.9.0", ">= 1.0.0")
      assert {:error, :version_mismatch} = Version.check_version("2.0.0", "== 1.0.0")
      assert {:error, :version_mismatch} = Version.check_version("2.0.0", "~> 1.0.0")
    end

    test "handles OR conditions" do
      assert :ok = Version.check_version("1.0.0", ">= 1.0.0 || >= 2.0.0")
      assert :ok = Version.check_version("2.0.0", ">= 1.0.0 || >= 2.0.0")
      assert {:error, :version_mismatch} = Version.check_version("0.9.0", ">= 1.0.0 || >= 2.0.0")
    end

    test "handles invalid version formats" do
      assert {:error, :invalid_version_format} = Version.check_version("invalid", ">= 1.0.0")
      assert {:error, :invalid_version_format} = Version.check_version("1", ">= 1.0.0")
      assert {:error, :invalid_version_format} = Version.check_version("1.0", ">= 1.0.0")
    end

    test "handles invalid requirement formats" do
      assert {:error, :invalid_requirement_format} = Version.check_version("1.0.0", "invalid")
      assert {:error, :invalid_requirement_format} = Version.check_version("1.0.0", ">")
      assert {:error, :invalid_requirement_format} = Version.check_version("1.0.0", ">= ")
    end
  end

  describe "parse_version_requirement/1" do
    test "parses simple requirements" do
      assert {:ok, ">= 1.0.0"} = Version.parse_version_requirement(">= 1.0.0")
      assert {:ok, "== 1.0.0"} = Version.parse_version_requirement("== 1.0.0")
      assert {:ok, "~> 1.0.0"} = Version.parse_version_requirement("~> 1.0.0")
    end

    test "parses OR conditions" do
      assert {:ok, {:or, [">= 1.0.0", ">= 2.0.0"]}} =
               Version.parse_version_requirement(">= 1.0.0 || >= 2.0.0")
    end

    test "handles whitespace in requirements" do
      assert {:ok, ">= 1.0.0"} = Version.parse_version_requirement("  >=  1.0.0  ")
      assert {:ok, {:or, [">= 1.0.0", ">= 2.0.0"]}} =
               Version.parse_version_requirement("  >=  1.0.0  ||  >=  2.0.0  ")
    end

    test "handles invalid requirements" do
      assert {:error, :invalid_requirement} = Version.parse_version_requirement("invalid")
      assert {:error, :invalid_requirement} = Version.parse_version_requirement(">")
      assert {:error, :invalid_requirement} = Version.parse_version_requirement(">= ")
    end

    test "handles invalid OR conditions" do
      assert {:error, :invalid_requirement} = Version.parse_version_requirement(">= 1.0.0 || invalid")
      assert {:error, :invalid_requirement} = Version.parse_version_requirement("invalid || >= 1.0.0")
    end
  end

  describe "parse_single_requirement/1" do
    test "parses valid requirements" do
      assert {:ok, ">= 1.0.0"} = Version.parse_single_requirement(">= 1.0.0")
      assert {:ok, "== 1.0.0"} = Version.parse_single_requirement("== 1.0.0")
      assert {:ok, "~> 1.0.0"} = Version.parse_single_requirement("~> 1.0.0")
    end

    test "handles whitespace" do
      assert {:ok, ">= 1.0.0"} = Version.parse_single_requirement("  >=  1.0.0  ")
    end

    test "handles invalid requirements" do
      assert {:error, :invalid_requirement} = Version.parse_single_requirement("invalid")
      assert {:error, :invalid_requirement} = Version.parse_single_requirement(">")
      assert {:error, :invalid_requirement} = Version.parse_single_requirement(">= ")
    end
  end
end
