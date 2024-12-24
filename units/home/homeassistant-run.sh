#!/usr/bin/with-contenv bashio

USER="home"
GROUP="home"

VENV_PATH="${VENV:-/var/tmp/homeassistant-venv}"
CONFIG_PATH=/config

#
# Create virtual environment
#

bashio::log.info "Initializing venv in $VENV_PATH"
su "$USER" \
  -c "python3 -m venv --system-site-packages '$VENV_PATH'"

#
# Run homeassistant
#

bashio::log.info "Activating venv"
. "$VENV_PATH/bin/activate"
export UV_SYSTEM_PYTHON=false

bashio::log.info "Installing uv into venv"
uv --version && su "$USER" \
  -c "uv pip freeze --system|grep ^uv=|xargs uv pip install"

bashio::log.info "Setting new \$HOME"
HOME="$( getent passwd "$USER" | cut -d: -f6 )"
export HOME

# Everything below should be kept in sync with upstream's
#   https://github.com/home-assistant/core/blob/dev/rootfs/etc/services.d/home-assistant/run
cd "$CONFIG_PATH" || bashio::exit.nok "Can't find config folder: $CONFIG_PATH"

# Enable mimalloc for Home Assistant Core, unless disabled
if [[ -z "${DISABLE_JEMALLOC+x}" ]]; then
  export LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"
  export MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:20000,muzzy_decay_ms:20000"
fi

bashio::log.info "Starting homeassistant"
exec \
  s6-setuidgid "$USER" \
  python3 -m homeassistant --config "$CONFIG_PATH"
