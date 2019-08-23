defmodule ExBanking.User do
  use GenServer

  def transaction(pid, {oper, args}) do
    if :erlang.process_info(pid, :message_queue_len) <= 10 do
      GenServer.call(pid, {oper, args})
    else
      if oper == :send, do: :too_many_requests_to_sender, else: :too_many_requests_to_user
    end
  end

  # -------------------- Internal

  def start_link(name), do: GenServer.start_link(__MODULE__, [], name: name)

  def init([]) do
    {:ok, %{}}
  end

  def handle_call({:increase, [amount, currency]}, _from, state) do
    actual_balance = state[currency] || 0
    new_balance = actual_balance + amount

    {:reply, {:ok, new_balance}, put_in(state[currency], new_balance)}
  end

  def handle_call({:decrease, [amount, currency]}, _from, state) do
    actual_balance = state[currency] || 0
    new_balance = actual_balance - amount

    if new_balance < 0 do
      {:reply, :not_enough_money, state}
    else
      {:reply, {:ok, new_balance}, put_in(state[currency], new_balance)}
    end
  end

  def handle_call({:get, [_, currency]}, _from, state),
    do: {:reply, {:ok, state[currency] || 0}, state}

  def handle_call({:send, [to_user, amount, currency]}, _from, state) do
    {:reply, {:ok, new_self_balance, new_to_balance}, new_state}
  end
end
