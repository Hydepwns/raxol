defmodule Raxol.Core.Runtime.Plugins.DependencyManager.VersionTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Version

  describe "check_version/2" do
    test ~c"handles simple version constraints" do
      assert :ok = Version.check_version("1.0.0", ">= 1.0.0")
      assert :ok = Version.check_version("1.1.0", ">= 1.0.0")
      assert :ok = Version.check_version("2.0.0", ">= 1.0.0")

      assert {:error, :version_mismatch} =
               Version.check_version("0.9.0", ">= 1.0.0")
    end

    test ~c"handles exact version matches" do
      assert :ok = Version.check_version("1.0.0", "== 1.0.0")

      assert {:error, :version_mismatch} =
               Version.check_version("1.0.1", "== 1.0.0")

      assert {:error, :version_mismatch} =
               Version.check_version("1.1.0", "== 1.0.0")
    end

    test ~c"handles version ranges" do
      assert :ok = Version.check_version("1.0.0", "~> 1.0")
      assert :ok = Version.check_version("1.0.1", "~> 1.0")
      assert :ok = Version.check_version("1.9.9", "~> 1.0")

      assert {:error, :version_mismatch} =
               Version.check_version("2.0.0", "~> 1.0")
    end

    test ~c"handles complex version constraints" do
      assert :ok = Version.check_version("1.0.0", ">= 1.0.0 and < 2.0.0")
      assert :ok = Version.check_version("1.9.9", ">= 1.0.0 and < 2.0.0")

      assert {:error, :version_mismatch} =
               Version.check_version("2.0.0", ">= 1.0.0 and < 2.0.0")

      assert {:error, :version_mismatch} =
               Version.check_version("0.9.0", ">= 1.0.0 and < 2.0.0")
    end

    test ~c"handles OR conditions" do
      assert :ok = Version.check_version("1.0.0", ">= 1.0.0 || >= 2.0.0")
      assert :ok = Version.check_version("2.0.0", ">= 1.0.0 || >= 2.0.0")

      assert {:error, :version_mismatch} =
               Version.check_version("0.9.0", ">= 1.0.0 || >= 2.0.0")
    end

    test ~c"handles invalid version formats" do
      assert {:error, :invalid_version_format} =
               Version.check_version("invalid", ">= 1.0.0")

      assert {:error, :invalid_version_format} =
               Version.check_version("1", ">= 1.0.0")

      assert {:error, :invalid_version_format} =
               Version.check_version("1.0", ">= 1.0.0")
    end

    test ~c"handles invalid requirement formats" do
      assert {:error, :invalid_requirement_format} =
               Version.check_version("1.0.0", "invalid")

      assert {:error, :invalid_requirement_format} =
               Version.check_version("1.0.0", ">")

      assert {:error, :invalid_requirement_format} =
               Version.check_version("1.0.0", ">= ")
    end
  end

  describe "parse_version_requirement/1" do
    test ~c"parses simple version requirements" do
      assert match?({:ok, _}, Version.parse_version_requirement(">= 1.0.0"))
      assert match?({:ok, _}, Version.parse_version_requirement("== 1.0.0"))
      assert match?({:ok, _}, Version.parse_version_requirement("~> 1.0"))
    end

    test ~c"parses complex version requirements" do
      assert {:ok, _} =
               Version.parse_version_requirement(">= 1.0.0 and < 2.0.0")

      assert {:ok, _} =
               Version.parse_version_requirement(">= 1.0.0 || >= 2.0.0")
    end

    test ~c"handles invalid requirement formats" do
      assert {:error, :invalid_requirement_format} =
               Version.parse_version_requirement("invalid")

      assert {:error, :invalid_requirement_format} =
               Version.parse_version_requirement(">")

      assert {:error, :invalid_requirement_format} =
               Version.parse_version_requirement(">= ")
    end
  end
end
