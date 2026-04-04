defmodule Mix.Raxol.Templates do
  @moduledoc """
  Template descriptions and previews for `mix raxol.new`.
  """

  @template_descriptions %{
    "counter" => "Interactive counter with buttons and keyboard shortcuts",
    "blank" => "Minimal skeleton with just quit handling",
    "todo" => "Todo list with add/delete/toggle and input modes",
    "dashboard" => "Multi-panel layout with tabs, live stats via subscriptions"
  }

  @templates Map.keys(@template_descriptions) |> Enum.sort()

  def template_descriptions, do: @template_descriptions
  def templates, do: @templates

  @doc "Prints the full template list with previews."
  def print_template_list do
    Mix.shell().info([:bright, "Available templates:", :reset])
    Mix.shell().info("")

    for name <- @templates do
      desc = @template_descriptions[name]
      label = String.pad_trailing(name, 12)
      Mix.shell().info(["  ", :cyan, label, :reset, desc])
    end

    Mix.shell().info("")
    Mix.shell().info("Usage: mix raxol.new my_app --template NAME")
    Mix.shell().info("")

    for name <- @templates do
      print_template_preview(name)
    end
  end

  @doc "Prints an interactive template prompt and returns the chosen template name."
  def prompt_template(opts) do
    print_template_menu()

    answer =
      Mix.shell().prompt(
        "Template [counter/blank/todo/dashboard] (default: counter)"
      )
      |> String.trim()
      |> String.downcase()

    Keyword.put(opts, :template, resolve_template(answer))
  end

  defp print_template_menu do
    Mix.shell().info("")
    Mix.shell().info([:bright, "Available templates:", :reset])

    for {name, i} <- Enum.with_index(@templates, 1) do
      desc = @template_descriptions[name]
      Mix.shell().info("  #{i}. #{String.pad_trailing(name, 12)} #{desc}")
    end
  end

  defp resolve_template(""), do: "counter"
  defp resolve_template("1"), do: "counter"
  defp resolve_template("2"), do: "blank"
  defp resolve_template("3"), do: "dashboard"
  defp resolve_template("4"), do: "todo"
  defp resolve_template(t) when t in @templates, do: t

  defp resolve_template(_) do
    Mix.shell().info([:yellow, "Unknown template, using counter.", :reset])
    "counter"
  end

  # --- Private ---

  defp print_template_preview("counter") do
    Mix.shell().info([:bright, "counter", :reset, " generates:"])

    Mix.shell().info(
      "  lib/my_app.ex      -- Counter with +/- buttons and keyboard control"
    )

    Mix.shell().info(
      "  test/my_app_test.exs -- Tests for increment/decrement/unknown"
    )

    Mix.shell().info("")
  end

  defp print_template_preview("blank") do
    Mix.shell().info([:bright, "blank", :reset, " generates:"])
    Mix.shell().info("  lib/my_app.ex      -- Empty TEA app with quit handling")

    Mix.shell().info(
      "  test/my_app_test.exs -- Tests for init and unknown messages"
    )

    Mix.shell().info("")
  end

  defp print_template_preview("todo") do
    Mix.shell().info([:bright, "todo", :reset, " generates:"])

    Mix.shell().info(
      "  lib/my_app.ex      -- Todo list with add/toggle/delete, input mode"
    )

    Mix.shell().info("  test/my_app_test.exs -- Tests for CRUD operations")
    Mix.shell().info("")
  end

  defp print_template_preview("dashboard") do
    Mix.shell().info([:bright, "dashboard", :reset, " generates:"])

    Mix.shell().info(
      "  lib/my_app.ex      -- 3-panel dashboard with live stats subscription"
    )

    Mix.shell().info(
      "  test/my_app_test.exs -- Tests for panel switching and tick"
    )

    Mix.shell().info("")
  end
end
