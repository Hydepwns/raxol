defmodule EventMacroHelpers do
  defmacro delegate_handle_event_3_to_2 do
    quote do
      def handle_event(event, state, _context), do: handle_event(event, state)
    end
  end
end
