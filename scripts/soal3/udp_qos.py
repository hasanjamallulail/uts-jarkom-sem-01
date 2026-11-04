import argparse
import socket
import time

p = argparse.ArgumentParser()
p.add_argument("mode", choices=["server", "client"])
p.add_argument("label")
p.add_argument("--count", type=int, default=30)
args = p.parse_args()

if args.mode == "server":
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("10.10.30.10", 5001))
    s.settimeout(4)
    received = set()

    while True:
        try:
            data, address = s.recvfrom(4096)
        except socket.timeout:
            break

        msg = data.decode(errors="replace").strip()

        if msg.startswith(args.label + ":"):
            received.add(msg)

    print("KONDISI:", args.label)
    print("DATAGRAM UNIK DITERIMA:", len(received))
    print("DATAGRAM DIKIRIM:", args.count)
    print("DATAGRAM TIDAK TERCATAT:",
          args.count - len(received))
    print("LOSS APLIKASI:",
          round(100 * (args.count - len(received))
                / args.count, 2), "%")

    s.close()

else:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    for i in range(args.count):
        message = f"{args.label}:{i:03d}".encode()
        s.sendto(message, ("10.10.30.10", 5001))
        time.sleep(0.03)

    print("KONDISI:", args.label)
    print("DATAGRAM DIKIRIM:", args.count)
    s.close()
