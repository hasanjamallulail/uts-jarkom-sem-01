#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan" || exit 1

OUT="evidence/audit-final"
mkdir -p "$OUT"

# Pemeriksaan aman: tidak mengubah konfigurasi.
export LC_ALL=C

judul() {
    echo ""
    echo "======================================================"
    echo " $1"
    echo "======================================================"
}

ada() {
    if [ -f "$1" ]; then
        echo "[ADA] $1"
    else
        echo "[BELUM ADA] $1"
    fi
}

ringkas_ping() {
    local f="$1"
    if [ -s "$f" ]; then
        grep -E \
          'packets transmitted|round-trip min/avg/max|rtt min/avg/max' \
          "$f" | tail -n 3 || true
    else
        echo "Log tidak ditemukan: $f"
    fi
}

# ============================================
# AUDIT 01 - TOPOLOGI
# ============================================
{
    judul "AUDIT 01 - TOPOLOGI DAN IP ADDRESS"

    echo "Tanggal pemeriksaan:"
    date -Is

    echo ""
    echo "===== FILE TOPOLOGI ====="
    for f in topology.clab.yml topology-next.clab.yml \
             topology-rip.clab.yml topology-ospf.clab.yml; do
        ada "$f"
    done

    echo ""
    echo "===== CONTAINER AKTIF ====="
    sudo docker ps --format \
      'table {{.Names}}\t{{.Status}}' |
      grep -E 'NAMES|clab-uts' || true

    echo ""
    echo "===== JUMLAH CONTAINER ====="
    sudo docker ps --format '{{.Names}}' |
      grep -c '^clab-uts-' || true

    echo ""
    echo "===== IP ROUTER ====="
    for r in R-HQ R-BR1 R-BR2 R-DC; do
        echo ""
        echo "----- $r -----"
        sudo docker exec "clab-uts-$r" \
          ip -4 -brief address show 2>&1 || true
    done

    echo ""
    echo "===== IP HOST DAN SERVER ====="
    for h in PC-HQ1 PC-HQ2 PC-BR1 PC-BR2 APP-SRV DNS-SRV; do
        echo ""
        echo "----- $h -----"
        sudo docker exec "clab-uts-$h" \
          ip -4 -brief address show 2>&1 || true
    done
} 2>&1 | tee "$OUT/01-topologi.txt"

# ============================================
# AUDIT 02 - STATIC ROUTING
# ============================================
{
    judul "AUDIT 02 - SOAL 1 STATIC ROUTING"

    echo "Catatan: yang ditampilkan adalah file historis,"
    echo "bukan tabel static routing aktif saat ini."

    echo ""
    echo "===== BACKUP KONFIGURASI STATIC ====="
    if [ -d configs/static-backup ]; then
        find configs/static-backup -type f | sort
    else
        echo "Folder static-backup belum ditemukan."
    fi

    echo ""
    echo "===== PERINTAH STATIC ROUTE DALAM BACKUP ====="
    if [ -d configs/static-backup ]; then
        grep -RnE '(^|[[:space:]])ip route ' \
          configs/static-backup || true
    fi

    echo ""
    echo "===== DAFTAR EVIDENCE SOAL 1 ====="
    if [ -d evidence/soal1 ]; then
        find evidence/soal1 -type f | sort
    fi

    echo ""
    echo "===== LONGEST PREFIX MATCH ====="
    echo "Target: 10.10.30.10/32 versus 10.10.30.0/24"

    grep -RniE \
      'longest|prefix|10\.10\.30\.10/32' \
      evidence/soal1 scripts 2>/dev/null |
      head -n 25 || true

    echo ""
    echo "===== BUKTI LINK FAILURE ====="
    grep -RniE \
      'link.failure|link.failure|100% packet loss|eth1 down' \
      evidence/soal1 2>/dev/null |
      head -n 20 || true
} 2>&1 | tee "$OUT/02-static-routing.txt"

