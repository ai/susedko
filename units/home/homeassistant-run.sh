#!/usr/bin/with-contenv bashio

# Based on https://github.com/tribut/homeassistant-docker-venv

VENV_PATH="${VENV:-/var/tmp/homeassistant-venv}"
CONFIG_PATH=/config

# Create virtual environment

python3 -m venv --system-site-packages $VENV_PATH

. "$VENV_PATH/bin/activate"
export UV_SYSTEM_PYTHON=false

uv --version && uv pip freeze --system|grep ^uv=|xargs uv pip install

HOME="$CONFIG_PATH"
export HOME

# Everything below should be kept in sync with upstream's
#  https://github.com/home-assistant/core/blob/dev/rootfs/etc/services.d/home-assistant/run
cd "$CONFIG_PATH"

# Enable mimalloc for Home Assistant Core, unless disabled
if [[ -z "${DISABLE_JEMALLOC+x}" ]]; then
  export LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"
  export MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:20000,muzzy_decay_ms:20000"
fi

python3 -m homeassistant --config "$CONFIG_PATH"
