defmodule Raxol.Telegram.Bot do
  @moduledoc """
  Telegram bot update handler.

  Routes incoming Telegram updates (messages, callback queries) to
  the SessionRouter. Handles `/start` and `/stop` commands directly.

  This module provides `handle_update/2` which can be called from
  a Telegex polling loop or webhook handler.

  ## Access Control

  Pass `allowed_chat_ids: [id1, id2]` to restrict which chats can
  interact with the bot. When set, updates from unlisted chats are
  silently ignored. When omitted or `nil`, all chats are allowed.
  """

  alias Raxol.Telegram.{InputAdapter, SessionRouter}

  @compile {:no_warn_undefined, [Telegex]}

  @doc """
  Processes a Telegram update.

  Dispatches messages and callback queries to the appropriate session.

  ## Options

    * `:allowed_chat_ids` - list of allowed chat IDs (nil = allow all)
  """
  @spec handle_update(map(), keyword()) :: :ok | {:error, term()}
  def handle_update(update, opts \\ [])

  def handle_update(
        %{callback_query: %{data: data, message: %{chat: %{id: chat_id}}} = query},
        opts
      ) do
    if chat_allowed?(chat_id, opts) do
      if Code.ensure_loaded?(Telegex) do
        Telegex.answer_callback_query(query.id)
      end

      case InputAdapter.translate_callback(data) do
        nil -> :ok
        event -> SessionRouter.route(chat_id, event)
      end
    else
      :ok
    end
  end

  def handle_update(%{message: %{text: text, chat: %{id: chat_id}}}, opts) when is_binary(text) do
    if chat_allowed?(chat_id, opts) do
      case InputAdapter.translate_text(text) do
        {:command, "start"} ->
          SessionRouter.start_session(chat_id)
          :ok

        {:command, "stop"} ->
          SessionRouter.stop_session(chat_id)
          :ok

        {:command, _} ->
          :ok

        nil ->
          :ok

        event ->
          SessionRouter.route(chat_id, event)
      end
    else
      :ok
    end
  end

  def handle_update(_, _opts), do: :ok

  defp chat_allowed?(_chat_id, opts) do
    case Keyword.get(opts, :allowed_chat_ids) do
      nil -> true
      ids when is_list(ids) -> Enum.member?(ids, _chat_id)
    end
  end
end
