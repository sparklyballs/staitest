#!/usr/bin/env bash

# shellcheck disable=SC2154
if [[ -n "${TZ}" ]]; then
  echo "Setting timezone to ${TZ}"
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
fi

cd /stai-blockchain || exit 1

# shellcheck disable=SC1091
. ./activate

stai init --fix-ssl-permissions

if [[ ${testnet} == 'true' ]]; then
  echo "configure testnet"
  stai configure --testnet true
fi

if [[ ${keys} == "persistent" ]]; then
  echo "Not touching key directories"
elif [[ ${keys} == "generate" ]]; then
  echo "to use your own keys pass them as a text file -v /path/to/keyfile:/path/in/container and -e keys=\"/path/in/container\""
  stai keys generate
elif [[ ${keys} == "copy" ]]; then
  if [[ -z ${ca} ]]; then
    echo "A path to a copy of the farmer peer's ssl/ca required."
    exit
  else
  stai init -c "${ca}"
  fi
else
  stai keys add -f "${keys}"
fi

for p in ${plots_dir//:/ }; do
  mkdir -p "${p}"
  if [[ ! $(ls -A "$p") ]]; then
    echo "Plots directory '${p}' appears to be empty, try mounting a plot directory with the docker -v command"
  fi
  stai plots add -d "${p}"
done

stai configure --upnp "${upnp}"

if [[ -n "${log_level}" ]]; then
  stai configure --log-level "${log_level}"
fi

if [[ -n "${peer_count}" ]]; then
  stai configure --set-peer-count "${peer_count}"
fi

if [[ -n "${outbound_peer_count}" ]]; then
  stai configure --set_outbound-peer-count "${outbound_peer_count}"
fi

if [[ -n ${farmer_address} && -n ${farmer_port} ]]; then
  stai configure --set-farmer-peer "${farmer_address}:${farmer_port}"
fi

sed -i 's/localhost/127.0.0.1/g' "$STAI_ROOT/config/config.yaml"

if [[ ${log_to_file} != 'true' ]]; then
  sed -i 's/log_stdout: false/log_stdout: true/g' "$STAI_ROOT/config/config.yaml"
else
  sed -i 's/log_stdout: true/log_stdout: false/g' "$STAI_ROOT/config/config.yaml"
fi

# Map deprecated legacy startup options.
if [[ ${farmer} == "true" ]]; then
  service="farmer-only"
elif [[ ${harvester} == "true" ]]; then
  service="harvester"
fi

if [[ ${service} == "harvester" ]]; then
  if [[ -z ${farmer_address} || -z ${farmer_port} || -z ${ca} ]]; then
    echo "A farmer peer address, port, and ca path are required."
    exit
  fi
fi

exec "$@"
