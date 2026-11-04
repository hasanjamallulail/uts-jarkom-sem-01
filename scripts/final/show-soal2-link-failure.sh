#!/usr/bin/env bash
set -uo pipefail

cd "$HOME/Hasan" || exit 1

OUT="evidence/laporan/soal2"
mkdir -p "$OUT"

{
    echo "=================================================="
    echo " UTS CS238 - SOAL 2(ii)"
    echo " PERBANDINGAN LINK FAILURE RIP VS OSPF"
    echo "=================================================="

    for PROTO in rip ospf; do

        FILE="evidence/soal2/$PROTO/$PROTO-link-failure.txt"

        echo ""
        echo "=================================================="
        echo " PROTOKOL: ${PROTO^^}"
        echo "=================================================="

        if [ ! -f "$FILE" ]; then
            echo "Evidence tidak ditemukan: $FILE"
            continue
        fi

        echo ""
        echo "===== 1. BAGIAN PENGUJIAN DALAM LOG ====="
        grep -nEi \
          'baseline|sebelum|link down|routing|tabel|ping|pemulihan|setelah|interface|traceroute' \
          "$FILE" | head -n 45 || true

        echo ""
        echo "===== 2. HASIL PING ====="
        grep -E \
          'packets transmitted|packet loss|round-trip' \
          "$FILE" || true

        echo ""
        echo "===== 3. STATUS DAN RUTE YANG TERCATAT ====="
        grep -E \
          'state (UP|DOWN)|R>\*|O>\*|Full/|via 10\.0\.0\.' \
          "$FILE" | head -n 35 || true

        echo ""
        echo "===== 4. BAGIAN AKHIR LOG ====="
        tail -n 22 "$FILE"

    done

    echo ""
    echo "=================================================="
    echo " CATATAN METODOLOGI"
    echo "=================================================="
    echo "1. Data RIP dan OSPF berasal dari eksperimen terpisah."
    echo "2. Ping segera setelah link UP bukan bukti waktu konvergensi."
    echo "3. Waktu pemulihan belum terukur secara kontinu."
    echo "4. Jalur alternatif BR1-HQ tidak tersedia."
    echo "5. Tidak ada konfigurasi yang diubah."

    echo ""
    echo "SOAL 2(ii) - PEMERIKSAAN SELESAI"

} 2>&1 | tee "$OUT/02-link-failure-rip-ospf.txt"
