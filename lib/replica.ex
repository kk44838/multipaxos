# Kazuya Kai-Olowu (kyk3218)

# Set up struct with default values for various required variables
defmodule ReplicaState do
    @enforce_keys [:config, :db, :leaders]
    defstruct(
      config:    Map.new,
      db:        nil,
      decisions: Map.new,
      leaders:   [],
      proposals: Map.new,
      requests:  [],
      slot_in:      1,
      slot_out:     1,
      window_size: 100
    )
  end # ReplicaState


defmodule Replica do

    def start config, database do

    # Initialise ReplicaState with values recieved in the BIND message from multipaxos
      receive do
        { :BIND, leaders } ->
            replica_state = %ReplicaState{
                config: config,
                db: database,
                leaders: leaders,
            }

            next replica_state
      end

    end # start

    defp propose replica_state do
      w = replica_state.window_size
      
      # Check if slot_in is within the current reconfiguration window, if so, if the slot_in
      # does not have an associated value in decision, pop a command out of the requested set, and
      # send a PROPOSE message to all leaders with that command and put it into the 
      # proposals map.
      new_replica_state =
        if replica_state.slot_in < replica_state.slot_out + w and replica_state.requests != [] do

            update_state = if !Map.has_key?(replica_state.decisions, replica_state.slot_in) do
            [cmd | commands] = replica_state.requests

            for leader <- replica_state.leaders do
                Debug.send(replica_state.config, self(), leader, :PROPOSE, [replica_state.slot_in, cmd])
                send leader, { :PROPOSE, replica_state.slot_in, cmd}
            end

            # Update a replica_state with the new proposal, remove the command from requests as it has been proposed
            %{ replica_state | proposals: Map.put(replica_state.proposals, replica_state.slot_in, cmd),
            requests: commands}

            else
                replica_state
            end

            # Increment the slot_in number
            propose %{ update_state | slot_in: update_state.slot_in + 1}
        else
            replica_state
        end
      new_replica_state
    end # propose


    defp perform replica_state, command do
        # Boolean that returns true if a command is in decisions
        to_execute =
            Map.to_list(replica_state.decisions)
            |> Enum.filter(fn({ s, _ }) -> s < replica_state.slot_out end)
            |> Enum.map(fn({ _, cmd }) -> cmd end)
            |> Enum.member?(command)

        
        new_replica_state =
            if !to_execute do
                { client, id, transaction } = command

                # Send EXECUTE command to the Database with transaction in the command
                Debug.send(replica_state.config, self(), replica_state.db, :EXECUTE, transaction)
                send replica_state.db, { :EXECUTE, transaction }

                # Send CLIENT_REPLY back to client
                send client, { :CLIENT_REPLY, id, :REPLICA_RESPONSE}
                %{ replica_state | slot_out: replica_state.slot_out + 1 }
            else
                %{ replica_state | slot_out: replica_state.slot_out + 1 }
            end
        new_replica_state
    end


    defp next replica_state do
    
        receive do
        # Upon recieving a CLIENT_REQUEST, notify the monitor, then call the propose
        # function after adding the command received to the requests list.
        { :CLIENT_REQUEST, command } ->
          Debug.replica_receive(replica_state.config, self(), :CLIENT_REQUEST, [command])

          send replica_state.config.monitor, { :CLIENT_REQUEST, replica_state.config.node_num }
          next propose(%{ replica_state | requests: [command | replica_state.requests] })

        # Upon recieving a DECISION call the propose
        # function after calling adding the proposal_contains_decision 
        # with the command added to the decision map.
        { :DECISION, slot, command } ->
            Debug.replica_receive(replica_state.config, self(), :DECISION, [command])

          next propose(proposal_contains_decision(%{ replica_state | decisions: Map.put(replica_state.decisions, slot, command) }))

        unexpected ->
          Util.halt "Replica: unexpected message #{inspect unexpected}"

      end # receive

    end # next

    # Recursively call this function while the proposals map contains
    # the decision by incrementing the slot_out number.
    defp proposal_contains_decision replica_state do

        # If the slot_out is in decision and in proposals, delete the entry
        # with the slot_out number from proposals. If the command in decisions
        # with slot_out as the key is not equal to the command in proposals
        # with the same key, add the command from proposals to the head of
        # the requests list.
        new_replica_state =
        if Map.has_key? replica_state.decisions, replica_state.slot_out do
            cmd1 = Map.get(replica_state.decisions, replica_state.slot_out)

            new_replica_state =
            if Map.has_key? replica_state.proposals, replica_state.slot_out do
                cmd2 = Map.get(replica_state.proposals, replica_state.slot_out)
                proposals = Map.delete(replica_state.proposals, replica_state.slot_out)
                requests =
                    if cmd1 !== cmd2 do
                    [cmd2 | replica_state.requests]
                    else
                        replica_state.requests
                    end

                %{ replica_state | proposals: proposals, requests: requests }
            else
                replica_state
            end

            perform new_replica_state, cmd1
            proposal_contains_decision %{ new_replica_state | slot_out: new_replica_state.slot_out + 1 }
        else
            replica_state
        end

        new_replica_state

    end # proposal_contains_decision

end # Replica
