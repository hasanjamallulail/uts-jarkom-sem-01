#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/Hasan"

SERVER="clab-uts-APP-SRV"
CLIENT="clab-uts-PC-BR1"
TARGET="10.10.30.10"
PID=$(sudo docker inspect -f '{{.State.Pid}}' "$CLIENT")
OUT="evidence/soal3/qos/tcp-response.txt"

cleanup() {
    sudo nsenter -t "$PID" -n \
        tc qdisc del dev eth1 root 2>/dev/null || true
}
trap cleanup EXIT

# Hindari menimpa konfigurasi QoS lain.
QDISC=$(sudo nsenter -t "$PID" -n tc qdisc show dev eth1)
if ! grep -q 'qdisc noqueue' <<< "$QDISC"; then
    echo "Qdisc bukan noqueue. Eksperimen dibatalkan."
    echo "$QDISC"
    exit 1
fi

test_response() {
    local LABEL="$1"

    echo ""
    echo "===== $LABEL ====="

    for i in 1 2 3 4 5; do
        sudo docker exec "$SERVER" \
            sh -c 'killall nc 2>/dev/null || true'

        sudo docker exec -d "$SERVER" \
            nc -l -p 5000 -e /bin/cat

        sleep 0.3

        START=$(date +%s%N)

        RESPONSE=$(sudo docker exec "$CLIENT" \
            sh -c "printf 'UJI TCP $i\n' | nc -w 3 $TARGET 5000")

        END=$(date +%s%N)

        ELAPSED=$(( (END - START) / 1000000 ))

        echo "Percobaan $i | ${ELAPSED} ms | Respons: $RESPONSE"
    done
}

{
    echo "UTS CS238 - PENGUJIAN WAKTU RESPONS TCP"

    test_response "BASELINE TANPA DELAY"

    echo ""
    echo "===== TERAPKAN DELAY 100 MS ====="

    sudo nsenter -t "$PID" -n \
        tc qdisc replace dev eth1 root netem delay 100ms

    sudo nsenter -t "$PID" -n \
        tc qdisc show dev eth1

    test_response "TCP DENGAN DELAY 100 MS"

    echo ""
    echo "===== PEMULIHAN QDISC ====="
    cleanup

    sudo nsenter -t "$PID" -n \
        tc qdisc show dev eth1

} 2>&1 | tee "$OUT"
