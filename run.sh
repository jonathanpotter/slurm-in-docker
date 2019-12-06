#!/usr/bin/env bash
#
# Runs containers locally.

IMAGE_TAG=0.0.1
# Container names and associated image in format <CONTAINER_NAME>:<IMAGE>
#CONTAINER_IMAGE_LIST='controller:controller worker01:worker worker02:worker database:database'
CONTAINER_IMAGE_LIST='controller:controller worker01:worker worker02:worker'

# Volumes to share files between nodes.
echo -e "\nCreating volumes...\n"
sudo podman volume create secret > /dev/null
sudo podman volume create home > /dev/null

echo -e "Starting containers..."
for CONTAINER_IMAGE in ${CONTAINER_IMAGE_LIST}; do

  # Parse list into container name and assocaited container image.
  CONTAINER_NAME=$(echo ${CONTAINER_IMAGE} | cut -d: -f1)
  IMAGE=$(echo ${CONTAINER_IMAGE} | cut -d: -f2)

  # Run the container in detached mode on podman network. Silent output.
  sudo podman run -d \
    --net podman \
    --env-file ${IMAGE}/.env \
    --mount 'type=volume,src=secret,dst=/.secret' \
    --mount 'type=volume,src=home,dst=/home' \
    --hostname ${CONTAINER_NAME}.local.dev \
    --name ${CONTAINER_NAME} ${IMAGE}:${IMAGE_TAG} > /dev/null

  # Get IP address and echo it.
  CONTAINER_IP_ADDR=$(sudo podman exec -it ${CONTAINER_NAME} \
    /usr/sbin/ip -f inet addr show dev eth0 | \
    grep inet | \
    cut -d" " -f6 | \
    cut -d"/" -f1)
  echo "  ${CONTAINER_NAME} (${CONTAINER_IP_ADDR})"

done
