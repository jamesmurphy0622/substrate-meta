#!/usr/bin/env bash
# TODO: #2 - Fix error in aria at https://substrate.archive.aws.geometry.io/polkadot/full/
#set -e

if [[ $# -ne 2 ]]; then
  echo "Usage:" >&2
  echo "archive_download.sh <network> <destination_path>" >&2
  echo "network: either 'polkadot' or 'kusama'" >&2
  echo "destination_path: the absolute path for the download (e.g. /data/chains/polkadot/db/full/)" >&2
  echo "CAUTION: the destination_path value will not be validated and contents of directory may be destroyed" >&2
  exit 2
fi

if ! command -v aria2c -h &> /dev/null
then
    echo "aria2c could not be found. Please install https://github.com/aria2/aria2 / \`apt install -y aria2\` / \`brew install aria2\`"
    exit 2
fi

NETWORK=$1
DEST_PATH=$2

# fix destination path trailing slash
[[ $DEST_PATH != */ ]] && DEST_PATH="$DEST_PATH"/

if [ "$NETWORK" == "polkadot" ]
then
  PRIMARY_MANIFEST_LOCATION="https://substrate.archive.aws.geometry.io/polkadot_primary_manifest.txt"
  PARACHAINS_MANIFEST_LOCATION="https://substrate.archive.aws.geometry.io/polkadot_parachains_manifest.txt"
elif [ "$NETWORK" == "kusama" ]
then
  PRIMARY_MANIFEST_LOCATION="https://substrate.archive.aws.geometry.io/kusama_primary_manifest.txt"
  PARACHAINS_MANIFEST_LOCATION="https://substrate.archive.aws.geometry.io/polkadot_parachains_manifest.txt"
else
  echo "Network must be either 'polkadot' or 'kusama'"
  exit 2
fi

run_download() {
  #  https://aria2.github.io/manual/en/html/aria2c.html
  # Use file allocation so if the disk fills up the process should exit.
  curl -s $1 | aria2c -d $2 -c --auto-file-renaming=false --file-allocation=falloc --no-file-allocation-limit=1M -j 25 -i -
}

run_with_resync() {
  # download primary manifest
  MANIFEST=$(curl -s $1)
  primary_manifest_hash=$(echo $MANIFEST | md5sum)
  run_download $1 $2

  MANIFEST=$(curl -s $1)
  if [[ $primary_manifest_hash != $(echo -e $MANIFEST | md5sum) ]] ;
  then
    echo "Running download again as source has been updated since the initial download was started."
    # TODO: Implement a diff to only download new files
#    grep -Fxv $(curl -s $1) $($primary_manifest_hash)
    run_download $1 $2
  else
    echo "No need to download again. Up to date."
  fi
}

echo "Starting primary download..."
run_with_resync $PRIMARY_MANIFEST_LOCAvi TION $2
echo "Starting parachains download..."
run_with_resync $PARACHAINS_MANIFEST_LOCATION $2/parachains/db
