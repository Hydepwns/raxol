defmodule Raxol.Policy do
  @moduledoc """
  Policy definition framework for Raxol.

  Provides a DSL for defining resource-based access control policies.

  ## Example

      defmodule DocumentPolicy do
        use Raxol.Policy

        def can?(:read, user, document) do
          document.owner_id == user.id or
          user.role == :admin or
          document.public?
        end

        def can?(:write, user, document) do
          document.owner_id == user.id and
          not document.locked?
        end
      end

      # Usage
      if DocumentPolicy.can?(:read, user, document) do
        show_document(document)
      end
  """

  @doc """
  Use this module to define a policy.

  ## Example

      defmodule MyPolicy do
        use Raxol.Policy

        def can?(:read, user, resource) do
          # Your authorization logic
          true
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Policy

      @doc """
      Check if an action is allowed.

      Override this function to implement your authorization logic.
      """
      def can?(_action, _user, _resource), do: false

      defoverridable can?: 3
    end
  end

  @doc """
  Callback for checking if an action is allowed.
  """
  @callback can?(action :: atom(), user :: map(), resource :: any()) ::
              boolean()

  @doc """
  Authorize an action, raising if not allowed.

  ## Example

      Raxol.Policy.authorize!(MyPolicy, :read, user, resource)
  """
  @spec authorize!(module(), atom(), map(), any()) :: :ok | no_return()
  def authorize!(policy, action, user, resource) do
    if policy.can?(action, user, resource) do
      :ok
    else
      raise Raxol.Policy.UnauthorizedError,
        action: action,
        user: user,
        resource: resource
    end
  end

  @doc """
  Authorize an action, returning a result tuple.

  ## Example

      case Raxol.Policy.authorize(MyPolicy, :read, user, resource) do
        :ok -> show_resource(resource)
        {:error, :unauthorized} -> show_error()
      end
  """
  @spec authorize(module(), atom(), map(), any()) ::
          :ok | {:error, :unauthorized}
  def authorize(policy, action, user, resource) do
    if policy.can?(action, user, resource) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Filter a list of resources to only those the user can access.

  ## Example

      readable_docs = Raxol.Policy.filter(DocumentPolicy, :read, user, documents)
  """
  @spec filter(module(), atom(), map(), list()) :: list()
  def filter(policy, action, user, resources) when is_list(resources) do
    Enum.filter(resources, &policy.can?(action, user, &1))
  end
end

defmodule Raxol.Policy.UnauthorizedError do
  @moduledoc """
  Exception raised when authorization fails.
  """

  defexception [:action, :user, :resource, :message]

  @impl true
  def exception(opts) do
    action = Keyword.get(opts, :action)
    user = Keyword.get(opts, :user)
    resource = Keyword.get(opts, :resource)

    message =
      "Unauthorized: #{inspect(user)} cannot #{action} #{inspect(resource)}"

    %__MODULE__{
      action: action,
      user: user,
      resource: resource,
      message: message
    }
  end
end
