#!/usr/bin/env bash

cd "$HOME/Hasan" || exit 1

OUT="evidence/final"
mkdir -p "$OUT"

LOG="$OUT/SHOW-ALL-UTS-CS238.txt"

# Simpan semua output sekaligus
exec > >(tee "$LOG") 2>&1

section() {
    echo ""
    echo "===================================================="
    echo " $1"
    echo "===================================================="
}

show_file() {
    FILE="$1"

    if [ -f "$FILE" ]; then
        echo "[ADA] $FILE"
        ls -lh "$FILE"
    else
        echo "[BELUM DITEMUKAN] $FILE"
    fi
}

show_ping_summary() {
    FILE="$1"

    if [ -f "$FILE" ]; then
        echo "----- $FILE -----"
        grep -E \
          'packets transmitted|packet loss|round-trip|rtt min' \
          "$FILE" | tail -n 4
    else
        echo "[BELUM DITEMUKAN] $FILE"
    fi
}

section "UTS CS238 - SHOW ALL FINAL SOAL 1 SAMPAI 5"

date -Is
echo "Project: $PWD"
echo "Hostname: $(hostname)"

section "00. STATUS LINGKUNGAN"

echo "===== SISTEM OPERASI ====="
cat /etc/os-release | head -n 6

echo ""
echo "===== DOCKER ====="
sudo docker --version

echo ""
echo "===== CONTAINERLAB ====="
containerlab version 2>/dev/null | head -n 8

echo ""
echo "===== CONTAINER AKTIF ====="
sudo docker ps --format \
  'table {{.Names}}\t{{.Status}}' |
  grep -E 'NAMES|clab-uts' || true

section "01. TOPOLOGI CONTAINERLAB"

echo "===== FILE TOPOLOGI ====="

for F in \
    topology.clab.yml \
    topology-next.clab.yml \
    topology-rip.clab.yml \
    topology-ospf.clab.yml
do
    show_file "$F"
done

echo ""
echo "===== NODE CONTAINER ====="
sudo docker ps --format '{{.Names}}' |
  grep '^clab-uts-' | sort || true

echo ""
echo "===== JUMLAH CONTAINER ====="
sudo docker ps --format '{{.Names}}' |
  grep -c '^clab-uts-' || true

section "02. SOAL 1 - STATIC ROUTING"

echo "===== EVIDENCE SOAL 1 ====="

if [ -d evidence/soal1 ]; then
    find evidence/soal1 -type f | sort
    echo "Jumlah file:"
    find evidence/soal1 -type f | wc -l
else
    echo "Folder evidence/soal1 belum ditemukan"
fi

echo ""
echo "===== BACKUP STATIC ROUTING ====="

if [ -d configs/static-backup ]; then
    find configs/static-backup -type f | sort
else
    echo "Backup static routing belum ditemukan"
fi

echo ""
echo "===== SCRIPT SOAL 1 ====="
find scripts -maxdepth 2 -type f \
  -iname '*static*' 2>/dev/null | sort

section "03. SOAL 2 - RIP VERSION 2"

echo "===== KONFIGURASI RIP ====="

for R in R-HQ R-BR1 R-BR2 R-DC; do
    echo ""
    echo "----- $R -----"
    show_file "configs/rip/$R/frr.conf"
done

echo ""
echo "===== EVIDENCE RIP ====="

if [ -d evidence/soal2/rip ]; then
    find evidence/soal2/rip -type f | sort
fi

echo ""
echo "===== ROUTING RIP TERSIMPAN ====="

if [ -f evidence/soal2/rip/baseline/R-HQ-rip-route.txt ]; then
    grep '^R' \
      evidence/soal2/rip/baseline/R-HQ-rip-route.txt
else
    echo "File routing RIP baseline tidak ditemukan pada path standar"
fi

echo ""
echo "===== LOG LINK FAILURE RIP ====="
show_file evidence/soal2/rip/rip-link-failure.txt

section "04. SOAL 2 - OSPF"

echo "===== KONFIGURASI OSPF ====="

for R in R-HQ R-BR1 R-BR2 R-DC; do
    echo ""
    echo "----- $R -----"
    show_file "configs/ospf/$R/frr.conf"

    if [ -f "configs/ospf/$R/frr.conf" ]; then
        grep -nE \
          'router ospf|ospf router-id|ip ospf network point-to-point' \
          "configs/ospf/$R/frr.conf" || true
    fi
