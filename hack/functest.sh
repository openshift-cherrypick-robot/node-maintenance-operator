#!/bin/bash -ex

if [ -z "$KUBEVIRTCI_PATH" ]; then
    KUBEVIRTCI_PATH="$(
        cd "$(dirname "$BASH_SOURCE[0]")/"
        readlink -f ../kubevirtci/cluster-up
    )"
fi

if [ -z "$KUBEVIRTCI_CONFIG_PATH" ]; then
    KUBEVIRTCI_CONFIG_PATH="$(
        cd "$(dirname "$BASH_SOURCE[0]")/"
        readlink -f ../_ci-configs
    )"
fi

KUBECTL_CMD="${KUBEVIRTCI_PATH}/kubectl.sh"

# Run tests
if [[ $KUBEVIRT_PROVIDER != "external" ]]; then
    export KUBECONFIG=$(${KUBEVIRTCI_PATH}/kubeconfig.sh)
fi

if [[ $KUBEVIRT_PROVIDER = k8s* ]]; then
    # on k8s we don' t have a etcd-quorum-guard running
    # we need it for testing the master quorum validation
    # so we create a fake etcd-quorum-guard PDB with maxUnavailable = 0, which will always result in disruptionsAllowed = 0 without a corresponding deployment
    # that will make node maintenance requests for master nodes always fail
    $KUBECTL_CMD apply -f test/manifests/fake-etcd-quorum-guard.yaml
fi

# let's track errors on our own here for being able to write a nice comment afterwards
set +e
# FIXME use a different namespace for test deployments, and create / destroy it before / after test execution
TEST_NAMESPACE=node-maintenance GOFLAGS="-mod=vendor" go test -v ./test/e2e/...

if [[ $? != 0 ]]; then
    echo "E2e tests FAILED"
    exit 1
fi

echo "E2e tests passed"
