defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

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

  setup context do
    ExBanking.Application.start()
    :ok = ExBanking.create_user(context.user1.id)
    :ok = ExBanking.create_user(context.user2.id)
    :ok = ExBanking.create_user(context.user3.id)
    :ok = ExBanking.create_user(context.user4.id)
    context

    on_exit(fn ->
      ExBanking.Application.stop()
    end)
  end

  setup %{user1: user1, user2: user2, cur1: cur1, cur2: cur2, cur3: cur3} = context do
    {:ok, balance1} = ExBanking.deposit(user1.id, 1000, cur1)
    {:ok, balance2} = ExBanking.deposit(user1.id, 10, cur2)
    {:ok, balance3} = ExBanking.deposit(user1.id, 1, cur3)

    {:ok, balance4} = ExBanking.deposit(user2.id, 99, cur2)

    context
    |> put_in([:user1, :balance, cur1], balance1)
    |> put_in([:user1, :balance, cur2], balance2)
    |> put_in([:user1, :balance, cur3], balance3)
    |> put_in([:user2, :balance, cur2], balance4)
  end

  describe "creating new user" do
    test ": with the another user's name", cnt do
      assert :user_already_exists == ExBanking.create_user(cnt.user1.id)
    end

    test ": balance on every currency is 0", %{user5: user, cur1: cur1, cur2: cur2} do
      assert :ok == ExBanking.create_user(user.id)
      assert {:ok, 0} == ExBanking.get_balance(user.id, cur1)
      assert {:ok, 0} == ExBanking.get_balance(user.id, cur2)
    end
  end

  describe "increasing user's balance" do
    test ": want to send more than 10 requests to user", cnt do
      # TODO: нагрузить большим кол-вом сообщений
      assert :too_many_requests_to_user == ExBanking.deposit(cnt.user1, 1000, cnt.cur1)
    end

    test ": want to increase on negative amount", cnt do
      assert :wrong_arguments = ExBanking.deposit(cnt.user1.id, -1000, cnt.cur1)
    end

    test ": want to increase amount not existing user", cnt do
      assert :user_does_not_exist = ExBanking.deposit(cnt.user5.id, 1000, cnt.cur1)
    end

    test ": user and USER are not the same person", cnt do
      assert :user_does_not_exist =
               ExBanking.deposit(String.uppercase(cnt.user1.id), 1000, cnt.cur1)
    end

    test ": balance depends on currency", %{user1: user, cur1: cur1, cur2: cur2, cur3: cur3} do
      assert {:ok, user[:balance][cur1] + 1000} = ExBanking.deposit(user.id, 1000, cur1)
      assert {:ok, user[:balance][cur2] + 1000} = ExBanking.deposit(user.id, 1000, cur2)
      assert {:ok, user[:balance][cur3] + 1000} = ExBanking.deposit(user.id, 1000, cur3)
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
  end

  describe "decreasing user's balance" do
    test ": want to send more than 10 requests to user", cnt do
      # TODO: нагрузить большим кол-вом сообщений
      assert :too_many_requests_to_user == ExBanking.withdraw(cnt.user1, 1000, cnt.cur1)
    end

    test ": want to decrease on negative amount", cnt do
      assert :wrong_arguments == ExBanking.withdraw(cnt.user1, -1000, cnt.cur1)
    end

    test ": want to decrease amount not existing user", cnt do
      assert :user_does_not_exist == ExBanking.withdraw(cnt.user5, 1000, cnt.cur1)
    end

    test ": user and USER are not the same person", cnt do
      assert :user_does_not_exist ==
               ExBanking.withdraw(String.uppercase(cnt.user1), 1000, cnt.cur1)
    end

    test ": balance depends on currency", %{user1: user, cur1: cur1, cur2: cur2, cur3: cur3} do
      assert {:ok, user[:balance][cur1] - 1000} = ExBanking.withdraw(user.id, 1000, cur1)
      assert {:ok, user[:balance][cur2] - 100} = ExBanking.withdraw(user.id, 100, cur2)
      assert {:ok, user[:balance][cur3] - 10} = ExBanking.withdraw(user.id, 10, cur3)
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
      assert {:ok, user1[:balance][cur] - 1000} == ExBanking.withdraw(user1.id, 1000, cur)
    end

    test ": max decreasing equal balance", %{user1: user, cur1: cur} do
      assert {:ok, 0} == ExBanking.withdraw(user.id, user[:balance][cur], cur)
      assert :not_enough_money == ExBanking.withdraw(user.id, user[:balance][cur], cur)
    end
  end

  describe "sending user's money" do
    test ": want to send more than 10 requests from one user", cnt do
      # TODO: нагрузить большим кол-вом сообщений
      assert :too_many_requests_to_sender ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, cnt.user1.balance[cnt.cur1] || 1, cur1)
    end

    test ": want to send more than 10 requests to one user", cnt do
      # TODO: нагрузить большим кол-вом сообщений
      assert :too_many_requests_to_reciever ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, cnt.user1.balance[cnt.cur1] || 1, cur1)
    end

    test ": want to send more amount then you have", cnt do
      assert :not_enough_money ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, cnt.user1.balance[cnt.cur1] || 1, cur1)
    end

    test ": want to send negative amount", cnt do
      assert :wrong_arguments == ExBanking.send(cnt.user1.id, cnt.user2.id, -1, cur1)
    end

    test ": want to send amount from not existing user to existing user", cnt do
      assert :user_does_not_exist == ExBanking.send(cnt.user5.id, cnt.user2.id, 1, cur1)
    end

    test ": want to send amount from existing user to not existing user", cnt do
      assert :user_does_not_exist == ExBanking.send(cnt.user1.id, cnt.user5.id, 1, cur1)
    end

    test ": user and USER are not the same person", cnt do
      assert :user_does_not_exist ==
               ExBanking.send(cnt.user1.id, String.uppercase(cnt.user2.id), 1, cur1)
    end

    test ": to existing user", cnt do
      assert {:ok, cnt.user1.balance[cur1] - 1, cnt.user2.balance[cur1] || 1} ==
               ExBanking.send(cnt.user1.id, cnt.user2.id, 1, cur1)
    end

    test ": balances are changed", cnt do
      assert {:ok, _, _} = ExBanking.send(cnt.user1.id, cnt.user2.id, 1, cur1)
      assert {:ok, cnt.user1.balance[cur1] || 0} == ExBanking.get_balance(cnt.user1.id, cur1)
      assert {:ok, cnt.user2.balance[cur1] || 1} == ExBanking.get_balance(cnt.user2.id, cur1)
    end
  end
end
