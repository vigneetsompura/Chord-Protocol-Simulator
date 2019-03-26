defmodule Worker do
    use GenServer
   
    def start(id, state) do
        name = via_tuple(id);
        GenServer.start_link(__MODULE__, state, name: name)
    end

    def init(state) do
        GenServer.cast(via_tuple(state[:fnode]),{:findsuccessor, :joinresponse, state[:id], state[:id], []})
        

        {:ok, state}
    end

    def handle_cast({:findsuccessor, type, sender, key, list},state) do
        n = state[:id]
        successor = state[:successor]
        successor = if(successor<=n) do successor + Kernel.trunc(:math.pow(2, state[:m])) else successor end
        list = list ++ [n]
        if(n == key) do
            GenServer.cast(via_tuple(sender),{type, list})
        else
            l = Enum.map(n+1..successor, fn(x) -> rem(x, Kernel.trunc(:math.pow(2,state[:m]))) end)
            if (Enum.member?(l, key)) do
                list = list ++ [rem(successor,Kernel.trunc(:math.pow(2,state[:m])))]
                GenServer.cast(via_tuple(sender),{type, list})
            else 
                delegatefindsuccessor(type, sender, key, list, state, state[:m]-1)
            end
        end
        {:noreply, state}
    end

    def delegatefindsuccessor(type, sender, key, list, state, m) do
        if(m<0) do
            GenServer.cast(via_tuple(Enum.at(state[:finger],Enum.count(state[:finger])-1)),{:findsuccessor,type, sender, key, list})
        else
            k = if(key<state[:id]) do key + Kernel.trunc(:math.pow(2, state[:m])) else key end
            kl = Enum.map(state[:id]+1..k, fn(x) -> rem(x, Kernel.trunc(:math.pow(2, state[:m]))) end)
            if(Enum.member?(kl, Enum.at(state[:finger],m)))do
                GenServer.cast(via_tuple(Enum.at(state[:finger],m)),{:findsuccessor, type, sender, key, list})
            else
                delegatefindsuccessor(type, sender, key, list, state, m-1)
            end
        end  
    end

    def handle_cast({:requestresponse, list},state) do
        state = Map.put(state, :hop, state[:hop]+Enum.count(list)-1)
        state = Map.put(state, :count, state[:count]+1)
        if(state[:count] >= state[:numRequests]) do
            GenServer.cast(via_tuple("server"), {:hopcount, state[:hop], state[:count]})
        end
        {:noreply, state}
    end

    def handle_cast({:joinresponse, list}, state) do
        state = Map.put(state, :predecessor, nil)
        state = Map.put(state, :successor, Enum.at(list, Enum.count(list)-1))
        stabilize();
        fixfinger();
        {:noreply, state}
    end

    def handle_info(:stabilize, state) do
        GenServer.cast(via_tuple(state[:successor]), {:send_predecessor, state[:id]})
        {:noreply, state}
    end

    def handle_info(:fixfingers, state) do
        GenServer.cast(via_tuple(state[:id]),{:findsuccessor, :fingerresponse, state[:id], state[:id]+Kernel.trunc(:math.pow(2, state[:next])),[]})
        {:noreply, state}
    end

    def handle_cast({:fingerresponse, list}, state) do
        finger = state[:finger]
        finger = Enum.map(Enum.with_index(finger), fn({x,y}) -> if(y == state[:next]) do Enum.at(list, Enum.count(list)-1) else x end end)
        state = Map.put(state, :finger, finger)
        state = if(state[:next]+1 >= state[:m]) do Map.put(state, :next, 0) else Map.put(state, :next, state[:next]+1) end
        fixfinger()
        {:noreply, state}
    end

    def handle_cast({:send_predecessor,id},state) do
        GenServer.cast(via_tuple(id), {:predecessorresponse, state[:predecessor]})
        {:noreply, state}
    end

    def handle_cast({:predecessorresponse, predecessor},state) do
        n = state[:id]
        successor = state[:successor]
        successor = if(successor<=n) do successor + Kernel.trunc(:math.pow(2, state[:m])) else successor end
        l = Enum.map(n+1..successor-1, fn(x) -> rem(x, Kernel.trunc(:math.pow(2, state[:m]))) end)
        state = if(Enum.member?(l, predecessor)) do Map.put(state, :successor, predecessor) else Map.put(state, :successor, state[:successor]) end
        GenServer.cast(via_tuple(state[:successor]),{:denewpredecessor, state[:id]})
        stabilize()
        {:noreply, state}
    end

    def handle_cast({:newpredecessor, id}, state) do
        predecessor = state[:predecessor]
        n = state[:id]
        state = if (predecessor == nil) do
            Map.put(state, :predecessor, id)
            else
                n = if(n<predecessor) do n + Kernel.trunc(:math.pow(2, state[:m])) else n end
                nl = Enum.map(predecessor+1..n-1, fn(x)-> rem(x, Kernel.trunc(:math.pow(2, state[:m])))end)
                if(Enum.member?(nl, id)) do
                    Map.put(state, :predecessor, id)
                else
                    state
                end
        end

        {:noreply, state}
    end

    defp stabilize() do
        Process.send_after(self(), :stabilize, 50)
    end

    defp fixfinger() do
        Process.send_after(self(), :fixfingers, 50)
    end

    defp via_tuple(id) do
        {:via, Registry, {:process_registry, id}}
    end
end