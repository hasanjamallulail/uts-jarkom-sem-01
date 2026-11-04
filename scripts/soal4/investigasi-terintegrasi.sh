#!/usr/bin/env bash
set -Eeuo pipefail

cd "$HOME/Hasan"

CLIENT="clab-uts-PC-BR1"
CLIENT2="clab-uts-PC-BR2"
SERVER="clab-uts-APP-SRV"

TARGET="10.10.30.10"
PORT="5504"

OUT="evidence/soal4"
PIDFILE="/tmp/soal4_tcp_5504.pid"

mkdir -p "$OUT"

LOG="$OUT/investigasi-lengkap.txt"

exec > >(tee "$LOG") 2>&1

CPID=""
SPID=""
ROUTE_ADDED=0

cleanup() {
    echo ""
    echo "===== CLEANUP OTOMATIS ====="

    if [ "$ROUTE_ADDED" -eq 1 ] && [ -n "$CPID" ]; then
        sudo nsenter -t "$CPID" -n \
          ip -4 route del unreachable "$TARGET/32" \
          2>/dev/null || true
        ROUTE_ADDED=0
    fi

    sudo docker exec "$SERVER" sh -c '
        F=/tmp/soal4_tcp_5504.pid
        if [ -f "$F" ]; then
            P=$(cat "$F")
            if [ -r "/proc/$P/cmdline" ] &&
               tr "\000" " " < "/proc/$P/cmdline" |
               grep -q "nc -l -p 5504"; then
                kill "$P" 2>/dev/null || true
            fi
            rm -f "$F"
        fi
    ' >/dev/null 2>&1 || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

section() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
    date -Is
}

start_tcp() {
    cleanup

    sudo docker exec -d "$SERVER" \
      sh -c 'echo $$ > /tmp/soal4_tcp_5504.pid; exec nc -l -p 5504 -e /bin/cat'

    sleep 1

    if ! sudo nsenter -t "$SPID" -n \
      ss -lnt | grep -q ":5504"; then
        echo "ERROR: TCP server tidak listening"
        exit 1
    fi

    echo "TCP SERVER: LISTEN port 5504"
}

stop_tcp() {
    sudo docker exec "$SERVER" sh -c '
        F=/tmp/soal4_tcp_5504.pid
        if [ -f "$F" ]; then
            P=$(cat "$F")
            if [ -r "/proc/$P/cmdline" ] &&
               tr "\000" " " < "/proc/$P/cmdline" |
               grep -q "nc -l -p 5504"; then
                kill "$P" 2>/dev/null || true
            fi
            rm -f "$F"
        fi
    '

    sleep 1
}

tcp_probe() {
    local CONTAINER="$1"
    local LABEL="$2"
    local RESULT
    local CODE

    echo ""
    echo "----- TCP TEST: $LABEL -----"

    set +e
    RESULT=$(sudo docker exec "$CONTAINER" sh -c \
      "printf 'SOAL4_TCP_OK\n' | nc -w 3 $TARGET $PORT" 2>&1)
    CODE=$?
    set -e

    echo "Respons: ${RESULT:-<tidak ada>}"
    echo "Exit code: $CODE"

    if [ "$CODE" -eq 0 ] &&
       [ "$RESULT" = "SOAL4_TCP_OK" ]; then
        echo "HASIL TCP: BERHASIL"
        TCP_OK=1
    else
        echo "HASIL TCP: GAGAL"
        TCP_OK=0
    fi
}

ping_probe() {
    local CONTAINER="$1"
    local LABEL="$2"

    echo ""
    echo "----- ICMP TEST: $LABEL -----"

    sudo docker exec "$CONTAINER" \
      ping -c 3 -W 1 "$TARGET" || true
}

hash_prior() {
    find configs evidence/soal1 evidence/soal2 evidence/soal3 \
      -type f -print0 |
      sort -z |
      sudo xargs -0 -r sha256sum |
      sha256sum |
      awk '{print $1}'
}

section "SOAL 4 - INVESTIGASI GANGGUAN TERINTEGRASI"

echo "Skenario: Routing IP + TCP"
echo "Client   : PC-BR1"
echo "Server   : APP-SRV"
echo "IP server: $TARGET"
echo "TCP port : $PORT"

section "0. PREFLIGHT DAN KEAMANAN"

CPID=$(sudo docker inspect -f '{{.State.Pid}}' "$CLIENT")
SPID=$(sudo docker inspect -f '{{.State.Pid}}' "$SERVER")

if [ "$CPID" -le 0 ] || [ "$SPID" -le 0 ]; then
    echo "ERROR: Container tidak aktif"
    exit 1
