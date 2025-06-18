defmodule Raxol.UI.Components.Dashboard.LayoutPersistence do
  @moduledoc '''
  Handles saving and loading dashboard widget layouts to disk.
  '''

  require Raxol.Core.Runtime.Log

  # User-specific config dir
  @layout_file Path.expand("~/.raxol/dashboard_layout.bin")

  @doc '''
  Saves the current widget layout (list of widget configs) to a file.

  Only saves fields essential for reconstructing the layout and widget state:
  `:id`, `:type`, `:title`, `:grid_spec`, `:component_opts`, `:data`.
  '''
  @spec save_layout(list(map())) :: :ok | {:error, term()}
  def save_layout(widgets) when is_list(widgets) do
    layout_file = @layout_file

    try do
      :ok = File.mkdir_p(Path.dirname(layout_file))

      layout_data =
        Enum.map(widgets, fn w ->
          Map.take(w, [:id, :type, :title, :grid_spec, :component_opts, :data])
        end)

      binary_data = :erlang.term_to_binary(layout_data)

      case File.write(layout_file, binary_data) do
        :ok ->
          Raxol.Core.Runtime.Log.info(
            "Dashboard layout saved to #{layout_file}"
          )

          :ok

        {:error, reason} ->
          Raxol.Core.Runtime.Log.error(
            "Failed to save dashboard layout to #{layout_file}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Failed to save dashboard layout to #{layout_file}: #{inspect(e)}"
        )

        # Consider wrapping the specific exception
        {:error, {:exception, e}}
    end
  end

  @doc '''
  Loads the widget layout from the file.
  Returns the list of widget configurations `[map()]` or `nil` if load fails or file doesn't exist.
  '''
  @spec load_layout() :: list(map()) | nil
  def load_layout do
    layout_file = @layout_file

    if File.exists?(layout_file) do
      try do
        case File.read(layout_file) do
          {:ok, binary_data} ->
            # Use safe binary_to_term
            layout_data = :erlang.binary_to_term(binary_data, [:safe])

            Raxol.Core.Runtime.Log.info(
              "Dashboard layout loaded from #{layout_file}"
            )

            # Basic validation: is it a list?
            if is_list(layout_data), do: layout_data, else: nil

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to read dashboard layout file #{layout_file}: #{inspect(reason)}"
            )

            nil
        end
      rescue
        e ->
          Raxol.Core.Runtime.Log.error(
            "Failed to deserialize dashboard layout from #{layout_file}: #{inspect(e)}"
          )

          nil
      end
    else
      Raxol.Core.Runtime.Log.info(
        "No saved dashboard layout found at #{layout_file}"
      )

      # Return nil explicitly if file doesn't exist
      nil
    end
  end
end
