defmodule Server do
    use GenServer
    def start(main, numNodes, numRequests) do
        App.start()
        m = Kernel.trunc(:math.log2(numNodes)) + Kernel.trunc(:math.log2(numRequests)) + 3
        state = %{:main => main, :numNodes => numNodes, :numRequests => numRequests, :m => m, :hops => 0, :count => 0}
        GenServer.start_link(__MODULE__, state, name: via_tuple("server"))
    end

    def init(state) do
        numNodes = state[:numNodes]
        numRequests = state[:numRequests]
        m = state[:m]

        nodes = Enum.uniq(Enum.sort(Enum.map(0..numNodes-1, fn(_) -> 
            rem(:binary.decode_unsigned(:crypto.hash(:sha, Integer.to_string(:rand.uniform(16777214)))), Kernel.trunc(:math.pow(2,m)))
        end)))

        firstNode = Enum.at(nodes, 0)

        for id <- nodes do
            finger = Enum.map(0..m-1, fn(_) -> id end)
            wState = %{:id => id, :fnode => firstNode, :predecessor => nil, :successor => id, :finger => finger, :hop => 0, :count => 0, :m => m, :next => 0, :numRequests => numRequests}
            Worker.start(id, wState)
        end
        state = Map.put(state, :numNodes, Enum.count(nodes))
        {:ok, state}
    end

    defp via_tuple(id) do
        {:via, Registry, {:process_registry, id}}
    end
end