#!/bin/bash
# Copyright (c) 2010 2011 Hitoshi Sato. All rights reserved.

if [ "X$HADOOP_VERSION" = "X0.21" ]; then
    . $TSUDOOP_HOME/conf/tsudoop-0.21.x.sh
else
    . $TSUDOOP_HOME/conf/tsudoop-0.20.x.sh
fi
