defmodule ExBankingTest do
  use ExUnit.Case
  require Logger

  setup_all do
    %{
      user1: %{id: "John", balance: %{}},
      user2: %{id: "Paul", balance: %{}},
      user3: %{id: "George", balance: %{}},
      user4: %{id: "Ringo", balance: %{}},
      user5: %{id: "Yoko"},
      cur1: "rub",
      cur2: "eur",
      cur3: "usd"
    }
  end

  setup %{user1: user1, user2: user2, user3: user3, user4: user4, cur1: cur1, cur2: cur2, cur3: cur3} = context do
    Application.start(:ex_banking)
    on_exit(fn ->
      Application.stop(:ex_banking)
    end)
    Logger.info("Application :ex_banking started")
    :ok = ExBanking.create_user(user1.id)
    :ok = ExBanking.create_user(user2.id)
    :ok = ExBanking.create_user(user3.id)
    :ok = ExBanking.create_user(user4.id)

    {:ok, balance1} = ExBanking.deposit(user1.id, 1000, cur1)
    {:ok, balance2} = ExBanking.deposit(user1.id, 100, cur2)
    {:ok, balance3} = ExBanking.deposit(user1.id, 10, cur3)

    {:ok, balance4} = ExBanking.deposit(user2.id, 99, cur2)

    context
    |> put_in([:user1, :balance, cur1], balance1)
    |> put_in([:user1, :balance, cur2], balance2)
    |> put_in([:user1, :balance, cur3], balance3)
    |> put_in([:user2, :balance, cur2], balance4)
  end

  describe "creating new user" do
    test ": with the another user's name", cnt do
      assert {:error, :user_already_exists} == ExBanking.create_user(cnt.user1.id)
    end

    test ": balance on every currency is 0", %{user5: user, cur1: cur1, cur2: cur2} do
      assert :ok == ExBanking.create_user(user.id)
      assert {:ok, 0} == ExBanking.get_balance(user.id, cur1)
      assert {:ok, 0} == ExBanking.get_balance(user.id, cur2)
    end

    test ": race condition", %{user5: %{id: user}} do
      assert 1 == Task.async_stream([user, user, user, user], fn(user) ->
        ExBanking.create_user(user)
      end)
      |> Enum.map(fn
        {:ok, :ok} -> 1
        {:ok, {:error, :user_already_exists}} -> 0
      end)
      |> Enum.sum()
    end
  end

  describe "increasing user's balance" do
    @tag :too_many_requests
    test ": want to send more than 10 requests to user", %{user1: user} = cnt do
      make_too_many_requests_to(user.id)
      assert {:error, :too_many_requests_to_user} == ExBanking.deposit(user.id, 1000, cnt.cur1)
      # за это время все таски должны быть завершены
      :timer.sleep(5000)
      assert {:ok, _} = ExBanking.deposit(user.id, 1000, cnt.cur1)
    end

    test ": want to increase on negative amount", cnt do
      assert {:error, :wrong_arguments} = ExBanking.deposit(cnt.user1.id, -1000, cnt.cur1)
    end

    test ": want to increase amount not existing user", cnt do
      assert {:error, :user_does_not_exist} = ExBanking.deposit(cnt.user5.id, 1000, cnt.cur1)
    end

    test ": user and USER are not the same person", cnt do
      assert {:error, :user_does_not_exist} = ExBanking.deposit(String.upcase(cnt.user1.id), 1000, cnt.cur1)
    end

    test ": balance depends on currency", %{user1: user, cur1: cur1, cur2: cur2, cur3: cur3} do
      assert {:ok, user[:balance][cur1] + 1000} == ExBanking.deposit(user.id, 1000, cur1)
      assert {:ok, user[:balance][cur2] + 1000} == ExBanking.deposit(user.id, 1000, cur2)
      assert {:ok, user[:balance][cur3] + 1000} == ExBanking.deposit(user.id, 1000, cur3)
    end

    test ": balance would be increased", %{user1: user, cur1: cur} do
      assert {:ok, user[:balance][cur]} == ExBanking.get_balance(user.id, cur)
      ExBanking.deposit(user.id, 1000, cur)
      assert {:ok, user[:balance][cur] + 1000} == ExBanking.get_balance(user.id, cur)
    end

    test ": returns actual balance", %{user1: user, cur1: cur} do
      result = ExBanking.deposit(user.id, 1000, cur)
      assert result == ExBanking.get_balance(user.id, cur)
    end

    test ": increase balance of one user isn't mean increasing balance of another user", %{
      user1: user1,
      user2: user2,
      cur2: cur
    } do
      assert {:ok, user2[:balance][cur] + 1} == ExBanking.deposit(user2.id, 1, cur)
      assert {:ok, user1[:balance][cur] + 1000} == ExBanking.deposit(user1.id, 1000, cur)
    end

    test ": providing 2 decimals", %{user1: user, cur3: cur} do
      actual_balance = user[:balance][cur] || 0
      ExBanking.deposit(user.id, 11.3, cur)
      ExBanking.deposit(user.id, 11.3333333333, cur)
      ExBanking.deposit(user.id, 11.143333, cur)
      ExBanking.deposit(user.id, 11.743333, cur)

      assert {:ok, actual_balance + 11.30 + 11.33 + 11.14 + 11.74 + 11.78} ==
               ExBanking.deposit(user.id, 11.776336, cur)
    end

    test "RUB and rub are differrent currency", %{cur1: cur, user1: user} do
      assert {:ok, user.balance[cur] + 10} == ExBanking.deposit(user.id, 10, cur)
      assert {:ok, 10} == ExBanking.deposit(user.id, 10, String.upcase(cur))
    end
  end

  describe "decreasing user's balance" do
    @tag :too_many_requests
    test ": want to send more than 10 requests to user", %{user1: user} = cnt do
      make_too_many_requests_to(user.id)
      assert {:error, :too_many_requests_to_user} == ExBanking.withdraw(user.id, 1000, cnt.cur1)
    end

    test ": want to decrease on negative amount", cnt do
      assert {:error, :wrong_arguments} == ExBanking.withdraw(cnt.user1.id, -1000, cnt.cur1)
    end

    test ": want to decrease amount not existing user", cnt do
      assert {:error, :user_does_not_exist} == ExBanking.withdraw(cnt.user5.id, 1000, cnt.cur1)
    end

    test ": user and USER are not the same person", cnt do
      assert {:error, :user_does_not_exist} ==
               ExBanking.withdraw(String.upcase(cnt.user1.id), 1000, cnt.cur1)
    end

    test ": balance depends on currency", %{user1: user, cur1: cur1, cur2: cur2, cur3: cur3} do
      assert {:ok, user[:balance][cur1] - 1000} == ExBanking.withdraw(user.id, 1000, cur1)
      assert {:ok, user[:balance][cur2] - 100} == ExBanking.withdraw(user.id, 100, cur2)
      assert {:ok, user[:balance][cur3] - 10} == ExBanking.withdraw(user.id, 10, cur3)
    end

    test ": balance would be decreased", %{user1: user, cur1: cur} do
      assert {:ok, user[:balance][cur]} == ExBanking.get_balance(user.id, cur)
      ExBanking.withdraw(user.id, 100, cur)
      assert {:ok, user[:balance][cur] - 100} == ExBanking.get_balance(user.id, cur)
    end

    test ": returns actual balance", %{user1: user, cur1: cur} do
      result = ExBanking.withdraw(user.id, 1000, cur)
      assert result == ExBanking.get_balance(user.id, cur)
    end

    test ": decrease balance of one user isn't mean decreasing balance of another user", %{
      user1: user1,
      user2: user2,
      cur2: cur
    } do
      assert {:ok, user2[:balance][cur] - 1} == ExBanking.withdraw(user2.id, 1, cur)
      assert {:ok, user1[:balance][cur] - 10} == ExBanking.withdraw(user1.id, 10, cur)
    end

    test ": max decreasing equal balance", %{user1: user, cur1: cur} do
      assert {:ok, 0} == ExBanking.withdraw(user.id, user[:balance][cur], cur)
      assert {:error, :not_enough_money} == ExBanking.withdraw(user.id, user[:balance][cur], cur)
    end

    test ": providing 2 decimals", %{user1: user, cur1: cur} do
      actual_balance = user[:balance][cur]
      ExBanking.withdraw(user.id, 11.3, cur)
      ExBanking.withdraw(user.id, 11.3333333333, cur)
      ExBanking.withdraw(user.id, 11.143333, cur)
      ExBanking.withdraw(user.id, 11.743333, cur)

      assert {:ok, actual_balance - 11.30 - 11.33 - 11.14 - 11.74 - 11.78} ==
               ExBanking.withdraw(user.id, 11.776336, cur)
    end
  end

  describe "sending user's money" do
    @tag :too_many_requests
    test ": want to send more than 10 requests to sender", cnt do
      make_too_many_requests_to(cnt.user1.id)

      assert {:error, :too_many_requests_to_sender} ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, cnt.user1.balance[cnt.cur1], cnt.cur1)
    end

    @tag :too_many_requests
    test ": want to send more than 10 requests to reciever", cnt do
      make_too_many_requests_to(cnt.user2.id)

      assert {:error, :too_many_requests_to_receiver} ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, cnt.user1.balance[cnt.cur1], cnt.cur1)
    end

    test ": want to send more amount then you have", cnt do
      assert {:error, :not_enough_money} ==
               ExBanking.send(
                 cnt.user1.id,
                 cnt.user2.id,
                 cnt.user1.balance[cnt.cur1] + 1,
                 cnt.cur1
               )
    end

    test ": want to send negative amount", cnt do
      assert {:error, :wrong_arguments} == ExBanking.send(cnt.user1.id, cnt.user2.id, -1, cnt.cur1)
    end

    test ": want to send amount from not existing user to existing user", cnt do
      assert {:error, :sender_does_not_exist} == ExBanking.send(cnt.user5.id, cnt.user2.id, 1, cnt.cur1)
    end

    test ": want to send amount from existing user to not existing user", cnt do
      assert {:error, :receiver_does_not_exist} == ExBanking.send(cnt.user1.id, cnt.user5.id, 1, cnt.cur1)
    end

    test ": want to send amount to self", %{user1: user, cur1: cur} do
      assert {:ok, user[:balance][cur], user[:balance][cur]} == ExBanking.send(user.id, user.id, 1, cur)
    end

    test ": user and USER are not the same person", cnt do
      assert {:error, :receiver_does_not_exist} ==
               ExBanking.send(cnt.user1.id, String.upcase(cnt.user2.id), 1, cnt.cur1)
    end

    test ": to existing user", cnt do
      assert {:ok, cnt.user1.balance[cnt.cur1] - 1, cnt.user2.balance[cnt.cur1] || 1} ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, 1, cnt.cur1)
    end

    test ": balances are changed", cnt do
      assert {:ok, _, _} = ExBanking.send(cnt.user1.id, cnt.user2.id, 1, cnt.cur1)

      assert {:ok, cnt.user1.balance[cnt.cur1] - 1} ==
               ExBanking.get_balance(cnt.user1.id, cnt.cur1)

      assert {:ok, cnt.user2.balance[cnt.cur1] || 1} ==
               ExBanking.get_balance(cnt.user2.id, cnt.cur1)
    end

    test ": providing 2 decimals", %{user1: user1, user2: user2, cur1: cur} do
      actual_balance1 = user1[:balance][cur]
      actual_balance2 = user2[:balance][cur] || 0
      {:ok, _, _} = ExBanking.send(user1.id, user2.id, 11.3, cur)
      {:ok, _, _} = ExBanking.send(user2.id, user1.id, 10.3333333333, cur)
      {:ok, _, _} = ExBanking.send(user1.id, user2.id, 12.143333, cur)
      {:ok, _, _} = ExBanking.send(user2.id, user1.id, 10.743333, cur)
      {:ok, new_balance1, new_balance2} = ExBanking.send(user1.id, user2.id, 12.776335, cur)

      assert Float.round(actual_balance1 - 11.30 + 10.33 - 12.14 + 10.74 - 12.78, 2) ==
               new_balance1

      assert Float.round(actual_balance2 + 11.30 - 10.33 + 12.14 - 10.74 + 12.78, 2) ==
               new_balance2
    end
  end

  describe "Other" do
    test ":send stange requests", %{user2: user} do
      {:ok, pid} = ExBanking.UserManager.get_pid(user.id)
      nil = GenServer.call(pid, :stranger)
    end

    test ": user wouldn't fail with a lot of queries", %{user1: user} = cnt do
      {:ok, _} = ExBanking.deposit(user.id, 1000, "bitcoin")
      make_too_many_requests_to(user.id)
      assert request_loop(fn -> ExBanking.send(user.id, cnt.user2.id, 400, "bitcoin") end)
    end
  end

  defp make_too_many_requests_to(user) do
    {:ok, pid} = ExBanking.UserManager.get_pid(user)

    Enum.each(1..15, fn _ ->
      GenServer.cast(pid, :long_duration_request)
    end)
  end

  defp request_loop(fun) do
    case fun.() do
      {:error, _} ->
        request_loop(fun)
      _ -> true
    end
  end
end
