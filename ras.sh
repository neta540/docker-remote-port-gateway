#!/bin/sh

USER_COUNT=${USERS:-5}
USER_START=1
RAS_GROUP="remoteaccess"
KEYS="/root/keys"
HOSTNAME=${HOST:-"gateway"}
SELPORT=${PORT:-22}

PORTA_OFFSET=10000
PORTB_OFFSET=20000
KEYS_SERVER="$KEYS/server"
KEYS_USERS="$KEYS/users"
KEYS_KNOWN_HOSTS="$KEYS_SERVER/known_hosts"

generate_sshd_server_keys() {
    SSH_HOST_KEYS="/etc/ssh"
    if [ ! -f  "$KEYS_SERVER/ssh_host_rsa_key" ]; then
        ssh-keygen -A
        for file in ssh_host_rsa_key ssh_host_dsa_key ssh_host_ecdsa_key ssh_host_ed25519_key; do
            cp "$SSH_HOST_KEYS/$file"  "$KEYS_SERVER/"
            cp "$SSH_HOST_KEYS/$file.pub"  "$KEYS_SERVER/"
        done
    else
        for file in ssh_host_rsa_key ssh_host_dsa_key ssh_host_ecdsa_key ssh_host_ed25519_key; do
            install -m600 "$KEYS_SERVER/$file"  "$SSH_HOST_KEYS/"
            install -m644 "$KEYS_SERVER/$file.pub"  "$SSH_HOST_KEYS/"
        done
    fi
    for file in ssh_host_rsa_key ssh_host_dsa_key ssh_host_ecdsa_key ssh_host_ed25519_key; do
        echo -n "$HOSTNAME:$SELPORT " > "$KEYS_KNOWN_HOSTS/$file.pub"
        cat "$KEYS_SERVER/$file.pub" >> "$KEYS_KNOWN_HOSTS/$file.pub"
    done
}

generate_ras_grp() {
    # create a group for ras users
    ! getent group "$RAS_GROUP" > /dev/null && \
        addgroup "$RAS_GROUP"
}

add_user()
{
    USERID=$1
    USER=$(printf "remote%d" "$USERID")
    # create a single user if it doesn't exist
    ! getent passwd "$USERNAME" > /dev/null && \
    (
        PERCENTAGE_VAL=$(echo "scale=4;$USERID/$USER_COUNT*100" | bc) && \
        PERCENTAGE=$(printf "%0.2f%%" "$PERCENTAGE_VAL") && \
        echo -n "Creating user $USER <=> [$PERCENTAGE] ... " && \
        adduser -D "$USER" && \
        passwd -d "$USER" &>dev/null && \
        adduser "$USER" "$RAS_GROUP" && \
        KEYFILE="$KEYS_USERS/$USER" && \
        (
            if [ ! -f "$KEYFILE" ]; then
                ssh-keygen -q -b 4096 -t rsa -f "$KEYFILE" -N ''
            fi
        ) && \
        PUBKEY="$KEYFILE.pub" && \
        FOLDER="/home/$USER/.ssh" && \
        mkdir -p "$FOLDER" && \
        chown "$USER:$USER" "$FOLDER" && \
        chmod 500 "$FOLDER" && \
        AUTH_KEYS="$FOLDER/authorized_keys" && \
        let PORTA="$USERID + $PORTA_OFFSET" && \
        let PORTB="$USERID + $PORTB_OFFSET" && \
        cat "$PUBKEY" >> "$AUTH_KEYS" && 
        chmod 400 "$AUTH_KEYS" && \
        chown "$USER:$USER" "$AUTH_KEYS" && \
        echo "
Match User $USER
    AllowAgentForwarding no
    PasswordAuthentication no
    X11Forwarding no
    GatewayPorts yes
    PermitTunnel no
    ForceCommand echo 'This account can only be used for forwarding'
    AllowStreamLocalForwarding no
    AllowTcpForwarding remote
    PermitListen 0.0.0.0:$PORTA 0.0.0.0:$PORTB
" >> /etc/ssh/sshd_config
        if [ $? -eq 0 ]; then
            echo "OK";
        else
            echo "FAIL";
        fi
        exit 0;
    )
}

prepare() {
    mkdir -p "$KEYS_USERS"
    mkdir -p "$KEYS_SERVER"
    mkdir -p "$KEYS_KNOWN_HOSTS"
    echo "$HOSTNAME" > /etc/hostname
    generate_sshd_server_keys
    generate_ras_grp
    cp /etc/ras/sshd_config /etc/ssh/sshd_config
    i=$USER_START
    for i in $(seq $USER_START $USER_COUNT); do
        add_user $i
    done
}

prepare
/usr/sbin/sshd -D