# Susedko Home Server

[Fedora CoreOS] ignition config for my home server.

[Fedora CoreOS]: https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/


## Prepare

To test locally or to flash image to USB drive you need:

```sh
sudo dnf install make podman qemu-system-x86-core
```

Save your Docker.io token to `units/dockerhub/docker-auth.json`:

```json
{
  "auths": {
    "docker.io": {
      "auth": "YOUR_TOKEN"
    }
  }
}
```


## Development

Run in one terminal:

```sh
make demo
```

And then run in another terminal:

```sh
make shell
```

Press <kbd>Ctrl + A</kbd> <kbd>X</kbd> to exit demo server shell.

Call `make clean` to remove all temporary files from the dir and system.


## Install

Insert USB flash drive and call:

```sh
make flash
```

It will write image to `/dev/sda`. Change `Makefile` if you need another path.

Then insert drive to machine and boot it. It will automatically install
system to `/dev/mmcblk1` (change `Makefile` for another drive).


## Other Setup

After re-installing the server you need to prepare some files on HDD.

Create backup:

```sh
borg init --encryption repokey-blake2 ai@susedko.local:/var/mnt/vault/ai/backup
```

Prepare ngrams and copy them to `/var/mnt/vault/.config/ngrams`:

```sh
wget https://languagetool.org/download/ngram-data/ngrams-en-20150817.zip
wget https://languagetool.org/download/ngram-data/ngrams-es-20150915.zip
wget https://languagetool.org/download/ngram-data/untested/ngram-ru-20150914.zip
unzip ngrams-en-20150817.zip
unzip ngrams-es-20150915.zip
unzip ngram-ru-20150914.zip
rm ngram*.zip
```

Set to Nextcloud config at `/var/mnt/vault/nextcloud/config/config.php`:

```php
  'overwrite.cli.url' => 'https://nextcloud.local',
  'overwriteprotocol' => 'https',
```


## Prepare Clients for Local Domains

Install [`./sitniks.crt`](./sitniks.crt) CA certificate to your system.

For MacOS:

```sh
sudo security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain ./sitniks.crt
```

For Linux CLI:

```sh
sudo dnf install nss-tools
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n sitnik -i ~/Dev/susedko/sitniks.crt
sudo cp ~/Dev/susedko/sitniks.crt /etc/pki/ca-trust/source/anchors/sitniks.pem
sudo update-ca-trust
```

For Firefox on Linux: go to `about:preferences#privacy`, click on `View Certificates`, and import `sitniks.crt`.

For Chrome on Linux: go to `chrome://settings/certificates`, click on `Authorities`, and add `sitniks.crt`.
