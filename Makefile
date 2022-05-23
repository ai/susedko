# Config

images = $(HOME)/.local/share/libvirt/images
qemu_image = $(images)/fedora-coreos-qemu.qcow2

# Main

.PHONY: main clean demo shell

main: config.ign

clean:
	rm -f config.ign
	rm -Rf $(images)
	podman rmi --all

demo: config.ign $(qemu_image)
	qemu-kvm -m 2048 -cpu host -nographic -snapshot \
	  -drive if=virtio,file=$(qemu_image) \
	  -fw_cfg name=opt/com.coreos/config,file=./config.ign \
	  -nic user,model=virtio,hostfwd=tcp::2222-:22

shell:
	ssh -p 2222 core@localhost

# Utils

config.ign: config.bu
	podman run -i --rm quay.io/coreos/butane:release < ./config.bu > ./config.ign

$(images):
	mkdir -p $(images)

$(qemu_image): | $(images)
	podman run --pull=always --rm \
	  -v "${images}:/data" -w /data \
    quay.io/coreos/coreos-installer:release download \
	  -s stable -p qemu -f qcow2.xz --decompress -C /data
	mv $(images)/fedora-coreos-*-qemu.x86_64.qcow2 \
	  $(qemu_image)
