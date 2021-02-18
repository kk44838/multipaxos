# Kazuya Kai-Olowu (kyk3218)

# Set up struct with default values for various required variables
defmodule LeaderState do
    @enforce_keys [:config, :acceptors, :replicas, :ballot_num]
    defstruct(
      config:    Map.new,
      acceptors: nil,
      replicas: nil,
      ballot_num: nil,
      active: false,
      proposals: Map.new,
      sleep_time: 500,
      sleep_time_multiplier: 1.5,
      sleep_time_subtract: 500
    )
  end # LeaderState

defmodule Leader do

    def start config do
      # Initialise ballot number
      ballot_num = { 0, self() }

      receive do
        # Initialise LeaderState with values recieved in the BIND message from multipaxos
        { :BIND, acceptors, replicas } ->
            leader_state = %LeaderState{
                config: config,
                acceptors: acceptors,
                replicas: replicas,
                ballot_num: ballot_num
            }
            
            # Spawn Scouts, and notify the Monitor
            send config.monitor, { :SCOUT_SPAWNED, config.node_num }
            scout = spawn Scout, :start, [config, self(), acceptors, ballot_num]
            Debug.starting_process(config, :SCOUT, scout, :LEADER, self())

            next leader_state
      end

    end # start

    defp next leader_state do

        receive do
        # Receive PROPOSE message from a Replica process
        { :PROPOSE, s, c } ->
          Debug.leader_receive(leader_state.config, leader_state.config.node_num, :PROPOSE, [s, c])
          
          # If our proposals map does not contain an entry for the slot number in the received PROPOSE message,
          # if the leader is in an active state, spawn Commanders (notifying the Monitor), then
          # add to the proposal map the command received with the slot number as the key.
          new_leader_state =
            if !Map.has_key? leader_state.proposals, s do
                if leader_state.active do
                    send leader_state.config.monitor, { :COMMANDER_SPAWNED, leader_state.config.node_num}
                    commander = spawn Commander, :start, [leader_state.config, self(), leader_state.acceptors, leader_state.replicas, {leader_state.ballot_num, s, c}]
                    Debug.starting_process(leader_state.config, :COMMANDER, commander, :LEADER, self())
                end

                %{ leader_state | proposals: Map.put(leader_state.proposals, s, c)}
            else
              leader_state
            end
          next new_leader_state
        
        # Receive ADOPTED message from a Scout process
        { :ADOPTED, b, pvalues } ->
            Debug.leader_receive(leader_state.config, leader_state.config.node_num, :ADOPTED, [b, pvalues])

            # If using the exponential backoff strategy, update the sleep_time as required
            new_sleep_time =
              if leader_state.config.leader_election == :exponential_backoff and leader_state.sleep_time > leader_state.sleep_time_subtract do
                leader_state.sleep_time - leader_state.sleep_time_subtract
              else
                leader_state.sleep_time
              end

            leader_state = %{ leader_state | sleep_time: new_sleep_time}
            
            
            new_leader_state =
              if leader_state.ballot_num == b do
                # If the current ballot number is equal to the one received, update propsals as follows.
                # First convert the set of tuples into a map using the slot number as a key. 
                pmap = Enum.group_by(pvalues, fn {_, s, _} -> s end, fn {b, _, c} -> {b, c} end)
                
                # For each slot number, only keep the ballot number-command pair with the highest ballot number
                pmap_max = Enum.map(pmap,
                  fn {s, v} ->
                    {s, Enum.reduce(v, fn {b1, c1}, {b2, c2} -> if b1 > b2 do {b1, c1} else {b2, c2} end end)}
                  end
                )
                
                # Remove the ballot number from the values for each key
                pmap_max = Enum.map(pmap_max,
                  fn {s, {_, c}} ->
                    {s, c}
                  end
                )
                
                # Convert from key-value list to a map
                pmap_max = Enum.into(pmap_max, %{})
                
                # Merge map of new proposals into old proposals map
                new_proposals = Map.merge(pmap_max, leader_state.proposals, fn _, c, _ -> c end)
                
                # For every proposal, spawn a Commander for that command (also Notify the Monitor)
                for { s, c } <- Map.to_list(new_proposals) do
                    send leader_state.config.monitor, { :COMMANDER_SPAWNED, leader_state.config.node_num}
                    commander = spawn Commander, :start, [leader_state.config, self(), leader_state.acceptors, leader_state.replicas, {leader_state.ballot_num, s, c}]
                    Debug.starting_process(leader_state.config, :COMMANDER, commander, :LEADER, self())
                end
                # Update proposals in the state
                %{ leader_state | proposals: new_proposals}
              else
                  leader_state
              end
            
            # Make the leader active
            next %{ new_leader_state | active: true }
        
        # Receive PREEMPTED message from a Scout or Commander process
        { :PREEMPTED, b} ->
          Debug.leader_receive(leader_state.config,  leader_state.config.node_num, :PREEMPTED, [b, leader_state.ballot_num])
          {r_num, msg_leader_id} = b

          # If using the bully algorithm with exponential backoff, update sleep_time as required.
          leader_state =
            if leader_state.config.leader_election == :exponential_bully_backoff and msg_leader_id > self() do
              sleep_time = leader_state.sleep_time * leader_state.sleep_time_multiplier
              Process.sleep(trunc leader_state.sleep_time)

              send leader_state.config.monitor, { :SERVER_SLEEP, leader_state.config.node_num, sleep_time}

              %LeaderState{ leader_state | sleep_time: sleep_time}
            else
              leader_state
            end
          
          # If the ballot number received is greater than current ballot number, set current ballot number
          # to one greater than that received. 
          new_leader_state =
            if b > leader_state.ballot_num do
                new_leader_state = %{ leader_state | ballot_num: {r_num + 1, self()}}

                # Implementation of Livelocking solutions
                new_leader_state =
                  case new_leader_state.config.leader_election do
                    # Random backoff
                    :randomised_backoff ->
                      sleep_time = Enum.random(1000 .. 3000)
                      Process.sleep(sleep_time)
                      send new_leader_state.config.monitor, { :SERVER_SLEEP, new_leader_state.config.node_num, sleep_time}
                      %LeaderState{ new_leader_state | sleep_time: sleep_time}

                    # Exponential backoff
                    :exponential_backoff ->
                      sleep_time = new_leader_state.sleep_time * new_leader_state.sleep_time_multiplier
                      Process.sleep(trunc new_leader_state.sleep_time)
                      send new_leader_state.config.monitor, { :SERVER_SLEEP, new_leader_state.config.node_num, sleep_time}
                      %LeaderState{ new_leader_state | sleep_time: sleep_time}

                    # No strategy
                    _ ->
                      new_leader_state
                  end
                
                  # Spawn Scouts with new ballot number and notify Monitor
                send new_leader_state.config.monitor, { :SCOUT_SPAWNED, new_leader_state.config.node_num }
                scout = spawn Scout, :start, [new_leader_state.config, self(), new_leader_state.acceptors, new_leader_state.ballot_num]

                Debug.starting_process(new_leader_state.config, :SCOUT, scout, :LEADER, self())

              # Make the leader inactive
              %{ new_leader_state | active: false}
            else

              leader_state
            end

          next new_leader_state

        unexpected ->
          Util.halt "Leader: unexpected message #{inspect unexpected}"

      end # receive

    end # next

end # Leader
