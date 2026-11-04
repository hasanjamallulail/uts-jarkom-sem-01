# UTS CS238 — Simulasi Jaringan Komputer

## Deskripsi Proyek

Proyek UTS CS238 merupakan implementasi jaringan perusahaan
menggunakan Ubuntu Server, Docker, Containerlab, dan FRRouting.

Topologi menggunakan arsitektur Hub-and-Spoke dengan 14 perangkat
logis yang terdiri dari router, switch, PC client, dan server.

## Teknologi

- Ubuntu Server
- Docker
- Containerlab
- FRRouting
- RIP Version 2
- OSPF
- Netcat
- tcpdump dan TShark
- Linux Traffic Control (tc netem)

## Struktur Proyek

- topology.clab.yml
- topology-next.clab.yml
- topology-rip.clab.yml
- topology-ospf.clab.yml
- configs/ : konfigurasi router
- scripts/ : script eksperimen
- evidence/ : hasil pengujian Soal 1 sampai Soal 5

## Soal 1 — Static Routing

Implementasi static routing, pengujian konektivitas,
traceroute, longest-prefix match, serta simulasi kegagalan link.

Evidence: evidence/soal1/

## Soal 2 — RIP dan OSPF

Implementasi routing dinamis RIP Version 2 dan OSPF.

Pengujian mencakup tabel routing, neighbor OSPF,
konektivitas antarlokasi, kegagalan link, dan pemulihan.

Evidence: evidence/soal2/

## Soal 3 — Transport Layer dan QoS

Pengujian TCP dan UDP pada kondisi layanan aktif dan tidak aktif.

Pengamatan paket menggunakan tcpdump dan TShark.

Eksperimen QoS menggunakan delay 100 ms dan packet loss 10%.

Hasil analisis TCP:
- 5 retransmission
- 4 duplicate ACK
- 2 indikasi previous segment not captured

Evidence: evidence/soal3/

## Soal 4 — Investigasi Gangguan Terintegrasi

Simulasi gangguan routing IP dan layanan TCP secara bersamaan.

Dilakukan diagnosis tiga hipotesis, perbaikan bertahap,
pengujian regresi, dan verifikasi integritas file sebelumnya.

Evidence: evidence/soal4/

## Soal 5 — Evaluasi Arsitektur

Evaluasi risiko single point of failure, salah konfigurasi,
dan degradasi kinerja jaringan.

Rekomendasi meliputi redundansi, monitoring, OSPF,
standardisasi konfigurasi, dan penerapan QoS.

Evidence: evidence/soal5/

## Menjalankan Topologi OSPF

```bash
cd ~/Hasan
sudo containerlab deploy -t topology-ospf.clab.yml
