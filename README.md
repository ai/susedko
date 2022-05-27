# Susedko Home Server

[Fedora CoreOS] ignition config for my home server.

[Fedora CoreOS]: https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/


## Development

To test locally or to install image to server’s SD card you need:

```sh
sudo dnf install make podman qemu-system-x86-core
```

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
