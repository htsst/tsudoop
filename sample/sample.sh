#/bin/bash

## include the following script

. /work0/GSIC/apps/tsudoop/conf/tsudoop.sh

## write your hadoop operations below

echo $hadoop_mapred_examples
hadoop jar $hadoop_mapred_examples pi 48 100
