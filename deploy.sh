#!/bin/bash

pkill -9 beam.smp; pkill -9 erl; pkill -9 epmd;

CLIENT_NODE="client@$(curl -s ifconfig.me)"
COOKIE="CHOCOLATE"
USER="a605472"
ARCHIVE_NAME="generalized_ricart_agrawala.zip"

# CLIENT_NODE="client@127.0.0.1"
# NODES="w1@127.0.0.1 w2@127.0.0.1"
INDEX=1
AVAIL_NODES="$(ssh ${USER}@lab000.cps.unizar.es 'nmap -sP -PS22 155.210.154.0-255' | grep 'report for lab' | awk '{print $5}' | grep -v -E -e '245' -e $(curl -s ifconfig.me) | shuf -n 5)"
# AVAIL_NODES=$(printf "127.0.0.1\n127.0.0.1")
while read -r NODE; do
    NODES=$(printf "%s %s" "${NODES}" "w${INDEX}@${NODE}")
    INDEX=$((${INDEX} + 1))
done <<< "${AVAIL_NODES}"
NODES="$(sed 's/^[[:space:]]//' <<< ${NODES})"
NUM_NODES="$(wc -w <<< ${NODES})"
echo "Found ${NUM_NODES} nodes: ${NODES}"

WORKER_NODES="["
if [ ${NUM_NODES} -gt 0 ]; then
    WORKER_NODES=$(printf "%s'%s'" "${WORKER_NODES}" "$(cut -d' ' -f1 <<< ${NODES})")
fi
for i in $(seq  2 ${NUM_NODES});do
    WORKER_NODES=$(printf "%s,'%s'" "${WORKER_NODES}" "$(cut -d' ' -f${i} <<< ${NODES})")
done
WORKER_NODES="$(printf "%s]" "${WORKER_NODES}")"

zip -r ${ARCHIVE_NAME} lib/ mix.exs test/
echo "Initializing remote BEAM instances..."
# Copy the ZIP on just one machine, the NFS will take care of the rest
for NODE in "$(cut -d' ' -f1 <<< ${NODES})"; do
    ADDR=$(cut -d'@' -f2 <<< ${NODE})
    USER_ADDR="${USER}@${ADDR}"
    if [ "${ADDR}" != "127.0.0.1" ]; then
        ssh ${USER_ADDR} "rm -rf /home/${USER}/elixir_app; mkdir /home/${USER}/elixir_app"
        scp ${ARCHIVE_NAME} ${USER_ADDR}:/home/${USER}/elixir_app
        ssh ${USER_ADDR} "cd /home/${USER}/elixir_app; unzip ${ARCHIVE_NAME}"
    fi
done
for NODE in ${NODES}; do
    ADDR=$(cut -d'@' -f2 <<< ${NODE})
    USER_ADDR="${USER}@${ADDR}"
    if [ "${ADDR}" != "127.0.0.1" ]; then
        ssh ${USER_ADDR} "cd /home/${USER}/elixir_app; \
            pkill -9 beam.smp; pkill -9 erl; pkill -9 epmd; \
            elixir --name ${NODE} \
                   --erl '-kernel inet_dist_listen_min 32000' \
                   --erl '-kernel inet_dist_listen_max 32009' \
                   --erl \"-generalized_ricart_agrawala members ${WORKER_NODES}\" \
                   --cookie ${COOKIE} --detached --no-halt -S mix"
    else
        elixir --name ${NODE} \
               --erl '-kernel inet_dist_listen_min 32000' \
               --erl '-kernel inet_dist_listen_max 32009' \
               --erl "-generalized_ricart_agrawala members ${WORKER_NODES}" \
               --cookie ${COOKIE} --detached --no-halt -S mix
    fi
    echo "Initialized BEAM on: ${NODE}"
done

echo "Done initializing BEAM on all nodes."

echo "Initializing client..."
elixir --name ${CLIENT_NODE} \
       --erl '-kernel inet_dist_listen_min 32000' \
       --erl '-kernel inet_dist_listen_max 32009' \
       --erl "-generalized_ricart_agrawala members ${WORKER_NODES}" \
       --cookie ${COOKIE} -S mix test --exclude disabled
