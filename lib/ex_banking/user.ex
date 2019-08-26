defmodule ExBanking.User do
  use GenServer
  # providing 2 decimal precision of money amount for any currency
  @decimals 2
  @message_box_size 10

  def transaction(pid, {oper, args}) do
    {:message_queue_len, message_box} = :erlang.process_info(pid, :message_queue_len)
    if message_box < @message_box_size do
      GenServer.call(pid, {oper, args})
    else
      case oper do
        :send -> :too_many_requests_to_sender
        :receive -> :too_many_requests_to_receiver
        _else -> :too_many_requests_to_user
      end
    end
  end

  # -------------------- Internal

  def start_link(name), do: GenServer.start_link(__MODULE__, [], name: String.to_atom(name))

  def init([]) do
    {:ok, %{}}
  end

  def handle_call({oper, [amount, currency]}, _from, state) when oper in [:increase, :receive] do
    actual_balance = state[currency] || 0
    new_balance = prepare_balance(actual_balance + amount)

    {:reply, {:ok, new_balance}, put_in(state[currency], new_balance)}
  end

  def handle_call({:decrease, [amount, currency]}, _from, state) do
    actual_balance = state[currency] || 0

    if state[currency] < amount do
      {:reply, :not_enough_money, state}
    else
      new_balance = prepare_balance(actual_balance - amount)
      {:reply, {:ok, new_balance}, put_in(state[currency], new_balance)}
    end
  end

  def handle_call({:get, [_, currency]}, _from, state),
    do: {:reply, {:ok, state[currency] || 0}, state}

  def handle_call({:send, [to_user, amount, cur]}, _from, state) do
    with {:enough_money, true} <- {:enough_money, state[cur] != nil and state[cur] >= amount},
         {:ok, new_receiver_balance} <- transaction(to_user, {:receive, [amount, cur]}) do
      new_balance = prepare_balance(state[cur] - amount)
      {:reply, {:ok, new_balance, new_receiver_balance}, put_in(state[cur], new_balance)}
    else
      {:enough_money, false} -> {:reply, :not_enough_money, state}
      e -> {:reply, e, state}
    end
  end
  def handle_call(_, _, state), do: {:reply, nil, state}
  def handle_cast(:long_duration_request, state) do
    :timer.sleep(150)
    {:noreply, state}
  end
  def handle_cast(_, state), do: {:noreply, state}
  def handle_info(_, state), do: {:noreply, state}

  defp prepare_balance(balance) when is_float(balance), do: Float.round(balance, @decimals)
  defp prepare_balance(balance) when is_integer(balance), do: prepare_balance(balance * 1.0)

end
