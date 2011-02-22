# Copyright (c) 2011 Hitoshi Sato, All rights reserved.

## Configuration

#TSUDOOP_DIR=$HOME/.tsudoop
#TSUDOOP_DIR=/work0/t2g-compview/.tsudoop-$USER
TSUDOOP_DIR=/gscr0/.tsudoop-$USER
TSUDOOP_LOCAL_DIR=/scr/.tsudoop-$USER
#TSUDOOP_DIR=/gscr0/.tsudoop-$USER

JAVA_HOME=$TSUDOOP_HOME/apps/jdk1.6.0_22
HADOOP_HOME=$TSUDOOP_HOME/apps/hadoop-0.21.0

#
#

export TSUDOOP_DIR JAVA_HOME HADOOP_HOME 
export PATH=$HADOOP_HOME/bin:$PATH

hadoop_streaming=$HADOOP_HOME/mapred/contrib/streaming/hadoop-*-streaming.jar
hadoop_mapred_examples=$HADOOP_HOME/hadoop-mapred-examples-*.jar
hadoop_test=$HADOOP_HOME/hadoop-mapred-test-*.jar

