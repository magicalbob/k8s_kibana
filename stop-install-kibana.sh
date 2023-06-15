#!/usr/bin/env bash

PROC_IDS=$(ps xa|grep ./install-kibana.sh|grep -v grep|cut -d\  -f1)
if [[ "x$PROC_IDS" != "x" ]] ; then
  kill $PROC_IDS
fi
