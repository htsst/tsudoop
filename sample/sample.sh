#/bin/bash

## include the following script

. /work0/t2g-compview/sato-h-ac/tsudoop-dev/conf/tsudoop.sh


## write your hadoop operations below

input=$HOME/input

rm -rf $input
hadoop jar $HADOOP_HOME/hadoop-mapred-examples-0.21.0.jar teragen 10000 $input
