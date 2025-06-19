defmodule Raxol.UI.Components.Input.ButtonVisualTest do
  use ExUnit.Case, async: true
  use Raxol.Test.Visual

  alias Raxol.UI.Components.Input.Button

  describe "visual tests for Button component" do
    test "renders default button" do
      component = setup_visual_component(Button, %{label: "Click Me"})

      assert_renders_as(component, fn output ->
        # Basic assertion: Check if the button's label is in the output
        sanitized_output = Regex.replace(~r/<[^>]*>/, output, "")
        assert String.contains?(sanitized_output, "Click Me")
        # More assertions can be added here, e.g., for layout or style
      end)
    end

    # TODO: Example of a snapshot test (can be uncommented and adapted)
    # test 'matches snapshot' do
    #   component = setup_visual_component(Button, %{label: "Snapshot Button"})
    #   context = %{snapshots_dir: "test/snapshots/button"} # Ensure this directory exists
    #
    #   # First run will create the snapshot if it doesn't exist
    #   # On subsequent runs, it will compare against the existing snapshot
    #   case compare_with_snapshot(component, "default_button_state", context) do
    #     :ok ->
    #       :ok # Test passes
    #     {:error, :no_snapshot} ->
    #       snapshot_component(component, "default_button_state", context)
    #       flunk("Snapshot created. Re-run test to compare.")
    #     {:diff, diff_output} ->
    #       flunk("Snapshot does not match:\n#{IO.iodata_to_binary(diff_output)}")
    #   end
    # end
  end
end
