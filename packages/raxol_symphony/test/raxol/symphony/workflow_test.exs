defmodule Raxol.Symphony.WorkflowTest do
  use ExUnit.Case, async: true

  alias Raxol.Symphony.Workflow

  describe "parse/1" do
    test "parses front matter and trims body" do
      contents = """
      ---
      tracker:
        kind: linear
        project_slug: "demo"
      polling:
        interval_ms: 5000
      ---

      You are working on issue {{ issue.identifier }}.

      """

      assert {:ok, %{config: config, prompt_template: prompt}} = Workflow.parse(contents)

      assert get_in(config, [:tracker, :kind]) == "linear"
      assert get_in(config, [:tracker, :project_slug]) == "demo"
      assert get_in(config, [:polling, :interval_ms]) == 5000
      assert prompt == "You are working on issue {{ issue.identifier }}."
    end

    test "treats whole file as body when no front matter" do
      contents = "Just a prompt body, no YAML.\n"

      assert {:ok, %{config: %{}, prompt_template: "Just a prompt body, no YAML."}} =
               Workflow.parse(contents)
    end

    test "returns error when YAML front matter is not a map" do
      contents = """
      ---
      - just
      - a
      - list
      ---

      body
      """

      assert {:error, :workflow_front_matter_not_a_map} = Workflow.parse(contents)
    end

    test "returns parse error for malformed YAML" do
      contents = """
      ---
      this: : : is invalid
      ---
      body
      """

      assert {:error, {:workflow_parse_error, _}} = Workflow.parse(contents)
    end

    test "treats unclosed front matter as full body" do
      contents = """
      ---
      tracker:
        kind: linear

      Body without closing delimiter.
      """

      assert {:ok, %{config: %{}, prompt_template: prompt}} = Workflow.parse(contents)
      assert String.starts_with?(prompt, "---")
    end

    test "atomizes nested map keys" do
      contents = """
      ---
      hooks:
        after_create: |
          echo hi
      agent:
        max_concurrent_agents: 4
      ---
      body
      """

      assert {:ok, %{config: config}} = Workflow.parse(contents)

      assert Map.has_key?(config, :hooks)
      assert Map.has_key?(config.hooks, :after_create)
      assert config.hooks.after_create =~ "echo hi"
      assert config.agent.max_concurrent_agents == 4
    end

    test "preserves list values without atomizing" do
      contents = """
      ---
      tracker:
        active_states:
          - Todo
          - In Progress
      ---
      body
      """

      assert {:ok, %{config: config}} = Workflow.parse(contents)
      assert config.tracker.active_states == ["Todo", "In Progress"]
    end

    test "empty front matter section yields empty config" do
      contents = """
      ---
      ---
      just a body
      """

      assert {:ok, %{config: %{}, prompt_template: "just a body"}} = Workflow.parse(contents)
    end
  end

  describe "load/1" do
    @tag :tmp_dir
    test "loads from disk", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "WORKFLOW.md")

      File.write!(path, """
      ---
      tracker:
        kind: linear
      ---
      hello
      """)

      assert {:ok, %{config: %{tracker: %{kind: "linear"}}, prompt_template: "hello"}} =
               Workflow.load(path)
    end

    test "returns missing error for non-existent file" do
      assert {:error, :missing_workflow_file} = Workflow.load("/nonexistent/path/WORKFLOW.md")
    end
  end
end
