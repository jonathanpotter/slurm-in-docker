#!/usr/bin/env bash
set -e

# start sshd server
_sshd_host() {
  if [ ! -d /var/run/sshd ]; then
    mkdir /var/run/sshd
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
  fi
  /usr/sbin/sshd
}

# setup worker ssh to be passwordless
_ssh_worker() {
  if [[ ! -d /home/worker ]]; then
    mkdir -p /home/worker
    chown -R worker:worker /home/worker
  fi
  cat > /home/worker/setup-worker-ssh.sh <<'EOFF'
mkdir -p ~/.ssh
chmod 0700 ~/.ssh
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N "" -C "$(whoami)@$(hostname)-$(date -I)"
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
chmod 0640 ~/.ssh/authorized_keys
cat >> ~/.ssh/config <<EOF
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel QUIET
EOF
chmod 0644 ~/.ssh/config
cd ~/
tar -czvf ~/worker-secret.tar.gz .ssh
cd -
EOFF
  chmod +x /home/worker/setup-worker-ssh.sh
  chown worker: /home/worker/setup-worker-ssh.sh
  sudo -u worker /home/worker/setup-worker-ssh.sh
}

# start munge and generate key
_munge_start() {
  chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
  chmod 0700 /etc/munge
  chmod 0711 /var/lib/munge
  chmod 0700 /var/log/munge
  chmod 0755 /var/run/munge
  /sbin/create-munge-key -f
  sudo -u munge /sbin/munged
  munge -n
  munge -n | unmunge
  remunge
}

# copy secrets to /.secret directory for other nodes
_copy_secrets() {
  cp /home/worker/worker-secret.tar.gz /.secret/worker-secret.tar.gz
  cp /home/worker/setup-worker-ssh.sh /.secret/setup-worker-ssh.sh
  cp /etc/munge/munge.key /.secret/munge.key
  rm -f /home/worker/worker-secret.tar.gz
  rm -f /home/worker/setup-worker-ssh.sh
}

# generate slurm.conf
_generate_slurm_conf() {
  cat > /etc/slurm/slurm.conf <<EOF
#
# Example slurm.conf file. Please run configurator.html
# (in doc/html) to build a configuration file customized
# for your environment.
#
#
# slurm.conf file generated by configurator.html.
#
# See the slurm.conf man page for more information.
#
ClusterName=$CLUSTER_NAME
SlurmctldHost=$CONTROL_MACHINE
#SlurmctldHostr=
#
SlurmUser=slurm
#SlurmdUser=root
SlurmctldPort=$SLURMCTLD_PORT
SlurmdPort=$SLURMD_PORT
AuthType=auth/munge
#JobCredentialPrivateKey=
#JobCredentialPublicCertificate=
StateSaveLocation=/var/spool/slurm/ctld
SlurmdSpoolDir=/var/spool/slurm/d
SwitchType=switch/none
MpiDefault=none
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
ProctrackType=proctrack/pgid
#PluginDir=
#FirstJobId=
ReturnToService=0
#MaxJobCount=
#PlugStackConfig=
#PropagatePrioProcess=
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#Prolog=
#Epilog=
#SrunProlog=
#SrunEpilog=
#TaskProlog=
#TaskEpilog=
#TaskPlugin=
#TrackWCKey=no
#TreeWidth=50
#TmpFS=
#UsePAM=
#
# TIMERS
SlurmctldTimeout=300
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0
#
# SCHEDULING
SchedulerType=sched/backfill
#SchedulerAuth=
#SelectType=select/linear
FastSchedule=1
#PriorityType=priority/multifactor
#PriorityDecayHalfLife=14-0
#PriorityUsageResetPeriod=14-0
#PriorityWeightFairshare=100000
#PriorityWeightAge=1000
#PriorityWeightPartition=10000
#PriorityWeightJobSize=1000
#PriorityMaxAge=1-0
#
# LOGGING
SlurmctldDebug=3
SlurmctldLogFile=/var/log/slurmctld.log
SlurmdDebug=3
SlurmdLogFile=/var/log/slurmd.log
JobCompType=jobcomp/none
#JobCompLoc=
#
# ACCOUNTING
JobAcctGatherType=jobacct_gather/linux
#JobAcctGatherFrequency=30
#
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=$ACCOUNTING_STORAGE_HOST
AccountingStoragePort=$ACCOUNTING_STORAGE_PORT
#AccountingStorageLoc=
#AccountingStoragePass=
#AccountingStorageUser=
#
# COMPUTE NODES
NodeName=worker[01-02] RealMemory=1800 CPUs=1 State=UNKNOWN
PartitionName=$PARTITION_NAME Nodes=ALL Default=YES MaxTime=INFINITE State=UP
EOF
}

# run slurmctld
_slurmctld() {
  if $USE_SLURMDBD; then
    echo -n "cheking for slurmdbd.conf"
    while [ ! -f /.secret/slurmdbd.conf ]; do
      echo -n "."
      sleep 1
    done
    echo ""
  fi
  mkdir -p /var/spool/slurm/ctld \
    /var/spool/slurm/d \
    /var/log/slurm
  chown -R slurm: /var/spool/slurm/ctld \
    /var/spool/slurm/d \
    /var/log/slurm
  touch /var/log/slurmctld.log
  chown slurm: /var/log/slurmctld.log
  if [[ ! -f /home/config/slurm.conf ]]; then
    echo "### generate slurm.conf ###"
    _generate_slurm_conf
  else
    echo "### use provided slurm.conf ###"
    cp /home/config/slurm.conf /etc/slurm/slurm.conf
  fi
  sacctmgr -i add cluster "${CLUSTER_NAME}"
  sleep 2s
  /usr/sbin/slurmctld
  cp -f /etc/slurm/slurm.conf /.secret/
}

### main ###
_sshd_host
_ssh_worker
_munge_start
_copy_secrets
_slurmctld

tail -f /dev/null
