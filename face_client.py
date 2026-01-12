import socket, json


SOCKET= "/tmp/faceunlock.sock"

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

s.connect(SOCKET)
s.send(json.dumps({"user": "chinmay"}).encode())

resp  = json.loads(s.recv(1024))

print(resp)


s.close()