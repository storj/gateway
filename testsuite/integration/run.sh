#!/usr/bin/env bash
set -ueo pipefail
set +x

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $SCRIPTDIR

VERSION=$(go list -m -f "{{.Version}}" storj.io/storj)

go install storj.io/storj/cmd/certificates@$VERSION
go install storj.io/storj/cmd/identity@$VERSION
go install storj.io/storj/cmd/satellite@$VERSION
go install storj.io/storj/cmd/storagenode@$VERSION
go install storj.io/storj/cmd/versioncontrol@$VERSION
go install storj.io/storj/cmd/storj-sim@$VERSION

cd ../.. && go install storj.io/gateway

# setup tmpdir for testfiles and cleanup
TMP=$(mktemp -d -t tmp.XXXXXXXXXX)
cleanup(){
	rm -rf "$TMP"
}
trap cleanup EXIT

export STORJ_NETWORK_DIR=$TMP

STORJ_NETWORK_HOST4=${STORJ_NETWORK_HOST4:-127.0.0.1}
STORJ_SIM_POSTGRES=${STORJ_SIM_POSTGRES:-""}

# setup the network
# if postgres connection string is set as STORJ_SIM_POSTGRES then use that for testing
if [ -z ${STORJ_SIM_POSTGRES} ]; then
	storj-sim -x --satellites 1 --host $STORJ_NETWORK_HOST4 network setup
else
	storj-sim -x --satellites 1 --host $STORJ_NETWORK_HOST4 network --postgres=$STORJ_SIM_POSTGRES setup
fi

# run aws-cli tests
storj-sim -x --satellites 1 --host $STORJ_NETWORK_HOST4 network test bash "$SCRIPTDIR"/awscli.sh
storj-sim -x --satellites 1 --host $STORJ_NETWORK_HOST4 network test bash "$SCRIPTDIR"/duplicity.sh
storj-sim -x --satellites 1 --host $STORJ_NETWORK_HOST4 network test bash "$SCRIPTDIR"/duplicati.sh
storj-sim -x --satellites 1 --host $STORJ_NETWORK_HOST4 network destroy

# setup the network with ipv6
#storj-sim -x --host "::1" network setup
# aws-cli doesn't support gateway with ipv6 address, so change it to use localhost
#find "$STORJ_NETWORK_DIR"/gateway -type f -name config.yaml -exec sed -i 's/server.address: "\[::1\]/server.address: "127.0.0.1/' '{}' +
# run aws-cli tests using ipv6
#storj-sim -x --host "::1" network test bash "$SCRIPTDIR"/script.sh
#storj-sim -x network destroy
