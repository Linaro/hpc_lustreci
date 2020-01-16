#!/bin/bash

export PDSH_SSH_ARGS_APPEND='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /root/.ssh/lustrecluster'
cd /lib64/lustre/tests && ./llmount.sh -f cfg/lustretestcentos8.sh && NAME=lustretestcentos8 sh ./sanity.sh
