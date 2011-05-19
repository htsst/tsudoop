# Copyright (c) 2011 Hitoshi Sato, All rights reserved.

## Configuration
TSUDOOP_DIR=/gscr0/.tsudoop-$USER
TSUDOOP_LOCAL_DIR=/scr/.tsudoop-$USER

HADOOP_HOME=$TSUDOOP_HOME/apps/hadoop-0.20.203.0
JAVA_HOME=$TSUDOOP_HOME/apps/jdk1.6.0_22

#
#

export TSUDOOP_DIR JAVA_HOME HADOOP_HOME 
export PATH=$HADOOP_HOME/bin:$PATH

hadoop_streaming=$HADOOP_HOME/contrib/streaming/hadoop-streaming-*.jar
hadoop_mapred_examples=$HADOOP_HOME/hadoop-examples-*.jar
hadoop_test=$HADOOP_HOME/hadoop-test-*.jar
