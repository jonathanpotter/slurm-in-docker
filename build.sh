#!/usr/bin/env bash
#
# Builds the container images for cluster.

IMAGE_TAG=0.0.1
#SUBDIR_LIST='base controller worker database'
SUBDIR_LIST='base controller worker'

for SUBDIR in ${SUBDIR_LIST}; do
  sudo podman build -f ${SUBDIR}/Dockerfile -t ${SUBDIR}:${IMAGE_TAG} ./${SUBDIR}
done