done

echo ""
echo "===== OSPF NEIGHBOR SAAT INI ====="

for R in R-HQ R-BR1 R-BR2 R-DC; do
    echo ""
    echo "----- $R -----"

    sudo docker exec "clab-uts-$R" \
      vtysh -c "show ip ospf neighbor" || true
done

echo ""
echo "===== OSPF ROUTING SAAT INI ====="

for R in R-HQ R-BR1 R-BR2 R-DC; do
    echo ""
    echo "----- $R -----"

    sudo docker exec "clab-uts-$R" \
      vtysh -c "show ip route ospf" || true
done

echo ""
echo "===== EVIDENCE OSPF ====="

if [ -d evidence/soal2/ospf ]; then
    find evidence/soal2/ospf -type f | sort
fi

section "05. SOAL 3 - TRANSPORT LAYER TCP"

echo "===== TCP HANDSHAKE ====="
show_file evidence/soal3/capture/tcp-handshake.pcap
show_file evidence/soal3/capture/tcp-handshake.txt

echo ""
echo "===== TCP SAAT SERVER MATI ====="
show_file evidence/soal3/capture/tcp-server-mati.pcap
show_file evidence/soal3/capture/tcp-server-mati.txt

echo ""
echo "===== RINGKASAN CAPTURE TCP ====="

if [ -f evidence/soal3/capture/tcp-handshake.txt ]; then
    grep 'Flags' \
      evidence/soal3/capture/tcp-handshake.txt |
      head -n 12
fi

section "06. SOAL 3 - TRANSPORT LAYER UDP"

echo "===== UDP SERVER MATI ====="
show_file evidence/soal3/udp/udp-server-mati.txt

echo ""
echo "===== UDP TANPA RESPONS ====="
show_file evidence/soal3/udp/udp-no-response-capture.txt
show_file evidence/soal3/udp/udp-no-response-server.log

echo ""
echo "===== DATA UDP TANPA RESPONS ====="

if [ -f evidence/soal3/udp/udp-no-response-server.log ]; then
    cat evidence/soal3/udp/udp-no-response-server.log
fi

section "07. SOAL 3 - QOS"

echo "===== BASELINE ====="
show_ping_summary evidence/soal3/qos/ping-baseline.txt

echo ""
echo "===== DELAY 100 MS ====="
show_ping_summary evidence/soal3/qos/ping-delay-100ms.txt

echo ""
echo "===== PACKET LOSS 10% ====="
show_ping_summary evidence/soal3/qos/ping-loss-10pct.txt

echo ""
echo "===== RESPONS APLIKASI TCP ====="

if [ -f evidence/soal3/qos/tcp-response.txt ]; then
    cat evidence/soal3/qos/tcp-response.txt
fi

echo ""
echo "===== TRANSFER FILE TCP ====="

if [ -f evidence/soal3/qos/tcp-transfer-fixed.csv ]; then
    cat evidence/soal3/qos/tcp-transfer-fixed.csv
fi

echo ""
echo "===== UDP BASELINE ====="

if [ -f evidence/soal3/qos/udp-fixed-BASELINE.txt ]; then
    cat evidence/soal3/qos/udp-fixed-BASELINE.txt
fi

echo ""
echo "===== UDP LOSS ====="

if [ -f evidence/soal3/qos/udp-fixed-LOSS_10PCT.txt ]; then
    cat evidence/soal3/qos/udp-fixed-LOSS_10PCT.txt
fi

section "08. SOAL 3 - TCP RETRANSMISSION"

for F in \
  tcp-retransmission-analysis.txt \
  tcp-duplicate-ack.txt \
  tcp-lost-segment.txt
do
    FILE="evidence/soal3/capture/$F"

    if [ -f "$FILE" ]; then
        echo "$F : $(wc -l < "$FILE") paket teridentifikasi"
    else
        echo "$F : BELUM DITEMUKAN"
    fi
done

echo ""
echo "===== PACKET CAPTURE QOS ====="
show_file evidence/soal3/capture/tcp-transfer-loss-fixed.pcap

section "09. SOAL 4 - INVESTIGASI GANGGUAN"

echo "===== RINGKASAN INVESTIGASI ====="

