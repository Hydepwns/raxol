# This example demonstrates the Raxol.UI.Components.Display.Progress component.
defmodule Raxol.Docs.Guides.Examples.Display.ProgressBarTest do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  defmodule State do
    defstruct progress_value: 25, timer: nil
  end

  @impl true
  def init(_opts) do
    # Start a timer to update the progress bar
    {:ok, timer} = :timer.send_interval(500, :tick)
    %State{progress_value: 0, timer: timer}
  end

  @impl true
  def update(message, model = %State{}) do
    case message do
      :tick ->
        new_value =
          if model.progress_value >= 100 do
            0 # Reset
          else
            model.progress_value + 5
          end
        %State{model | progress_value: new_value}

      _ ->
        model
    end
  end

  @impl true
  def view(model = %State{}) do
    view do
      column(gap: 15, padding: 15) do
        text(content: "Progress Bar Example", style: "font-size: 1.3em; font-weight: bold;")

        # Basic Progress Bar
        text(content: "Basic Progress Bar (Value: #{model.progress_value}%)")
        progress_bar(value: model.progress_value, max: 100, style: "width: 300px;")

        # Progress Bar with different styling (if supported/needed)
        # text(content: "Styled Progress Bar")
        # progress_bar(value: model.progress_value, max: 100, style: "width: 400px; height: 25px;")
      end
    end
  end

  @impl true
  def terminate(_reason, model = %State{}) do
     # Ensure the timer is cancelled when the application stops
     if model.timer, do: :timer.cancel(model.timer)
     :ok
  end

  # Function to run the example directly
  def main do
    Raxol.start_link(__MODULE__, [])
    # For CI/test/demo: sleep for 2 seconds, then exit. Adjust as needed.
    Process.sleep(2000)
  end
end

# To run this example: mix run -e "Raxol.Docs.Guides.Examples.Display.ProgressBarTest.main()"
# (Assuming Raxol is a dependency or mix project is set up)
