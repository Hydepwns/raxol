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
            # Example default
            width: 80,
            # Example default
            height: 20

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
    Logger.debug("Table #{state.id} received message: #{inspect(msg)}")

    case msg do
      {:set_page, page} when is_integer(page) and page > 0 ->
        {%{state | current_page: page}, []}

      {:sort, column_id} ->
        new_direction =
          if state.sort_by == column_id and state.sort_direction == :asc,
            do: :desc,
            else: :asc

        {%{state | sort_by: column_id, sort_direction: new_direction}, []}

      {:filter, term} ->
        # Reset to first page when filtering changes
        {%{state | filter_term: term, current_page: 1}, []}

      _ ->
        {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = props, state) do
    # Handle key events for navigation, selection, etc. if needed
    Logger.debug("Table #{state.id} received event: #{inspect(event)}")

    # Create search field ID constant for comparison
    search_field_id = "#{state.id}_search"

    case event do
      # Handle keyboard navigation events for pagination
      {:key, {:arrow_left, _mods}} ->
        # Check for pagination option
        if is_map_key(state.options, :paginate) && state.options.paginate do
          # If paginate is enabled, go to previous page
          current_page = state.current_page

          if current_page > 1 do
            {%{state | current_page: current_page - 1}, []}
          else
            {state, []}
          end
        else
          {state, []}
        end

      {:key, {:arrow_right, _mods}} ->
        # Check for pagination option
        if is_map_key(state.options, :paginate) && state.options.paginate do
          # If paginate is enabled, go to next page
          current_page = state.current_page
          total_items = length(state.data)
          total_pages = max(1, ceil(total_items / state.page_size))

          if current_page < total_pages do
            {%{state | current_page: current_page + 1}, []}
          else
            {state, []}
          end
        else
          {state, []}
        end

      # Handle text input for search field
      {:text_input, id, value} ->
        if id == search_field_id && is_map_key(state.options, :searchable) &&
             state.options.searchable do
          # Update filter term and reset to first page
          {%{state | filter_term: value, current_page: 1}, []}
        else
          {state, []}
        end

      # Handle button clicks
      {:button_click, id} ->
        cond do
          # Pagination button clicks
          id == "#{state.id}_prev_page" ->
            {%{state | current_page: max(1, state.current_page - 1)}, []}

          id == "#{state.id}_next_page" ->
            total_items = length(state.data)
            total_pages = max(1, ceil(total_items / state.page_size))

            {%{state | current_page: min(total_pages, state.current_page + 1)},
             []}

          # Column header sort button clicks
          String.starts_with?(id, "#{state.id}_sort_") and
              state.options[:sortable] ->
            # Extract column id from button id
            column_id =
              String.replace_prefix(id, "#{state.id}_sort_", "")
              |> String.to_atom()

            new_direction =
              if state.sort_by == column_id and state.sort_direction == :asc,
                do: :desc,
                else: :asc

            {%{state | sort_by: column_id, sort_direction: new_direction}, []}

          true ->
            {state, []}
        end

      _ ->
        {state, []}
    end
  end

  # --- Render Logic ---

  # Main render function implementing Component behaviour
  @impl Raxol.UI.Components.Base.Component
  # Changed arity to 2
  def render(state, %{} = _props) do
    # Prepare data (filter, sort, paginate)
    processed_data = process_data(state)

    # Calculate layout (column widths, etc.) - Placeholder
    col_widths = calculate_column_widths(state.columns, state.width)

    # Use View Elements macros
    Raxol.View.Elements.column id: state.id,
                               width: state.width,
                               height: state.height do
      # Render Search Bar if searchable
      if state.options[:searchable] do
        render_search_bar(state)
      end

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

  defp render_search_bar(state) do
    Raxol.View.Elements.row do
      Raxol.View.Elements.label(content: "Search: ")

      Raxol.View.Elements.text_input(
        id: "#{state.id}_search",
        value: state.filter_term,
        placeholder: "Filter table...",
        on_change: fn value -> {:filter, value} end,
        width: state.width - 10
      )
    end
  end

  defp render_header(columns, col_widths, state) do
    Raxol.View.Elements.row do
      # Render each column header
      Enum.map(columns, fn %{id: id, label: label} ->
        width = Map.get(col_widths, id, 10)

        # Determine if this column is the sort column and the direction
        is_sort_column = state.sort_by == id

        sort_indicator =
          cond do
            not state.options[:sortable] -> ""
            not is_sort_column -> " "
            state.sort_direction == :asc -> " ▲"
            state.sort_direction == :desc -> " ▼"
            true -> " "
          end

        # Calculate adjusted width to account for sort indicator
        adjusted_width = width - String.length(sort_indicator)

        # Format header text with possible truncation
        header_text = String.slice(label, 0, max(0, adjusted_width))
        padded_text = String.pad_trailing(header_text, adjusted_width)

        # Add the sort indicator and create the full label
        full_text = padded_text <> sort_indicator <> " "

        # If sortable, render as a button, otherwise as a label
        if state.options[:sortable] do
          Raxol.View.Elements.button(
            id: "#{state.id}_sort_#{id}",
            label: full_text,
            action: {:sort, id},
            style: %{
              bold: true,
              underline: is_sort_column,
              # Account for space separator
              width: width + 1
            }
          )
        else
          Raxol.View.Elements.label(
            content: full_text,
            # Account for space separator
            style: %{bold: true, width: width + 1}
          )
        end
      end)
    end
  end

  defp render_data_rows(data, columns, col_widths, state) do
    Enum.map(data, fn row_data ->
      render_single_row(row_data, columns, col_widths, state)
    end)
  end

  defp render_single_row(row_data, columns, col_widths, _state) do
    row_cells =
      Enum.map(columns, fn %{id: id} ->
        cell_value = Map.get(row_data, id, "") |> to_string()
        width = Map.get(col_widths, id, 10)
        # Pad/truncate value
        # Add space separator
        String.pad_trailing(cell_value, width) <> " "
      end)

    Raxol.View.Elements.row do
      Raxol.View.Elements.label(content: Enum.join(row_cells))
    end
  end

  defp render_pagination_footer(state) do
    # Calculate total pages
    total_items = length(state.data)
    total_pages = max(1, ceil(total_items / state.page_size))

    # Ensure current_page is within bounds
    current_page = max(1, min(state.current_page, total_pages))

    # Create a pagination row with controls
    Raxol.View.Elements.row do
      # "Previous" button
      Raxol.View.Elements.button(
        id: "#{state.id}_prev_page",
        label: "< Prev",
        action: {:set_page, max(1, current_page - 1)},
        enabled: current_page > 1
      )

      # Page indicator
      Raxol.View.Elements.label(
        content: " Page #{current_page} of #{total_pages} ",
        style: %{bold: true}
      )

      # "Next" button
      Raxol.View.Elements.button(
        id: "#{state.id}_next_page",
        label: "Next >",
        action: {:set_page, min(total_pages, current_page + 1)},
        enabled: current_page < total_pages
      )

      # Additional information
      Raxol.View.Elements.label(
        content: " (#{total_items} items, #{state.page_size} per page)"
      )
    end
  end

  # --- Data Processing Helpers ---

  defp process_data(state) do
    # Apply filtering, sorting, pagination based on state.options and state fields
    # Start with raw data
    data = state.data

    # Apply filtering if filter_term is present and filtering is enabled
    data =
      if state.options[:searchable] && state.filter_term &&
           state.filter_term != "" do
        filter_data(data, state.filter_term)
      else
        data
      end

    # Apply sorting if sort_by is present and sorting is enabled
    data =
      if state.options[:sortable] && state.sort_by do
        sort_data(data, state.sort_by, state.sort_direction)
      else
        data
      end

    # Apply pagination if enabled
    if state.options[:paginate] do
      paginate_data(data, state.current_page, state.page_size)
    else
      data
    end
  end

  defp filter_data(data, filter_term) do
    filter_term = String.downcase(filter_term)

    Enum.filter(data, fn row ->
      # Check if any field in the row contains the filter term
      Enum.any?(row, fn {_key, value} ->
        value
        |> to_string()
        |> String.downcase()
        |> String.contains?(filter_term)
      end)
    end)
  end

  defp sort_data(data, sort_by, direction) do
    Enum.sort_by(
      data,
      fn row ->
        Map.get(row, sort_by)
      end,
      sort_direction_to_comparator(direction)
    )
  end

  defp sort_direction_to_comparator(:asc), do: &<=/2
  defp sort_direction_to_comparator(:desc), do: &>=/2

  defp paginate_data(data, page, page_size) do
    offset = (page - 1) * page_size
    Enum.slice(data, offset, page_size)
  end

  defp calculate_column_widths(columns, total_width) do
    # Placeholder: Distribute width evenly
    num_cols = length(columns)

    each_width =
      if num_cols > 0, do: div(total_width, num_cols), else: total_width

    Map.new(columns, fn %{id: id} -> {id, each_width} end)
  end

  # --- Original Helper Functions (May need removal/refactoring) ---
  # Keep relevant ones, remove those replaced by Component logic or render helpers

  # Example: Original render function (remove or adapt)
  # def render(data, columns, options) do ... end

  # Example: Original pagination helper (adapt or remove)
  # defp paginated(data, page, page_size, sort_by, sort_direction, filter_term) do ... end
end