fi

echo "===== CEK ROUTE KHUSUS YANG SUDAH ADA ====="

EXISTING=$(sudo nsenter -t "$CPID" -n \
  ip -4 route show exact "$TARGET/32")

if [ -n "$EXISTING" ]; then
    echo "DIBATALKAN: sudah ada route /32:"
    echo "$EXISTING"
    exit 1
fi

echo "===== CEK PORT TCP KHUSUS ====="

if sudo nsenter -t "$SPID" -n ss -lnt |
   grep -q ":5504"; then
    echo "DIBATALKAN: port TCP 5504 sudah digunakan"
    exit 1
fi

if sudo docker exec "$SERVER" test -e "$PIDFILE"; then
    echo "DIBATALKAN: file PID percobaan sudah ada"
    exit 1
fi

echo "===== CEK OSPF R-BR1 ====="

NEIGHBOR=$(sudo docker exec clab-uts-R-BR1 \
  vtysh -c "show ip ospf neighbor")

echo "$NEIGHBOR"

if ! grep -q "Full" <<< "$NEIGHBOR"; then
    echo "DIBATALKAN: adjacency OSPF belum FULL"
    exit 1
fi

echo "===== CEK QDISC PC-BR1 ====="

sudo nsenter -t "$CPID" -n tc qdisc show dev eth1

echo "===== CHECKSUM FILE SOAL 1-3 ====="

HASH_BEFORE=$(hash_prior)
echo "$HASH_BEFORE" > "$OUT/checksum-sebelum.txt"
echo "Checksum awal: $HASH_BEFORE"

section "1. BASELINE KONDISI NORMAL"

echo "===== ROUTING CLIENT ====="
sudo nsenter -t "$CPID" -n ip -4 route get "$TARGET"

echo "===== OSPF ROUTING ====="
sudo docker exec clab-uts-R-BR1 \
  vtysh -c "show ip route ospf"

ping_probe "$CLIENT" "BASELINE BR1"

start_tcp
tcp_probe "$CLIENT" "BASELINE TCP"

if [ "$TCP_OK" -ne 1 ]; then
    echo "ERROR: Baseline TCP tidak berhasil"
    exit 1
fi

BASELINE_OK=1

echo "BASELINE: VALID"

section "2. PEMICU GANGGUAN PERTAMA - ROUTING"

# Nyalakan lagi layanan khusus sebelum gangguan.
start_tcp

echo "===== TAMBAHKAN ROUTE UNREACHABLE ====="

sudo nsenter -t "$CPID" -n \
  ip -4 route add unreachable "$TARGET/32"

ROUTE_ADDED=1

echo "===== ROUTE YANG DISUNTIKKAN ====="

sudo nsenter -t "$CPID" -n \
  ip -4 route show exact "$TARGET/32"

ping_probe "$CLIENT" "ROUTING TERGANGGU"

tcp_probe "$CLIENT" "ROUTING TERGANGGU"

section "3. PEMICU GANGGUAN KEDUA - TCP SERVER"

stop_tcp

echo "===== STATUS TCP SERVER ====="

sudo nsenter -t "$SPID" -n ss -lnt |
  grep ":5504" || echo "TCP 5504 TIDAK LISTEN"

ping_probe "$CLIENT" "DUA GANGGUAN AKTIF"
tcp_probe "$CLIENT" "DUA GANGGUAN AKTIF"

section "4. DIAGNOSIS TIGA HIPOTESIS"

echo "===== H1: OSPF ROUTER BERMASALAH? ====="

sudo docker exec clab-uts-R-BR1 \
  vtysh -c "show ip ospf neighbor"

sudo docker exec clab-uts-R-BR1 \
  vtysh -c "show ip route ospf"

echo ""
echo "===== H2: ROUTING IP CLIENT BERMASALAH? ====="

sudo nsenter -t "$CPID" -n \
  ip -4 route show exact "$TARGET/32"

sudo nsenter -t "$CPID" -n \
  ip -4 route get "$TARGET" || true

echo ""
echo "===== H3: LAYANAN TCP TIDAK AKTIF? ====="

sudo nsenter -t "$SPID" -n \
  ss -lnt | grep ":5504" ||
  echo "TCP 5504 TIDAK LISTEN"

echo ""
echo "===== KONTROL CABANG 2 ====="

ping_probe "$CLIENT2" "BR2 SAAT GANGGUAN BR1"

section "5. SOLUSI TAHAP 1 - PERBAIKI ROUTING SAJA"

sudo nsenter -t "$CPID" -n \
  ip -4 route del unreachable "$TARGET/32"

