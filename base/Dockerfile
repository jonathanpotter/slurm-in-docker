#FROM registry.access.redhat.com/rhel7-atomic:7.7
#FROM registry.access.redhat.com/rhel7-minimal
FROM registry.access.redhat.com/rhel7:7.7

MAINTAINER Michael J. Stealey <stealey@renci.org>

# iputils for ping; iproute for ip
ARG PACKAGES="wget tree sudo iputils iproute hostname rpm-build readline-devel pam-devel perl-ExtUtils-MakeMaker perl-Switch gcc make mariadb-server mariadb-devel munge munge-libs munge-devel openssh-server openssh-clients"
ARG TINI_VERSION=0.18.0
ARG TINI_SHA256SUM=eadb9d6e2dc960655481d78a92d2c8bc021861045987ccd3e27c7eae5af0cf33
ARG SLURM_SHA1SUM=6ef212f43df73177ffe83ef2d89f2087e77a7d34

ENV SLURM_VERSION=19.05.4 \
  MUNGE_UID=981 \
  SLURM_UID=982 \
  WORKER_UID=1000

RUN groupadd -g $MUNGE_UID munge \
  && useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGE_UID -g munge  -s /sbin/nologin munge \
  && groupadd -g $SLURM_UID slurm \
  && useradd  -m -c "Slurm workload manager" -d /var/lib/slurm -u $SLURM_UID -g slurm  -s /bin/bash slurm \
  && groupadd -g $WORKER_UID worker \
  && useradd  -m -c "Workflow user" -d /home/worker -u $WORKER_UID -g worker  -s /bin/bash worker

# Get tini
RUN curl \
        --progress-bar \
        --location \
        --fail \
        --show-error \
        https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 \
        -o /usr/local/bin/tini && \
    echo "${TINI_SHA256SUM} /usr/local/bin/tini" | sha256sum -c - && \
    chmod 0755 /usr/local/bin/tini

# install packages for general functionality
RUN yum-config-manager --enable rhel-7-server-optional-rpms && \
    yum install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install ${PACKAGES} && \
    yum clean all

# install slurm 19.05.1 (/usr/bin/mpiexec from slurm-torque conflicts with openmpi install)
RUN curl \
      --progress-bar \
      --location \
      --fail \
      --show-error \
      https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
      -o /root/slurm-${SLURM_VERSION}.tar.bz2 && \
  echo "${SLURM_SHA1SUM} /root/slurm-${SLURM_VERSION}.tar.bz2" | sha1sum -c - && \
  rpmbuild -ta /root/slurm-${SLURM_VERSION}.tar.bz2 && \
  rpm -Uvh $(ls /root/rpmbuild/RPMS/x86_64/*.rpm | grep -v -e 'torque' -e 'openmpi')

VOLUME ["/home", "/.secret"]

#   22:         SSH
# 3306:         MariaDB
# 6817:         Slurm Ctl D
# 6818:         Slurm D
# 6819:         Slurm DBD
EXPOSE 22 3306 6817 6818 6819
