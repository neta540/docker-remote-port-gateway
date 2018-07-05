# Docker reverse port gateway

Allows 1-999 users to securely forward two remote ports to this gateway

This server will let clients to connect to it via ssh to forward their ports.

## Usage

### Server

Suppose the server is reachable at gateway.example.com on port 2222 and we would like to allow 10 different clients to connect to it.

```sh
# Build the server
docker build . -t docker-rp-ras
# Use a volume for persistant data
docker volume create rasdata
# Run the server using our configuration
#  - 10 users access
#  - server should be available at: gateway.example.com:2222
docker run --name ras -v rasdata:/root/keys -e USERS=10 -e HOST="gateway.example.com" -e PORT=2222 -p 2222:22 -d docker-rp-ras
```

Generated keys and known_hosts file will be available in rasdata volume. We can copy them to a folder for later use using:

```sh
# Generate a folder to copy RAS data
mkdir data
# Copy RAS data into our folder
docker cp ras:/root/keys/. data
```

Forwarded ports are as follows:

- 10000+UserNumber [1-999]

- 20000+UserNumber [1-999]

So, user remote3 will be allowed to bind only to port 10003 and 20003 on the server.

To let other containers connect to the clients we should link the containers together.

### Clients

To connect to the RAS server we should use the identity file that our server generated earlier. Known hosts file and the identity files will be created on the server /root/keys folder.

Suppose we would like to forward device 3 local port 22 to the server that is on gateway.example.com:2222:

```sh
ssh -i [identity] -o UserKnownHostsFile=[known_host_file] -R 0.0.0.0:10003:localhost:22 -l remote3 -p 2222 gateway.example.com
```

### Accessing Clients services from server

If we would like to connect to the SSH service of remote3 we can connect to it using:

```sh
docker exec -ti ras sh
ssh -p 10003 127.0.0.1
```

Or instead, using a linked container:

```sh
docker run --rm --link ras alpine sh
ssh -p 10003 ras
```
