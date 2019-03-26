defmodule Test do
    use GenServer
    def start do
        GenServer.start_link(__MODULE__, %{})
    end

    def init(state) do
        schedule_t2()
        schedule_t1()
        {:ok, state}
    end

    def handle_info(:t1, state) do
        IO.puts "1"
        schedule_t1()
        {:noreply, state}
    end

    def handle_info(:t2, state) do
        IO.puts "2"
        schedule_t2()
        {:noreply, state}
    end

    defp schedule_t1() do
        Process.send_after(self(), :t1, 500)
    end

    defp schedule_t2() do
        Process.send_after(self(), :t2, 5000)
    end
end

Test.start