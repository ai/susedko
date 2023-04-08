# Config

images = $(HOME)/.local/share/libvirt/images
qemu_image = $(images)/fedora-coreos-qemu.qcow2
install_to_disk = /dev/mmcblk1
flash_drive = /dev/sda
ssl_ca = "/C=ES/CN=Sitniks"
ssl_by = "/C=ES/ST=Barcelona/L=Barcelona/O=Sitniks/CN=susedko.local"

# Main

.PHONY: clean demo shell test flash demo.bu config.bu

test: validate_config

clean:
	rm -Rf *.ign *.bu *.iso builder/node_modules
	rm -Rf units/domains/*.{crt,key,pem,csr}
	rm -Rf $(images)
	podman rmi --all --force

demo: demo.ign $(qemu_image)
	qemu-kvm -m 2048 -cpu host -nographic -snapshot \
	  -drive if=virtio,file=$(qemu_image) \
	  -fw_cfg name=opt/com.coreos/config,file=./demo.ign \
	  -nic user,model=virtio,hostfwd=tcp::2222-:22,hostfwd=tcp::8443-:443,hostfwd=tcp::9091-:9091,hostfwd=tcp::9092-:9092,hostfwd=tcp::8096-:8096

shell:
	ssh -o "StrictHostKeyChecking=no" -p 2222 ai@localhost

flash: config.ign fedora-coreos.iso
	rm -f ./flash.iso
	podman run --privileged --rm -v .:/data -w /data \
	  quay.io/coreos/coreos-installer:release iso customize \
		 --dest-ignition config.ign \
		 --dest-device $(install_to_disk) \
		 -o ./flash.iso \
		./fedora-coreos.iso
	sudo fdisk -l $(flash_drive)
	@echo "Press Enter to flash drive or Ctrl+C to cancel"
	@read
	sudo dd if=./flash.iso of=$(flash_drive) bs=1M status=progress
	rm ./flash.iso
	sudo umount $(flash_drive)1

# Utils

builder/node_modules:
	podman run --rm -v "./:/workdir:z" -w /workdir/builder \
	  docker.io/node:18-alpine npm install

config.bu: builder/node_modules units/dockerhub/docker-auth.json units/domains/ssl.key secrets.env
	podman run --rm -v "./:/workdir:z" -w /workdir/builder \
	  docker.io/node:18-alpine node build.js

config.ign: config.bu
	podman run --rm -i \
	  quay.io/coreos/butane:release --strict < ./config.bu > ./config.ign

demo.bu: builder/node_modules units/dockerhub/docker-auth.json units/domains/ssl.key secrets.env
	podman run --rm -v "./:/workdir:z" -w /workdir/builder \
	  -e DEMO=1 \
	  docker.io/node:18-alpine node build.js

demo.ign: demo.bu
	podman run --rm -i \
	  quay.io/coreos/butane:release --strict < ./demo.bu > ./demo.ign

validate_config: config.ign
	podman run --rm -i \
	  quay.io/coreos/ignition-validate:release - < ./config.ign

fedora-coreos.iso:
	podman run --security-opt label=disable --rm -v .:/data -w /data \
    quay.io/coreos/coreos-installer:release download -s stable -p metal -f iso
	rm ./fedora-coreos-*.iso.*
	mv ./fedora-coreos-*.iso ./fedora-coreos.iso

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

sitniks.key: sitniks.ini
	openssl genpkey -out sitniks.key -algorithm RSA \
	  -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:65537
	openssl req -new -key sitniks.key -extensions v3_ca -batch -out sitniks.csr \
	  -utf8 -subj $(ssl_ca)
	openssl x509 -req -sha256 -days 1461 -in sitniks.csr -signkey sitniks.key \
	  -extfile sitniks.ini -out sitniks.crt
	rm sitniks.csr

units/domains/dhparam.pem:
	openssl dhparam -out units/domains/dhparam.pem 4096

units/domains/ssl.key: units/domains/ssl.ini sitniks.key units/domains/dhparam.pem
	openssl genpkey -out units/domains/ssl.key -algorithm RSA \
	  -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:65537
	openssl req -new -key units/domains/ssl.key -days 1461 -extensions v3_ca \
	  -batch -out units/domains/ssl.csr -utf8 -subj $(ssl_by)
	openssl x509 -req -sha256 -days 1461 -in units/domains/ssl.csr \
	  -CAkey sitniks.key -CA sitniks.crt -out units/domains/ssl.crt \
	  -extfile units/domains/ssl.ini
	rm units/domains/ssl.csr

secrets.env:
	echo "AI_PASSWORD=$$(dd bs=512 if=/dev/urandom count=1 2>/dev/null | tr -dc '[:alpha:]' | fold -w $${1:-16} | head -n 1)" > secrets.env
