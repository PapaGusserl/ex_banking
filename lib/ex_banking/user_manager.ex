defmodule ExBanking.UserManager do
  use Supervisor
  @moduledoc "Module supervises User's profiles"

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init([], opts)
  end

  @doc "Create user"
  @spec create(user :: String.t()) :: :ok | {:error, :user_already_exists}
  def create(user) do
    case Supervisor.start_child(__MODULE__, user_spec(user)) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> {:error, :user_already_exists}
    end
  end

  @doc "Return user's pid"
  @spec get_pid(user :: String.t()) :: {:ok, pid} | {:error, {:user_does_not_exist, user :: String.t}}
  def get_pid(user) do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.find(fn {id, _, _, _} -> id == user end)
    |> case do
      {_, pid, _, _} -> {:ok, pid}
      nil -> {:error, {:user_does_not_exist, user}}
    end
  end

  defp user_spec(id) do
    %{
      id: id,
      start: {ExBanking.User, :start_link, [id]},
      restart: :transient,
      type: :worker
    }
  end
end
