defmodule Raxol.Symphony.PathSafetyTest do
  use ExUnit.Case, async: true

  alias Raxol.Symphony.PathSafety

  describe "sanitize_key/1" do
    test "passes through allowed characters" do
      assert PathSafety.sanitize_key("MT-123") == "MT-123"
      assert PathSafety.sanitize_key("abc.def_ghi") == "abc.def_ghi"
      assert PathSafety.sanitize_key("123-ABC.xyz_999") == "123-ABC.xyz_999"
    end

    test "replaces forbidden characters with underscore" do
      assert PathSafety.sanitize_key("MT 123") == "MT_123"
      assert PathSafety.sanitize_key("foo/bar") == "foo_bar"
      assert PathSafety.sanitize_key("..") == ".."
      assert PathSafety.sanitize_key("foo$bar") == "foo_bar"
    end

    test "neutralizes path traversal attempts" do
      # Forward slashes get sanitized; the resulting key contains no separators.
      sanitized = PathSafety.sanitize_key("../../etc/passwd")
      refute String.contains?(sanitized, "/")
      assert sanitized == ".._.._etc_passwd"
    end

    test "handles unicode by replacing each byte/char outside the allowed set" do
      sanitized = PathSafety.sanitize_key("résumé")
      refute sanitized =~ ~r/[éü]/
      # Length stays positive; non-ASCII chars all turn into underscores.
      assert sanitized == "r_sum_"
    end
  end

  describe "workspace_path/2" do
    test "produces an absolute path under root" do
      root = "/tmp/symphony_workspaces_test"
      assert {:ok, path} = PathSafety.workspace_path(root, "MT-42")
      assert path == "/tmp/symphony_workspaces_test/MT-42"
      assert Path.type(path) == :absolute
    end

    test "applies sanitization to the identifier component" do
      root = "/tmp/symphony_workspaces_test"
      assert {:ok, path} = PathSafety.workspace_path(root, "abc/../etc")
      assert Path.basename(path) == "abc_.._etc"
      # Result must still be inside root.
      assert String.starts_with?(path, root <> "/")
    end

    test "rejects empty workspace root" do
      assert {:error, :invalid_workspace_root} = PathSafety.workspace_path("", "MT-42")
    end
  end

  describe "validate_inside_root/2" do
    test "accepts a path under root" do
      assert {:ok, "/tmp/sym/A"} = PathSafety.validate_inside_root("/tmp/sym/A", "/tmp/sym")
    end

    test "accepts the root itself" do
      assert {:ok, "/tmp/sym"} = PathSafety.validate_inside_root("/tmp/sym", "/tmp/sym")
    end

    test "rejects a sibling-prefix path" do
      assert {:error, :workspace_outside_root} =
               PathSafety.validate_inside_root("/tmp/symbiote", "/tmp/sym")
    end

    test "rejects a path outside root" do
      assert {:error, :workspace_outside_root} =
               PathSafety.validate_inside_root("/etc/passwd", "/tmp/sym")
    end

    test "normalizes both paths before comparing" do
      assert {:ok, "/tmp/sym/A"} =
               PathSafety.validate_inside_root("/tmp/sym/./B/../A", "/tmp/sym/")
    end

    test "rejects path that traverses out via ../" do
      assert {:error, :workspace_outside_root} =
               PathSafety.validate_inside_root("/tmp/sym/../escape", "/tmp/sym")
    end
  end

  describe "assert_cwd!/1" do
    @tag :tmp_dir
    test "passes when cwd matches", %{tmp_dir: tmp_dir} do
      original = File.cwd!()

      try do
        File.cd!(tmp_dir)
        assert :ok = PathSafety.assert_cwd!(tmp_dir)
      after
        File.cd!(original)
      end
    end

    test "raises when cwd mismatches" do
      assert_raise RuntimeError, ~r/cwd .* != expected workspace/, fn ->
        PathSafety.assert_cwd!("/definitely/not/cwd")
      end
    end
  end
end
