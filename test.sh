#!/usr/bin/env bash
#
# Tests all the containers in the cluster.

set +e

# Test ssh with key-based authentication from worker to controller.
test_ssh() {
  CONTROLLER_IP=$(sudo podman exec controller ip -f inet addr show dev eth0 | \
    grep inet | \
    cut -d" " -f6 | \
    cut -d"/" -f1)
  if [ $? -ne 0 ]; then
    echo "Error: Could not get controller ip address."
    exit 1
  fi

  CONTROLLER_HOSTNAME=$(sudo podman exec controller cat /etc/hostname)
  if [ $? -ne 0 ]; then
    echo "Error: Could not get controller hostname."
    exit 1
  fi

  CONTROLLER_HOSTNAME_FROM_SSH=$(sudo podman exec -u worker worker01 ssh ${CONTROLLER_IP} cat /etc/hostname)
  if [ $? -ne 0 ]; then
    echo "Error: Could not ssh to controller."
    exit 1
  fi

  if [ "${CONTROLLER_HOSTNAME}" == "${CONTROLLER_HOSTNAME_FROM_SSH}" ]; then
    echo "SSH test passed."
  else
    echo "Error: SSH test failed."
  fi
}

######################
# Main
######################

test_ssh

# Test MariaDB.
# sudo podman exec -ti database mysql -uslurm -ppassword -hdatabase.local.dev
# if [ $? -eq 0 ]; then
#   echo "MariaDB test passed."
# else
#   echo "Error: MariaDB test failed."
#   exit 1
# fi
