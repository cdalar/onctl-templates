## Wireguard simple setup

Spin up a wireguard server with a single command.
```
onctl up -n wg -a wireguard/vpn.sh
```

For you mobile devices, install wireguard app and scan the qr code below.
```
http://<IP>/qr.png
```

For your desktop, use the following configuration.
```
http://<IP>/wg-client.conf
```

## Wireguard with multiple clients

Set NUM_OF_CLIENTS parameter to number of clients you need. 
```
onctl up -n wg-multi -a wireguard/multi.sh -e NUM_OF_CLIENTS=5
```

For you mobile devices, install wireguard app and scan the qr code below.
```
http://<IP>/qr-client1.png
http://<IP>/qr-client2.png
http://<IP>/qr-client3.png
http://<IP>/qr-client4.png
http://<IP>/qr-client5.png
```

For your desktop, use the following configuration.
```
http://<IP>/wg-client1.conf
http://<IP>/wg-client2.conf
http://<IP>/wg-client3.conf
http://<IP>/wg-client4.conf
http://<IP>/wg-client5.conf
```
