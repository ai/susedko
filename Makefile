# Config

images = $(HOME)/.local/share/libvirt/images
qemu_image = $(images)/fedora-coreos-qemu.qcow2

# Main

.PHONY: clean demo shell test config.bu

test: validate_config

clean:
	rm -Rf config.ign config.bu builder/node_modules
	rm -Rf $(images)
	rm -Rf units/domains/*.crt
	rm -Rf units/domains/*.key
	rm -Rf units/domains/*.pem
	rm -Rf units/domains/*.csr
	podman rmi --all --force

demo: config.ign $(qemu_image) units/domains/ssl.key
	qemu-kvm -m 2048 -cpu host -nographic -snapshot \
	  -drive if=virtio,file=$(qemu_image) \
	  -fw_cfg name=opt/com.coreos/config,file=./config.ign \
	  -nic user,model=virtio,hostfwd=tcp::2222-:22

shell:
	ssh -o "StrictHostKeyChecking=no" -p 2222 ai@localhost

flash: config.ign units/domains/ssl.key
	sudo podman run --pull=always --privileged --rm \
	  -v /dev:/dev -v /run/udev:/run/udev -v .:/data -w /data \
	  quay.io/coreos/coreos-installer:release \
	  install /dev/sda -i ./config.ign

# Utils

builder/node_modules:
	podman run --rm -v "./:/workdir:z" -w /workdir/builder \
	  docker.io/node:18-alpine npm install

config.bu: builder/node_modules units/dockerhub/docker-auth.json units/domains/dhparam.pem
	podman run --rm -v "./:/workdir:z" -w /workdir/builder \
	  docker.io/node:18-alpine node build.js

config.ign: config.bu
	podman run --rm -i \
	  quay.io/coreos/butane:release --strict < ./config.bu > ./config.ign

validate_config: config.ign
	podman run --rm -i \
	  quay.io/coreos/ignition-validate:release - < ./config.ign

$(images):
	mkdir -p $(images)

$(qemu_image): | $(images)
	podman run --rm -v "${images}:/data" -w /data \
    quay.io/coreos/coreos-installer:release download \
	  -s stable -p qemu -f qcow2.xz --decompress -C /data
	mv $(images)/fedora-coreos-*-qemu.x86_64.qcow2 \
	  $(qemu_image)

units/dockerhub/docker-auth.json:
	podman login --authfile units/dockerhub/docker-auth.json

sitniks.key:
	openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 \
	  -keyout sitniks.key -out sitniks.crt -subj "/C=ES/CN=Sitniks"

units/domains/dhparam.pem:
	openssl dhparam -out units/domains/dhparam.pem 4096

units/domains/ssl.key: units/domains/ssl.ext sitniks.key
	openssl req -new -nodes -newkey rsa:2048 \
	  -keyout units/domains/ssl.key -out units/domains/ssl.csr \
	  -subj "/C=ES/ST=Barcelona/L=Barcelona/O=Sitniks/CN=susedko.local"
	openssl x509 -req -sha256 -days 1024 -in units/domains/ssl.csr \
	  -CA sitniks.crt -CAkey sitniks.key -CAcreateserial \
	  -extfile units/domains/ssl.ext -out units/domains/ssl.crt
	rm units/domains/ssl.csr