# ============================================
# AUDIT 03 - RIP
# ============================================
{
    judul "AUDIT 03 - SOAL 2 RIP VERSION 2"

    echo "===== FILE KONFIGURASI RIP ====="
    for r in R-HQ R-BR1 R-BR2 R-DC; do
        echo ""
        echo "----- $r -----"

        f="configs/rip/$r/frr.conf"
        ada "$f"

        if [ -f "$f" ]; then
            grep -nE \
              'router rip|version 2|network |no auto-summary|passive-interface' \
              "$f" || true
        fi

        d="configs/rip/$r/daemons"
        if [ -f "$d" ]; then
            grep '^ripd=' "$d" || true
        fi
    done

    echo ""
    echo "===== EVIDENCE RIP ====="
    if [ -d evidence/soal2/rip ]; then
        find evidence/soal2/rip -type f | sort
    fi

    echo ""
    echo "===== LOG RIP TERKAIT GANGGUAN ====="
    grep -RniE \
      'packets transmitted|packet loss|round-trip|link.down|link.up|recovery|pemulihan' \
      evidence/soal2/rip 2>/dev/null |
      head -n 30 || true

    echo ""
    echo "CATATAN:"
    echo "Waktu konvergensi RIP belum dianggap terukur"
    echo "tanpa log monitoring dengan timestamp yang memadai."
} 2>&1 | tee "$OUT/03-rip.txt"

# ============================================
# AUDIT 04 - OSPF
# ============================================
{
    judul "AUDIT 04 - SOAL 2 OSPF"

    echo "===== KONFIGURASI OSPF ====="
    for r in R-HQ R-BR1 R-BR2 R-DC; do
        echo ""
        echo "----- $r -----"

        f="configs/ospf/$r/frr.conf"
        ada "$f"

        if [ -f "$f" ]; then
            grep -nE \
              'router ospf|ospf router-id|network |area |ip ospf network point-to-point|passive-interface' \
              "$f" || true
        fi
    done

    echo ""
    echo "===== OSPF NEIGHBOR AKTUAL ====="
    for r in R-HQ R-BR1 R-BR2 R-DC; do
        echo ""
        echo "----- $r -----"

        sudo docker exec "clab-uts-$r" \
          vtysh -c 'show ip ospf neighbor' 2>&1 || true
    done

    echo ""
    echo "===== ROUTING OSPF R-HQ ====="
    sudo docker exec clab-uts-R-HQ \
      vtysh -c 'show ip route ospf' 2>&1 || true

    echo ""
    echo "===== ROUTING OSPF R-BR1 ====="
    sudo docker exec clab-uts-R-BR1 \
      vtysh -c 'show ip route ospf' 2>&1 || true

    echo ""
    echo "===== EVIDENCE OSPF ====="
    if [ -d evidence/soal2/ospf ]; then
        find evidence/soal2/ospf -type f | sort
    fi
} 2>&1 | tee "$OUT/04-ospf.txt"

# ============================================
# AUDIT 05 - UJI KONEKTIVITAS AKTUAL
# ============================================
{
    judul "AUDIT 05 - KONEKTIVITAS SAAT INI"

    for h in PC-HQ1 PC-BR1 PC-BR2; do
        echo ""
        echo "===== $h KE APP-SRV ====="

        sudo docker exec "clab-uts-$h" \
          ping -c 5 -W 1 10.10.30.10 2>&1 || true
    done

    echo ""
    echo "CATATAN:"
    echo "Ini adalah kondisi OSPF saat audit."
    echo "Bukan pengukuran ulang RIP atau static routing."
} 2>&1 | tee "$OUT/05-konektivitas.txt"

