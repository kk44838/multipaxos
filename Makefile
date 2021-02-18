# Kazuya Kai-Olowu (kyk3218)

SERVERS  ?= 5
CLIENTS  = 5
CONFIG   ?= default # Options: default, randomised_backoff, exponential_backoff, exponential_bully_backoff
DEBUG    ?= 0
MAX_TIME = 15000
WINDOW_SIZE = 100

START    = Multipaxos.start
HOST	:= 127.0.0.1

# --------------------------------------------------------------------

TIME    := $(shell date +%H:%M:%S)
SECS    := $(shell date +%S)
COOKIE  := $(shell echo $$PPID)

NODE_SUFFIX := ${SECS}_${LOGNAME}@${HOST}

ELIXIR  := elixir --no-halt --cookie ${COOKIE} --name
MIX 	:= -S mix run -e ${START} \
	${NODE_SUFFIX} ${MAX_TIME} ${DEBUG} ${SERVERS} ${CLIENTS} ${CONFIG} ${WINDOW_SIZE}

# --------------------------------------------------------------------
all: run cluster

random:
	$(MAKE) run CONFIG=randomised_backoff

random_round_robin:
	$(MAKE) run CONFIG=random_round_robin

random_quorum:
	$(MAKE) run CONFIG=random_quorum

exponential:
	$(MAKE) run CONFIG=exponential_backoff

exponential_bully:
	$(MAKE) run CONFIG=exponential_bully_backoff

default_2_server_5_client:
	$(MAKE) run SERVERS=2

server_1_crash_default_2_server_5_client:
	$(MAKE) run SERVERS=2 CONFIG=server_1_crash_default_2_server_5_client

server_1_crash_random_backoff:
	$(MAKE) run CONFIG=server_1_crash_random_backoff

three_server_crash_random_backoff:
	$(MAKE) run CONFIG=three_server_crash_random_backoff

run cluster: compile
	@ ${ELIXIR} server1_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server2_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server3_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server4_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} server5_${NODE_SUFFIX} ${MIX} cluster_wait &

	@ ${ELIXIR} client1_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client2_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client3_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client4_${NODE_SUFFIX} ${MIX} cluster_wait &
	@ ${ELIXIR} client5_${NODE_SUFFIX} ${MIX} cluster_wait &
	@sleep 3
	@ ${ELIXIR} multipaxos_${NODE_SUFFIX} ${MIX} cluster_start

compile:
	mix compile

clean:
	mix clean
	@rm -f erl_crash.dump

ps:
	@echo ------------------------------------------------------------
	epmd -names

