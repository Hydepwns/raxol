defmodule Raxol.UI.Components.Modal.Rendering do
  @moduledoc """
  Rendering logic and form field rendering for the Modal component.
  """

  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  alias Raxol.UI.Components.Selection.Dropdown

  @doc "Renders the modal content when visible."
  @spec render_modal_content(map()) :: any()
  def render_modal_content(state) do
    Raxol.View.Elements.box id: get_modal_box_id(state),
                            style: get_modal_style(state) do
      Raxol.View.Elements.column style: %{width: :fill, padding: 1} do
        build_modal_elements(
          render_title(state.title),
          render_content(state),
          render_buttons(state.buttons)
        )
      end
    end
  end

  @doc "Renders the modal title."
  @spec render_title(String.t()) :: any()
  def render_title(title) do
    Raxol.View.Elements.label(content: title, style: %{bold: true})
  end

  @doc "Renders the modal content based on type."
  @spec render_content(map()) :: any()
  def render_content(%{content: content} = state) when is_binary(content) do
    Raxol.View.Elements.label(content: content)
  end

  def render_content(%{type: type} = state) when type in [:prompt, :form] do
    render_form_content(state)
  end

  def render_content(%{content: content}) when not is_nil(content) do
    content
  end

  def render_content(_state) do
    nil
  end

  @doc "Renders modal buttons."
  @spec render_buttons(list()) :: list()
  def render_buttons(buttons) do
    Enum.map(buttons, fn {label, msg} ->
      Raxol.View.Elements.button(
        label: label,
        on_click: {:button_click, msg}
      )
    end)
  end

  @doc "Gets modal box ID."
  @spec get_modal_box_id(map()) :: any()
  def get_modal_box_id(state) do
    if Map.get(state, :id, nil),
      do: "#{Map.get(state, :id, nil)}-box",
      else: nil
  end

  @doc "Gets modal style."
  @spec get_modal_style(map()) :: map()
  def get_modal_style(state) do
    Map.merge(
      %{border: :double, width: state.width, align: :center},
      state.style
    )
  end

  @doc "Builds modal elements with proper spacing."
  @spec build_modal_elements(any(), any(), list()) :: list()
  def build_modal_elements(title_element, content_element, button_elements) do
    [
      title_element,
      render_spacer(title_element && content_element),
      content_element,
      render_spacer(content_element && button_elements != []),
      render_button_row(button_elements)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc "Renders spacer element."
  @spec render_spacer(boolean()) :: any()
  def render_spacer(condition) do
    if condition, do: Raxol.View.Elements.label(content: "")
  end

  @doc "Renders button row."
  @spec render_button_row(list()) :: any()
  def render_button_row(button_elements) do
    Raxol.View.Elements.row style: %{justify: :center, width: :fill, gap: 2} do
      button_elements
    end
  end

  @doc "Renders form content with fields."
  @spec render_form_content(map()) :: any()
  def render_form_content(state) do
    field_elements =
      Enum.with_index(state.form_state.fields)
      |> Enum.map(&render_field(&1, state))
      |> Enum.reject(&is_nil/1)

    Raxol.View.Elements.column style: %{width: :fill, gap: 1} do
      field_elements
    end
  end

  @doc "Renders a single form field."
  @spec render_field({map(), integer()}, map()) :: any()
  def render_field({field, index}, state) do
    field_full_id =
      Raxol.UI.Components.Modal.State.get_field_full_id(field, state)

    focused? = index == state.form_state.focus_index
    common_props = get_common_props(field, field_full_id, focused?)

    input_element = render_input_element(field, common_props)
    render_field_container(field, input_element)
  end

  @doc "Gets common props for form fields."
  @spec get_common_props(map(), any(), boolean()) :: map()
  def get_common_props(field, field_full_id, focused?) do
    Map.merge(field.props || %{}, %{
      id: field_full_id,
      focused: focused?
    })
  end

  @doc "Renders input element based on field type."
  @spec render_input_element(map(), map()) :: any()
  def render_input_element(field, common_props) do
    case field.type do
      :text_input -> render_text_input(field, common_props)
      :checkbox -> render_checkbox(field, common_props)
      :dropdown -> render_dropdown(field, common_props)
      _ -> render_unsupported_field(field)
    end
  end

  @doc "Renders text input field."
  @spec render_text_input(map(), map()) :: any()
  def render_text_input(field, common_props) do
    text_input_props =
      Map.merge(common_props, %{
        "value" => field.value || "",
        "on_change" => {:field_update, field.id}
      })

    Raxol.View.Elements.text_input(text_input_props)
  end

  @doc "Renders checkbox field."
  @spec render_checkbox(map(), map()) :: any()
  def render_checkbox(field, common_props) do
    checkbox_props =
      Map.merge(common_props, %{
        "checked" => !!field.value,
        "label" => "",
        "on_toggle" => {:field_update, field.id}
      })

    Raxol.View.Elements.checkbox(checkbox_props)
  end

  @doc "Renders dropdown field."
  @spec render_dropdown(map(), map()) :: any()
  def render_dropdown(field, common_props) do
    dropdown_props =
      Map.merge(common_props, %{
        "options" => field.options || [],
        "initial_value" => field.value,
        "width" => :fill,
        "on_change" => {:field_update, field.id}
      })

    %{type: Dropdown, attrs: dropdown_props}
  end

  @doc "Renders unsupported field type."
  @spec render_unsupported_field(map()) :: any()
  def render_unsupported_field(field) do
    Raxol.Core.Runtime.Log.warning(
      "Unsupported form field type in Modal: #{inspect(field.type)}"
    )

    Raxol.View.Elements.label(content: "[Unsupported Field: #{field.id}]")
  end

  @doc "Renders field container with label and error."
  @spec render_field_container(map(), any()) :: any()
  def render_field_container(field, input_element) do
    Raxol.View.Elements.column style: %{width: :fill, gap: 0} do
      [
        render_field_row(field, input_element),
        render_field_error(field)
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  @doc "Renders field row with label and input."
  @spec render_field_row(map(), any()) :: any()
  def render_field_row(field, input_element) do
    Raxol.View.Elements.row style: %{width: :fill, gap: 1} do
      [
        if(field.label,
          do:
            Raxol.View.Elements.label(content: field.label, style: %{width: 15})
        ),
        input_element
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  @doc "Renders field error message."
  @spec render_field_error(map()) :: any()
  def render_field_error(field) do
    if field.error do
      Raxol.View.Elements.row style: %{width: :fill} do
        Raxol.View.Elements.label(
          content: field.error,
          style: %{color: :red, padding_left: 16}
        )
      end
    end
  end
end
