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
  def create_user(user) do
    with {:user_name_valid, true} <- {:user_name_valid, is_binary(user)},
         {:user_exists, false} <- {:user_not_exist, UserManager.exists?(user)} do
      UserManager.create(user)
    else
      {:user_name_valid, false} -> :wrong_arguments
      {:user_exists, true} -> :user_already_exists
    end
  end

  @doc """
  Increases user's balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency), do: transaction(:increase, user, amount, currency)

  @doc """
  Decreases user's balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency), do: transaction(:decrease, user, amount, currency)

  @doc """
  Returns balance of the user in given format
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number} | banking_error
  def get_balance(user, currency), do: transaction(:get, user, 0, currency)

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
  def send(from_user, to_user, amount, currency) do
    with {:param_valid, true} <- {:param_valid, is_binary(from_user)},
         {:param_valid, true} <- {:param_valid, is_binary(to_user)},
         # TODO: решить проблему с сотыми
         {:param_valid, true} <- {:param_valid, is_number(amount) and amount >= 0},
         {:param_valid, true} <- {:param_valid, is_binary(currency)},
         {:ok, from_pid} <- UserManager.get_pid(from_user)
         {:ok, to_pid}   <- UserManager.get_pid(to_user)
    do
      User.transaction(from_pid, {:send, [to_pid, amount, currency]})
    else
      {:param_valid, false} -> :wrong_arguments
      {:error, _} -> :user_not_exist
    end
  end

  defp transaction(oper, user, amount, currency) do
    with {:param_valid, true} <- {:param_valid, is_binary(user)},
         # TODO: решить проблему с сотыми
         {:param_valid, true} <- {:param_valid, is_number(amount) and amount >= 0},
         {:param_valid, true} <- {:param_valid, is_binary(currency)},
         {:ok, pid} <- UserManager.get_pid(user) do
      User.transaction(pid, {oper, [amount, currency]})
    else
      {:param_valid, false} -> :wrong_arguments
      {:error, _} -> :user_not_exist
    end
  end
end
