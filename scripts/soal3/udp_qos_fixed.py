import argparse
import socket
import time

p = argparse.ArgumentParser()
p.add_argument("mode", choices=["server", "client"])
p.add_argument("label")
p.add_argument("--count", type=int, default=100)
args = p.parse_args()

PORT = 5003

if args.mode == "server":
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("10.10.30.10", PORT))
    s.settimeout(3)

    print("UDP_SERVER_READY", flush=True)
    received = set()

    while True:
        try:
            data, addr = s.recvfrom(4096)
        except socket.timeout:
            break

        message = data.decode(errors="replace").strip()

        if message.startswith(args.label + ":"):
            received.add(message)

    print("KONDISI:", args.label)
    print("DATAGRAM DIKIRIM:", args.count)
    print("DATAGRAM DITERIMA:", len(received))
    print("DATAGRAM HILANG:", args.count - len(received))
    print("LOSS APLIKASI: %.2f%%" %
          (100 * (args.count - len(received)) / args.count))

    s.close()

else:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    for i in range(args.count):
        data = f"{args.label}:{i:04d}".encode()
        s.sendto(data, ("10.10.30.10", PORT))
        time.sleep(0.02)

    print("DATAGRAM BERHASIL DIKIRIM DARI CLIENT:", args.count)
    s.close()