# ============================================
# AUDIT 06 - TCP DAN UDP
# ============================================
{
    judul "AUDIT 06 - SOAL 3 TCP DAN UDP"

    echo "===== TCP HANDSHAKE ====="
    f="evidence/soal3/capture/tcp-handshake.txt"
    if [ -s "$f" ]; then
        grep 'Flags' "$f" | head -n 12 || true
    else
        echo "Log TCP handshake belum ditemukan."
    fi

    echo ""
    echo "===== TCP SERVER TIDAK AKTIF ====="
    f="evidence/soal3/capture/tcp-server-mati.txt"
    if [ -s "$f" ]; then
        cat "$f"
    else
        echo "Log TCP server mati belum ditemukan."
    fi

    echo ""
    echo "===== UDP SERVER TIDAK AKTIF ====="
    f="evidence/soal3/udp/udp-server-mati.txt"
    if [ -s "$f" ]; then
        cat "$f"
    else
        echo "Log UDP server mati belum ditemukan."
    fi

    echo ""
    echo "===== UDP TANPA RESPONS APLIKASI ====="
    for f in \
      evidence/soal3/udp/udp-no-response-capture.txt \
      evidence/soal3/udp/udp-no-response-server.log; do

        if [ -s "$f" ]; then
            echo "----- $f -----"
            cat "$f"
        else
            echo "Belum ditemukan: $f"
        fi
    done

    echo ""
    echo "===== PCAP YANG TERSEDIA ====="
    find evidence/soal3 -type f -name '*.pcap' \
      | sort || true
} 2>&1 | tee "$OUT/06-tcp-udp.txt"

# ============================================
# AUDIT 07 - QOS
# ============================================
{
    judul "AUDIT 07 - SOAL 3 QOS"

    echo "===== ICMP BASELINE (20 PAKET) ====="
    ringkas_ping evidence/soal3/qos/ping-baseline.txt

    echo ""
    echo "===== DELAY 100 MS (20 PAKET) ====="
    ringkas_ping evidence/soal3/qos/ping-delay-100ms.txt

    echo ""
    echo "===== LOSS 10% (100 PAKET) ====="
    ringkas_ping evidence/soal3/qos/ping-loss-10pct.txt

    echo ""
    echo "===== TRANSFER TCP 256 KiB ====="
    f="evidence/soal3/qos/tcp-transfer-fixed.csv"
    if [ -s "$f" ]; then
        cat "$f"
    fi

    echo ""
    echo "===== UDP BASELINE ====="
    cat evidence/soal3/qos/udp-fixed-BASELINE.txt \
      2>/dev/null || true

    echo ""
    echo "===== UDP LOSS 10% ====="
    cat evidence/soal3/qos/udp-fixed-LOSS_10PCT.txt \
      2>/dev/null || true

    echo ""
    echo "===== TCP RETRANSMISSION ====="
    for f in \
      tcp-retransmission-analysis.txt \
      tcp-duplicate-ack.txt \
      tcp-lost-segment.txt; do

        p="evidence/soal3/capture/$f"

        if [ -f "$p" ]; then
            echo "$f : $(wc -l < "$p")"
        else
            echo "$f : TIDAK DITEMUKAN"
        fi
    done

    echo ""
    echo "===== QDISC SAAT INI ====="
    PID=$(sudo docker inspect -f '{{.State.Pid}}' \
      clab-uts-PC-BR1 2>/dev/null)

    if [[ "$PID" =~ ^[0-9]+$ ]] && [ "$PID" -gt 0 ]; then
        sudo nsenter -t "$PID" -n \
          tc qdisc show dev eth1 || true
    fi
} 2>&1 | tee "$OUT/07-qos.txt"

