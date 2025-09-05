defmodule Raxol.Examples.SelectListShowcase do
  @moduledoc """
  Showcase for the enhanced SelectList component with its various features.

  This example demonstrates:
  - Basic selection (single and multiple)
  - Searching and filtering
  - Pagination
  - Keyboard navigation
  - Styling options
  """
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  import Raxol.View.Elements

  @impl Raxol.UI.Components.Base.Component
  def init(_props) do
    %{
      # Current tab selection
      active_tab: :basic,

      # Selected options from each list
      basic_selected: nil,
      multiple_selected: [],
      search_selected: nil,
      pagination_selected: nil,

      # Search text
      search_text: "",

      # Sample data
      users: [
        %{
          id: 1,
          name: "Alice Smith",
          email: "alice@example.com",
          role: "Admin"
        },
        %{id: 2, name: "Bob Johnson", email: "bob@example.com", role: "User"},
        %{
          id: 3,
          name: "Carol Williams",
          email: "carol@example.com",
          role: "User"
        },
        %{
          id: 4,
          name: "Dave Brown",
          email: "dave@example.com",
          role: "Moderator"
        },
        %{id: 5, name: "Eve Davis", email: "eve@example.com", role: "Admin"},
        %{
          id: 6,
          name: "Frank Miller",
          email: "frank@example.com",
          role: "User"
        },
        %{
          id: 7,
          name: "Grace Wilson",
          email: "grace@example.com",
          role: "User"
        },
        %{
          id: 8,
          name: "Heidi Moore",
          email: "heidi@example.com",
          role: "Moderator"
        },
        %{id: 9, name: "Ivan Taylor", email: "ivan@example.com", role: "User"},
        %{id: 10, name: "Judy White", email: "judy@example.com", role: "Admin"},
        %{
          id: 11,
          name: "Kevin Lewis",
          email: "kevin@example.com",
          role: "User"
        },
        %{
          id: 12,
          name: "Laura Harris",
          email: "laura@example.com",
          role: "Moderator"
        },
        %{id: 13, name: "Mike Clark", email: "mike@example.com", role: "User"},
        %{
          id: 14,
          name: "Nancy Young",
          email: "nancy@example.com",
          role: "User"
        },
        %{
          id: 15,
          name: "Oscar Scott",
          email: "oscar@example.com",
          role: "Admin"
        }
      ],
      countries: [
        %{
          code: "US",
          name: "United States",
          population: "331 million",
          continent: "North America"
        },
        %{
          code: "CN",
          name: "China",
          population: "1.4 billion",
          continent: "Asia"
        },
        %{
          code: "IN",
          name: "India",
          population: "1.38 billion",
          continent: "Asia"
        },
        %{
          code: "ID",
          name: "Indonesia",
          population: "273 million",
          continent: "Asia"
        },
        %{
          code: "PK",
          name: "Pakistan",
          population: "220 million",
          continent: "Asia"
        },
        %{
          code: "BR",
          name: "Brazil",
          population: "212 million",
          continent: "South America"
        },
        %{
          code: "NG",
          name: "Nigeria",
          population: "206 million",
          continent: "Africa"
        },
        %{
          code: "BD",
          name: "Bangladesh",
          population: "164 million",
          continent: "Asia"
        },
        %{
          code: "RU",
          name: "Russia",
          population: "144 million",
          continent: "Europe/Asia"
        },
        %{
          code: "MX",
          name: "Mexico",
          population: "128 million",
          continent: "North America"
        },
        %{
          code: "JP",
          name: "Japan",
          population: "126 million",
          continent: "Asia"
        },
        %{
          code: "ET",
          name: "Ethiopia",
          population: "114 million",
          continent: "Africa"
        },
        %{
          code: "PH",
          name: "Philippines",
          population: "109 million",
          continent: "Asia"
        },
        %{
          code: "EG",
          name: "Egypt",
          population: "102 million",
          continent: "Africa"
        },
        %{
          code: "VN",
          name: "Vietnam",
          population: "97 million",
          continent: "Asia"
        },
        %{
          code: "DE",
          name: "Germany",
          population: "83 million",
          continent: "Europe"
        },
        %{
          code: "IR",
          name: "Iran",
          population: "83 million",
          continent: "Asia"
        },
        %{
          code: "TR",
          name: "Turkey",
          population: "83 million",
          continent: "Europe/Asia"
        },
        %{
          code: "FR",
          name: "France",
          population: "67 million",
          continent: "Europe"
        },
        %{
          code: "GB",
          name: "United Kingdom",
          population: "67 million",
          continent: "Europe"
        },
        %{
          code: "TH",
          name: "Thailand",
          population: "66 million",
          continent: "Asia"
        },
        %{
          code: "IT",
          name: "Italy",
          population: "60 million",
          continent: "Europe"
        },
        %{
          code: "ZA",
          name: "South Africa",
          population: "59 million",
          continent: "Africa"
        },
        %{
          code: "MM",
          name: "Myanmar",
          population: "54 million",
          continent: "Asia"
        },
        %{
          code: "KR",
          name: "South Korea",
          population: "51 million",
          continent: "Asia"
        },
        %{
          code: "CO",
          name: "Colombia",
          population: "50 million",
          continent: "South America"
        },
        %{
          code: "KE",
          name: "Kenya",
          population: "53 million",
          continent: "Africa"
        },
        %{
          code: "ES",
          name: "Spain",
          population: "47 million",
          continent: "Europe"
        },
        %{
          code: "AR",
          name: "Argentina",
          population: "45 million",
          continent: "South America"
        },
        %{
          code: "DZ",
          name: "Algeria",
          population: "43 million",
          continent: "Africa"
        }
      ],
      fruits: [
        {"Apple", :apple},
        {"Banana", :banana},
        {"Cherry", :cherry},
        {"Date", :date},
        {"Elderberry", :elderberry},
        {"Fig", :fig},
        {"Grape", :grape},
        {"Honeydew", :honeydew},
        {"Imbe", :imbe},
        {"Jackfruit", :jackfruit}
      ]
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event({:select_tab, tab}, _props, state) when is_atom(tab) do
    {%{state | active_tab: tab}, []}
  end

  def handle_event({:select_fruit, fruit_value}, _props, state) do
    # Basic single selection
    {%{state | basic_selected: fruit_value}, []}
  end

  def handle_event({:select_user, user_id}, _props, state) do
    # For multiple selection
    handle_user_selection(
      state.multiple_selected |> Enum.member?(user_id),
      user_id,
      state
    )
  end

  def handle_event({:select_user_with_search, user_id}, _props, state) do
    # Search list selection
    user = state.users |> Enum.find(&(&1.id == user_id))
    {%{state | search_selected: user}, []}
  end

  def handle_event({:select_country, country_code}, _props, state) do
    # Pagination list selection
    country = state.countries |> Enum.find(&(&1.code == country_code))
    {%{state | pagination_selected: country}, []}
  end

  def handle_event({:update_search, search_text}, _props, state) do
    {%{state | search_text: search_text}, []}
  end

  def handle_event(_event, _props, state) do
    {state, []}
  end

  @impl Raxol.UI.Components.Base.Component
  def render(state, _context) do
    # Custom theme settings
    theme = %{
      select_list: %{
        label_fg: :cyan,
        focused_fg: :black,
        focused_bg: :cyan,
        selected_fg: :black,
        selected_bg: :green,
        search_fg: :white,
        search_bg: :blue,
        pagination_fg: :white,
        pagination_bg: :blue
      }
    }

    panel title: "SelectList Component Showcase", border: :single, width: 100 do
      column padding: 1, gap: 1 do
        # Description
        label(
          "This showcase demonstrates the enhanced SelectList component with various features."
        )

        # Tab navigation
        row gap: 2 do
          button(
            label: "Basic",
            on_click: {:select_tab, :basic},
            style: get_tab_style(state.active_tab == :basic)
          )

          button(
            label: "Multiple Selection",
            on_click: {:select_tab, :multiple},
            style: get_tab_style(state.active_tab == :multiple)
          )

          button(
            label: "Search & Filter",
            on_click: {:select_tab, :search},
            style: get_tab_style(state.active_tab == :search)
          )

          button(
            label: "Pagination",
            on_click: {:select_tab, :pagination},
            style: get_tab_style(state.active_tab == :pagination)
          )
        end

        # Content based on selected tab
        panel title: tab_title(state.active_tab), border: :single, height: 20 do
          column padding: 1, gap: 1 do
            case state.active_tab do
              :basic -> render_basic_tab(state, theme)
              :multiple -> render_multiple_tab(state, theme)
              :search -> render_search_tab(state, theme)
              :pagination -> render_pagination_tab(state, theme)
            end
          end
        end

        # Selection display
        panel title: "Selected Items", border: :single do
          column padding: 1, gap: 1 do
            case state.active_tab do
              :basic ->
                render_basic_selection(state.basic_selected)

              :multiple ->
                render_multiple_selection(state.multiple_selected, state.users)

              :search ->
                render_search_selection(state.search_selected)

              :pagination ->
                render_pagination_selection(state.pagination_selected)
            end
          end
        end

        # Instructions panel
        panel title: "Keyboard Navigation", border: :single do
          column padding: 1 do
            label(text: "Arrow Up/Down: Navigate items")
            label(text: "Page Up/Down: Navigate pages")
            label(text: "Home/End: Jump to first/last item")

            label(
              text:
                "Tab: Switch between search box and list (when search enabled)"
            )

            label(text: "Enter: Select item")
            label(text: "Space: Toggle selection (in multiple selection mode)")
            label(text: "Backspace: Delete search text (when search focused)")
            label(text: "Type any text: Incremental search in list")
          end
        end
      end
    end
  end

  # Helper functions for refactored if statements

  # Handle user selection instead of if statement
  defp handle_user_selection(true, user_id, state) do
    # Remove from selection
    {%{
       state
       | multiple_selected:
           state.multiple_selected |> Enum.reject(&(&1 == user_id))
     }, []}
  end

  defp handle_user_selection(false, user_id, state) do
    # Add to selection
    {%{state | multiple_selected: [user_id | state.multiple_selected]}, []}
  end

  # Get tab style instead of if statement
  defp get_tab_style(true), do: [bg: :blue, fg: :white]
  defp get_tab_style(false), do: []

  # Render basic selection instead of if statement
  defp render_basic_selection(nil), do: label(text: "No fruit selected")
  defp render_basic_selection(selected), do: label(text: "Selected fruit: #{selected}")

  # Render multiple selection instead of if statement
  defp render_multiple_selection(selected, _users) when selected == [] do
    label(text: "No users selected")
  end

  defp render_multiple_selection(selected, users) do
    selected_users =
      users
      |> Enum.filter(&Enum.member?(selected, &1.id))
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    label(text: "Selected users: #{selected_users}")
  end

  # Render search selection instead of if statement
  defp render_search_selection(nil), do: label(text: "No user selected")

  defp render_search_selection(selected) do
    column do
      label(text: "Selected user:")
      label(text: "Name: #{selected.name}")
      label(text: "Email: #{selected.email}")
      label(text: "Role: #{selected.role}")
    end
  end

  # Render pagination selection instead of if statement
  defp render_pagination_selection(nil), do: label(text: "No country selected")

  defp render_pagination_selection(selected) do
    column do
      label(text: "Selected country:")
      label(text: "Name: #{selected.name}")
      label(text: "Population: #{selected.population}")
      label(text: "Continent: #{selected.continent}")
    end
  end

  # Tab-specific rendering functions

  defp render_basic_tab(state, theme) do
    column gap: 1 do
      label(text: "Basic single-selection list with fruits:")

      # Convert fruits to expected format for SelectList options
      options = Enum.map(state.fruits, fn {label, value} -> {label, value} end)

      %{
        type: Raxol.UI.Components.Input.SelectList,
        id: :basic_select,
        assigns: %{
          options: options,
          label: "Select a fruit:",
          on_select: {:select_fruit},
          max_height: 10,
          theme: theme.select_list
        }
      }
    end
  end

  defp render_multiple_tab(state, theme) do
    column gap: 1 do
      label(text: "Multiple selection list with users:")

      # Convert users to expected format for SelectList options
      options =
        Enum.map(state.users, fn user ->
          {"#{user.name} (#{user.role})", user.id}
        end)

      %{
        type: Raxol.UI.Components.Input.SelectList,
        id: :multiple_select,
        assigns: %{
          options: options,
          label: "Select users (use Space to toggle):",
          on_select: {:select_user},
          max_height: 12,
          multiple: true,
          theme: theme.select_list
        }
      }
    end
  end

  defp render_search_tab(state, theme) do
    column gap: 1 do
      label(text: "Searchable list with users:")

      # Convert users to expected format for SelectList options
      options =
        Enum.map(state.users, fn user ->
          {"#{user.name} (#{user.email})", user.id}
        end)

      %{
        type: Raxol.UI.Components.Input.SelectList,
        id: :search_select,
        assigns: %{
          options: options,
          label: "Search users (by name or email):",
          on_select: {:select_user_with_search},
          max_height: 12,
          enable_search: true,
          searchable_fields: [:name, :email],
          placeholder: "Type to search...",
          theme: theme.select_list
        }
      }
    end
  end

  defp render_pagination_tab(state, theme) do
    column gap: 1 do
      label(text: "Paginated list with countries:")

      # Convert countries to expected format for SelectList options
      options =
        Enum.map(state.countries, fn country ->
          {"#{country.name} (#{country.continent})", country.code}
        end)

      %{
        type: Raxol.UI.Components.Input.SelectList,
        id: :pagination_select,
        assigns: %{
          options: options,
          label: "Select a country:",
          on_select: {:select_country},
          max_height: 12,
          page_size: 8,
          show_pagination: true,
          theme: theme.select_list
        }
      }
    end
  end

  defp tab_title(tab) do
    case tab do
      :basic -> "Basic Selection"
      :multiple -> "Multiple Selection"
      :search -> "Search & Filter"
      :pagination -> "Pagination"
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def update({:update_props, new_props}, state) do
    {:noreply, Map.merge(state, new_props)}
  end

  def update({:tab_selected, tab}, state) do
    {:noreply, %{state | active_tab: tab}}
  end
end
