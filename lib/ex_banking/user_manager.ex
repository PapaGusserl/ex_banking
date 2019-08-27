defmodule ExBanking.UserManager do
  use Supervisor
  @moduledoc "Module supervises User's profiles"

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    opts = [strategy: :one_for_one, name: __MODULE__]
    supervise([], opts)
  end

  @doc "Create user"
  @spec create(user :: String.t()) :: :ok
  def create(user) do
    {:ok, _} = Supervisor.start_child(__MODULE__, user_spec(user))
    :ok
  end

  @doc "Checks user's existing"
  @spec exists?(user :: String.t()) :: boolean
  def exists?(user) do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.any?(fn {id, _, _, _} -> id == user end)
  end

  @doc "Return user's pid"
  @spec get_pid(user :: String.t()) :: {:ok, pid} | {:error, :id_not_exist}
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