# ============================================
# AUDIT 08 - INVESTIGASI SOAL 4
# ============================================
{
    judul "AUDIT 08 - SOAL 4 GANGGUAN TERINTEGRASI"

    LOG="evidence/soal4/investigasi-lengkap.txt"

    if [ -s "$LOG" ]; then
        echo "===== BASELINE, HIPOTESIS, SOLUSI ====="

        grep -E \
          'BASELINE:|H1:|H2:|H3:|HASIL PEMULIHAN:|Status file lama:' \
          "$LOG" || true

        echo ""
        echo "===== HASIL TCP ====="
        grep -E \
          'TCP TEST:|HASIL TCP:|Exit code:' \
          "$LOG" || true

        echo ""
        echo "===== HASIL ICMP ====="
        grep -E \
          'ICMP TEST:|packets transmitted|round-trip' \
          "$LOG" || true

        echo ""
        echo "===== OSPF SAAT REGRESI ====="
        grep -E 'Full/' "$LOG" | tail -n 12 || true
    else
        echo "Log investigasi tidak ditemukan."
    fi

    echo ""
    echo "===== BUKTI TCP SYN DAN RST ====="
    cat evidence/soal4/tcp-server-mati.txt \
      2>/dev/null || true

    echo ""
    echo "===== CHECKSUM SOAL 1-3 ====="
    for f in \
      evidence/soal4/checksum-sebelum.txt \
      evidence/soal4/checksum-sesudah.txt; do
        if [ -f "$f" ]; then
            cat "$f"
        fi
    done
} 2>&1 | tee "$OUT/08-investigasi.txt"

# ============================================
# AUDIT 09 - EVALUASI DAN BERKAS
# ============================================
{
    judul "AUDIT 09 - SOAL 5 DAN KELENGKAPAN"

    echo "===== EVIDENCE SOAL 5 ====="
    find evidence/soal5 -type f 2>/dev/null | sort || true

    echo ""
    echo "===== JUMLAH EVIDENCE SOAL 1-5 ====="

    for n in 1 2 3 4 5; do
        d="evidence/soal$n"

        if [ -d "$d" ]; then
            echo "Soal $n: $(find "$d" -type f | wc -l) file"
        else
            echo "Soal $n: folder belum ditemukan"
        fi
    done

    echo ""
    echo "===== README ====="
    ada README.md

    echo ""
    echo "===== FILE TOPOLOGI ====="
    ada topology.clab.yml
    ada topology-ospf.clab.yml

    echo ""
    echo "===== LAPORAN PDF DI SERVER ====="
    find "$HOME/Hasan" -maxdepth 3 \
      -type f -iname '*.pdf' 2>/dev/null | sort

    echo ""
    echo "===== FILE ZIP BACKUP ====="
    find "$HOME/UTS-BACKUP" -maxdepth 1 \
      -type f -name '*.zip' 2>/dev/null | sort

    echo ""
    echo "===== CATATAN AUDIT ====="
    echo "Soal 2(iii): ulangi pengukuran perlu bukti tersendiri."
    echo "Soal 3(v): tiga penyebab TCP gagal perlu ditulis."
    echo "Soal 1(iv-v): perbandingan dan rekomendasi harus eksplisit."
    echo "Soal 4(ii): matriks hipotesis harus lengkap."
    echo "Soal 5(iii): metode dan ukuran sampel harus konsisten."
} 2>&1 | tee "$OUT/09-kelengkapan.txt"

# ============================================
# RINGKASAN FINAL
# ============================================
{
    judul "AUDIT FINAL UTS CS238"

    echo "Folder evidence: $OUT"
    echo ""

    echo "===== OUTPUT AUDIT ====="
    ls -lh "$OUT"/*.txt

    echo ""
    echo "===== JUMLAH FILE AUDIT ====="
    find "$OUT" -maxdepth 1 \
      -type f -name '*.txt' | wc -l

    echo ""
    echo "===== STATUS ====="
    echo "Pemeriksaan selesai."
    echo "Tidak ada simulasi gangguan yang dijalankan."
    echo "Tidak ada perubahan konfigurasi router."

    echo ""
    echo "CATATAN: Temuan historis memerlukan pembacaan"
    echo "log/screenshot aslinya untuk kesimpulan final."
} 2>&1 | tee "$OUT/10-ringkasan.txt"

echo ""
echo "=============================================="
echo " AUDIT SELESAI - SEMUA FILE DISIMPAN"
echo "=============================================="