if [ -f evidence/soal4/ringkasan-soal4.txt ]; then
    cat evidence/soal4/ringkasan-soal4.txt
fi

echo ""
echo "===== HASIL REGRESI ICMP ====="

if [ -f evidence/soal4/investigasi-lengkap.txt ]; then

    grep -E \
      'ICMP TEST:|packets transmitted|round-trip' \
      evidence/soal4/investigasi-lengkap.txt ||
      true

    echo ""
    echo "===== HASIL TCP ====="

    grep -E \
      'TCP TEST:|HASIL TCP:|Exit code:' \
      evidence/soal4/investigasi-lengkap.txt ||
      true
fi

echo ""
echo "===== CHECKSUM FILE SOAL 1-3 ====="

show_file evidence/soal4/checksum-sebelum.txt
show_file evidence/soal4/checksum-sesudah.txt

if [ -f evidence/soal4/checksum-sebelum.txt ] &&
   [ -f evidence/soal4/checksum-sesudah.txt ]; then

    if cmp -s \
      evidence/soal4/checksum-sebelum.txt \
      evidence/soal4/checksum-sesudah.txt; then

        echo "HASIL: FILE SOAL 1-3 TIDAK BERUBAH"
    else
        echo "PERINGATAN: CHECKSUM BERBEDA"
    fi
fi

section "10. SOAL 5 - EVALUASI ARSITEKTUR"

echo "===== EVIDENCE SOAL 5 ====="

if [ -d evidence/soal5 ]; then
    find evidence/soal5 -type f | sort
else
    echo "Folder evidence/soal5 belum ditemukan"
fi

echo ""
echo "===== SNAPSHOT EVALUASI ====="
show_file evidence/soal5/evaluasi-arsitektur.txt

section "11. UJI KONEKTIVITAS FINAL"

echo "===== CABANG 1 KE APPLICATION SERVER ====="

sudo docker exec clab-uts-PC-BR1 \
  ping -c 5 -W 1 10.10.30.10 || true

echo ""
echo "===== CABANG 2 KE APPLICATION SERVER ====="

sudo docker exec clab-uts-PC-BR2 \
  ping -c 5 -W 1 10.10.30.10 || true

echo ""
echo "===== KANTOR PUSAT KE APPLICATION SERVER ====="

sudo docker exec clab-uts-PC-HQ1 \
  ping -c 5 -W 1 10.10.30.10 || true

section "12. VERIFIKASI KONFIGURASI JARINGAN"

echo "===== QDISC PC-BR1 ====="

PID=$(sudo docker inspect -f '{{.State.Pid}}' \
  clab-uts-PC-BR1)

sudo nsenter -t "$PID" -n \
  tc qdisc show dev eth1

echo ""
echo "===== ROUTING MENUJU APP-SRV ====="

sudo nsenter -t "$PID" -n \
  ip -4 route get 10.10.30.10 || true

echo ""
echo "===== ROUTE KHUSUS /32 ====="

sudo nsenter -t "$PID" -n \
  ip -4 route show exact 10.10.30.10/32

section "13. REKAP JUMLAH FILE EVIDENCE"

for N in 1 2 3 4 5; do

    DIR="evidence/soal$N"

    if [ -d "$DIR" ]; then
        COUNT=$(find "$DIR" -type f | wc -l)
        echo "SOAL $N : $COUNT file evidence"
    else
        echo "SOAL $N : FOLDER BELUM DITEMUKAN"
    fi

done

echo ""
echo "===== TOTAL EVIDENCE SOAL 1-5 ====="

find evidence/soal1 evidence/soal2 evidence/soal3 \
     evidence/soal4 evidence/soal5 \
     -type f 2>/dev/null | wc -l

section "14. PEMERIKSAAN BACKUP ZIP"

if [ -d "$HOME/UTS-BACKUP" ]; then
    ls -lh "$HOME/UTS-BACKUP"/*.zip 2>/dev/null ||
      echo "Belum ada backup ZIP pada folder UTS-BACKUP"
else
    echo "Folder UTS-BACKUP belum ditemukan"
fi

section "VERIFIKASI FINAL SELESAI"

echo "Output lengkap: $LOG"
echo "Semua pemeriksaan bersifat observasi."
echo "Konfigurasi router dan container tidak diubah."