ROUTE_ADDED=0

echo "===== ROUTING SETELAH PERBAIKAN ====="

sudo nsenter -t "$CPID" -n \
  ip -4 route get "$TARGET"

ping_probe "$CLIENT" "SETELAH PERBAIKAN ROUTING"

tcp_probe "$CLIENT" "TCP MASIH MATI"

echo "KESIMPULAN TAHAP 1:"
echo "Routing dipulihkan tanpa mengaktifkan TCP server."

section "6. CAPTURE TCP SAAT LAYANAN MATI"

sudo timeout 6 nsenter -t "$SPID" -n \
  tcpdump -i eth1 -nn -U \
  -w "$OUT/tcp-server-mati.pcap" \
  "host 10.10.20.10 and tcp port 5504" \
  2> "$OUT/tcp-capture-info.txt" &

CAP_PID=$!

sleep 1

tcp_probe "$CLIENT" "BUKTI TCP SERVER MATI"

wait "$CAP_PID" || true

sudo tcpdump -nn -r "$OUT/tcp-server-mati.pcap" |
  tee "$OUT/tcp-server-mati.txt"

section "7. SOLUSI TAHAP 2 - PULIHKAN TCP"

start_tcp

tcp_probe "$CLIENT" "SETELAH TCP DIPULIHKAN"

if [ "$TCP_OK" -ne 1 ]; then
    echo "ERROR: TCP belum berhasil setelah solusi"
    exit 1
fi

RECOVERY_OK=1

echo "HASIL PEMULIHAN: BERHASIL"

section "8. UJI REGRESI"

echo "===== REGRESI PC-BR1 ====="
ping_probe "$CLIENT" "BR1 KE APP-SRV"

echo "===== REGRESI PC-BR2 ====="
ping_probe "$CLIENT2" "BR2 KE APP-SRV"

echo "===== REGRESI TCP DARI CABANG 2 ====="
start_tcp
tcp_probe "$CLIENT2" "TCP BR2 KE APP-SRV"

echo "===== REGRESI OSPF EMPAT ROUTER ====="

for R in R-HQ R-BR1 R-BR2 R-DC; do
    echo ""
    echo "===== $R ====="
    sudo docker exec "clab-uts-$R" \
      vtysh -c "show ip ospf neighbor"
done

echo "===== QDISC TIDAK BERUBAH ====="

sudo nsenter -t "$CPID" -n tc qdisc show dev eth1

section "9. CLEANUP DAN PEMERIKSAAN AKHIR"

cleanup

echo "===== ROUTE SETELAH CLEANUP ====="

sudo nsenter -t "$CPID" -n \
  ip -4 route show exact "$TARGET/32"

sudo nsenter -t "$CPID" -n \
  ip -4 route get "$TARGET"

echo "===== TCP PORT UJI ====="

sudo nsenter -t "$SPID" -n ss -lnt |
  grep ":5504" || echo "PORT UJI TELAH DITUTUP"

echo "===== CHECKSUM SOAL 1-3 ====="

HASH_AFTER=$(hash_prior)
echo "$HASH_AFTER" > "$OUT/checksum-sesudah.txt"

echo "Sebelum: $HASH_BEFORE"
echo "Sesudah: $HASH_AFTER"

if [ "$HASH_BEFORE" = "$HASH_AFTER" ]; then
    FILE_STATUS="TIDAK BERUBAH"
else
    FILE_STATUS="ADA PERUBAHAN - PERLU DIPERIKSA"
fi

echo "Status file lama: $FILE_STATUS"

section "10. RINGKASAN AKHIR"

{
    echo "UTS CS238 - RINGKASAN SOAL 4"
    echo "========================================"
    echo "Skenario: Routing IP + TCP"
    echo "Baseline TCP: BERHASIL"
    echo "Gangguan 1: Route unreachable khusus APP-SRV"
    echo "Gangguan 2: TCP server port 5504 mati"
    echo "H1: OSPF diperiksa melalui neighbor dan tabel routing"
    echo "H2: Route khusus teridentifikasi"
    echo "H3: TCP port 5504 tidak listening"
    echo "Perbaikan 1: Route sementara dihapus"
    echo "Perbaikan 2: Layanan TCP diuji kembali"
    echo "Pemulihan TCP: BERHASIL"
    echo "Regresi: BR1, BR2, dan OSPF diuji"
    echo "Status file Soal 1-3: $FILE_STATUS"
    echo "========================================"
} | tee "$OUT/ringkasan-soal4.txt"

echo ""
echo "SEMUA PENGUJIAN SOAL 4 SELESAI"

trap - EXIT
