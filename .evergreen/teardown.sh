#!/usr/bin/env bash
# Handle common teardown actions for drivers-tools.
# This includes mongo-orchestration, load-balancer, docker, and consolidation
# of log files.
# Note: To avoid scope creep, any new functionality should be
# handled in sub-folders with their own setup and teardown scripts.

set -eu

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
. $SCRIPT_DIR/handle-paths.sh

pushd $SCRIPT_DIR

# Stop orchestration if it is running.
if [[ -f "${MONGO_ORCHESTRATION_HOME}/server.log" ]]; then
    # Purposely use sh here to ensure backwards compatibility.
    sh ${DRIVERS_TOOLS}/.evergreen/stop-orchestration.sh
    # Ensure that the logs are accessible to the child log scraper below.
    cp ${MONGO_ORCHESTRATION_HOME}/*.log $DRIVERS_TOOLS/.evergreen/orchestration || true
fi

# Stop the load balancer if it is running.
if [[ -f "$DRIVERS_TOOLS/haproxy.conf" ]]; then
    bash /.evergreen/run-load-balancer.sh stop
fi

# Clean up docker.
bash ./docker/teardown.sh

# Move all child log files into $DRIVERS_TOOLS/.evergreen/test_logs.tar.gz.
LOG_DIR="$(mktemp -d)"
# Prepend the parent directory name to the file name.
find "$(pwd -P)" -name \*.log -exec bash -c 'x="$1"; cp $x '"${LOG_DIR}"'/$(basename $(dirname $x))_$(basename $x)' shell {} \;
# Handle files from the .evergreen directory.
pushd $LOG_DIR
find . -name .evergreen_\* -exec bash -c 'mv $0 ${0/.evergreen_/}' {} \;
popd
# Slurp into a tar file.
tar zcvf "$(pwd -P)/test_logs.tar.gz" -C $LOG_DIR/ .
rm -rf $LOG_DIR

popd
