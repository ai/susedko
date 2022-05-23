config.ign: config.bu
	podman run -i --rm quay.io/coreos/butane:release < ./config.bu > ./config.ign

main: config.ign

clean:
	rm config.ign
