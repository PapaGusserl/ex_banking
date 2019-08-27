defmodule ExBanking do
  alias ExBanking.{User, UserManager}

  @moduledoc """
  Documentation for ExBanking.
  """
  @type banking_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists
           | :user_does_not_exist
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_user
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  @doc """
  Function creates new user in the system
  """
  @spec create_user(user :: String.t()) :: :ok | banking_error
  def create_user(user) when is_binary(user), do: UserManager.create(user)
  def create_user(_), do: {:error, :wrong_arguments}

  @doc """
  Increases user's balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency), do: request(:increase, user, amount, currency)

  @doc """
  Decreases user's balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency), do: request(:decrease, user, amount, currency)

  @doc """
  Returns balance of the user in given format
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number} | banking_error
  def get_balance(user, currency), do: request(:get, user, 0, currency)

  @doc """
  Decreases from_user's balance in given currency by amount value
  Increases to_user's balance in given currency by amount value
  Returns balance of from_user and to_user in given format
  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(from_user, to_user, amount, currency)
    when is_binary(from_user)
     and is_binary(to_user)
     and is_binary(currency)
     and is_number(amount) and amount >= 0
  do
    with {:ok, from_pid} <- UserManager.get_pid(from_user),
         {:ok, to_pid} <- UserManager.get_pid(to_user) do
      User.transaction(from_pid, {:send, [to_pid, amount, currency]})
    else
      {:error, {:user_does_not_exist, ^from_user}} -> {:error, :sender_does_not_exist}
      {:error, {:user_does_not_exist, ^to_user}} -> {:error, :receiver_does_not_exist}
    end
  end

  def send(_, _, _, _), do: {:error, :wrong_arguments}

  defp request(oper, user, amount, currency)
    when is_binary(user) and is_binary(currency) and is_number(amount) and amount >= 0
  do
    case UserManager.get_pid(user) do
      {:ok, pid} -> User.transaction(pid, {oper, [amount, currency]})
      _ -> {:error, :user_does_not_exist}
    end
  end

  defp request(_, _, _, _), do: {:error, :wrong_arguments}
end
