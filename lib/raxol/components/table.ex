defmodule Raxol.Components.Table do
  @moduledoc """
  Renders data in a tabular format with optional headers, sorting, and pagination.
  """

  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Logger

  # Require view macros
  require Raxol.View.Elements

  # Define state struct
  defstruct id: nil,
            columns: [],
            data: [],
            options: %{},
            sort_by: nil,
            sort_direction: :asc,
            current_page: 1,
            page_size: 10,
            filter_term: "",
            # Add any other necessary state fields
            width: 80, # Example default
            height: 20 # Example default

  # --- Component Behaviour Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state from props, potentially merging with defaults
    # Example: Merge options, set initial data/columns
    opts = Map.get(props, :options, %{})
    default_opts = %{paginate: false, searchable: false, sortable: false}
    merged_opts = Map.merge(default_opts, opts)

    %__MODULE__{
      id: props[:id],
      columns: props[:columns] || [],
      data: props[:data] || [],
      options: merged_opts,
      page_size: Map.get(opts, :page_size, 10),
      width: Map.get(props, :width, 80),
      height: Map.get(props, :height, 20)
      # Initialize other fields as needed
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages for sorting, pagination, filtering, etc.
    Logger.debug("Table #{state.id} received message: #{inspect msg}")
    # Placeholder
    case msg do
      {:set_page, page} when is_integer(page) and page > 0 ->
        {%{state | current_page: page}, []}
      {:sort, column_id} ->
        new_direction = if state.sort_by == column_id and state.sort_direction == :asc, do: :desc, else: :asc
        {%{state | sort_by: column_id, sort_direction: new_direction}, []}
      _ -> {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle key events for navigation, selection, etc. if needed
    Logger.debug("Table #{state.id} received event: #{inspect event}")
    # Placeholder
    {state, []}
  end

  # --- Render Logic ---

  # Main render function implementing Component behaviour
  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do # Changed arity to 2
    # Prepare data (filter, sort, paginate)
    processed_data = process_data(state)

    # Calculate layout (column widths, etc.) - Placeholder
    col_widths = calculate_column_widths(state.columns, state.width)

    # Use View Elements macros
    Raxol.View.Elements.column id: state.id, width: state.width, height: state.height do
      # Render Header
      if state.options[:header] != false do
        render_header(state.columns, col_widths, state)
      end

      # Render Separator (example)
      Raxol.View.Elements.label(content: String.duplicate("-", state.width))

      # Render Data Rows
      render_data_rows(processed_data, state.columns, col_widths, state)

      # Render Footer (pagination controls, etc.) - Placeholder
      if state.options[:paginate] do
        render_pagination_footer(state)
      end
    end
    # Note: Raxol.View.Elements.column returns the element structure directly
    # No need for to_element here unless the result needs wrapping.
  end


  # --- Internal Render Helpers (Simplified) ---

  defp render_header(columns, col_widths, _state) do
    header_cells = Enum.map(columns, fn %{id: id, label: label} ->
      width = Map.get(col_widths, id, 10)
      # Pad/truncate label
      String.pad_trailing(label, width) <> " " # Add space separator
    end)

    Raxol.View.Elements.row do
      Raxol.View.Elements.label(content: Enum.join(header_cells))
    end
  end

  defp render_data_rows(data, columns, col_widths, state) do
    Enum.map(data, fn row_data ->
      render_single_row(row_data, columns, col_widths, state)
    end)
  end

  defp render_single_row(row_data, columns, col_widths, _state) do
     row_cells = Enum.map(columns, fn %{id: id} ->
       cell_value = Map.get(row_data, id, "") |> to_string()
       width = Map.get(col_widths, id, 10)
       # Pad/truncate value
       String.pad_trailing(cell_value, width) <> " " # Add space separator
     end)

     Raxol.View.Elements.row do
        Raxol.View.Elements.label(content: Enum.join(row_cells))
     end
  end

  defp render_pagination_footer(state) do
    # Placeholder pagination
    Raxol.View.Elements.row do
      Raxol.View.Elements.label(content: "Page: #{state.current_page}")
      # TODO: Add buttons/links for prev/next page
    end
  end

  # --- Data Processing Helpers ---

  defp process_data(state) do
    # Apply filtering, sorting, pagination based on state.options and state fields
    data = state.data # Start with raw data
    # TODO: Implement filtering based on state.filter_term
    # TODO: Implement sorting based on state.sort_by and state.sort_direction
    # TODO: Implement pagination based on state.current_page and state.page_size
    data
  end

  defp calculate_column_widths(columns, total_width) do
    # Placeholder: Distribute width evenly
    num_cols = length(columns)
    each_width = if num_cols > 0, do: div(total_width, num_cols), else: total_width
    Map.new(columns, fn %{id: id} -> {id, each_width} end)
  end

  # --- Original Helper Functions (May need removal/refactoring) ---
  # Keep relevant ones, remove those replaced by Component logic or render helpers

  # Example: Original render function (remove or adapt)
  # def render(data, columns, options) do ... end

  # Example: Original pagination helper (adapt or remove)
  # defp paginated(data, page, page_size, sort_by, sort_direction, filter_term) do ... end

end
