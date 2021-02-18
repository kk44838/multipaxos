# Kazuya Kai-Olowu (kyk3218)
defmodule Debug do

def info(config, message, verbose \\ 1) do
  if config.debug_level >= verbose do IO.puts message end
end # log

def map(config, themap, verbose \\ 0) do
  if config.debug_level >= verbose do
    Enum.each(themap, fn ({key, value}) -> IO.puts "  #{key} #{inspect value}" end)
  end
end # map

def starting(config, verbose \\ 0) do
  if config.debug_level >= verbose do
    IO.puts   "--> Starting #{config.node_name} at #{config.node_location}"
  end
end # starting

def letter(config, letter, verbose \\ 3) do
  if config.debug_level >= verbose do IO.write letter end
end # letter

def mapstring(map) do
  for {key  , value} <- map, into: "" do "\n  #{key}\t #{inspect value}" end
end # mapstr  ing

def starting_process(config, process_name, id, parent, parent_id, verbose \\ 4) do
  if config.debug_level >= verbose do
    IO.puts "Starting #{process_name} with ID: #{inspect(id)} started by #{parent} with ID: #{inspect(parent_id)}."
  end
end

def exiting_process(config, process_name, id, verbose \\ 4) do
  if config.debug_level >= verbose do
    IO.puts "Exiting #{process_name} with ID: #{inspect(id)}."
  end
end


def acceptor_receive(config, id, type, leader, b, verbose \\ 2) do
  if config.debug_level >= verbose do
    IO.puts "Acceptor #{inspect(id)} received #{type} from leader #{inspect(leader)} with ballot_num #{inspect(b)}."
  end
end

def acceptor_accepted_set(config, id, msg, verbose \\ 4) do
  if config.debug_level >= verbose do
    IO.puts "Acceptor #{inspect(id)} updated accepted map with #{inspect(msg)}."
  end
end

def send(config, src, dest, atom, params, verbose \\ 2) do
  if config.debug_level >= verbose do
    IO.puts "Send #{atom} from #{inspect(src)} to #{inspect(dest)} with parameters #{inspect(params)}."
  end
end

def client_send(config, src, dest, atom, params, verbose \\ 1) do
  if config.debug_level >= verbose do
    send(config, src, dest, atom, params, verbose)
  end
end

def client_receive(config, id, atom, params, verbose \\ 1) do
  if config.debug_level >= verbose do
    IO.puts "Client #{inspect(id)} received #{atom} with command #{inspect(params)}."
  end
end

def scout_receive(config, id, type, acceptor, b, verbose \\ 2) do
  if config.debug_level >= verbose do
    IO.puts "Scout #{inspect(id)} received #{inspect type} from acceptor #{inspect(acceptor)} with ballot_num #{inspect(b)}."
  end
end

def commander_receive(config, id, type, acceptor, b, verbose \\ 2) do
  if config.debug_level >= verbose do
    IO.puts "Commander #{inspect(id)} received #{inspect type} from acceptor #{inspect(acceptor)} with ballot_num #{inspect(b)}."
  end
end

def leader_receive(config, id, type, args, verbose \\ 2) do
  if config.debug_level >= verbose do
    IO.puts "Leader #{inspect(id)} received #{type} with args #{inspect(args)}."
  end
end

def leader_proposals_map(config, map, id, key, val, verbose \\ 0) do
  if config.debug_level >= verbose do
    IO.puts "Leader #{inspect(id)} updated leader proposals map with key #{key} and value #{val}."
    map(config, map)
  end
end

def replica_receive(config, id, type, args, verbose \\ 2) do
  if config.debug_level >= verbose do
    IO.puts "Leader #{inspect(id)} received #{type} with args #{inspect(args)}."
  end
end


end # Debug
