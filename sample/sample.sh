#/bin/bash

## include the following script

. $TSUDOOP_HOME/conf/tsudoop.sh

## write your hadoop operations below

echo $hadoop_mapred_examples
hadoop jar $hadoop_mapred_examples pi 48 100

## use log(), if you want to log the results of the running application.
# log hadoop jar $hadoop_mapred_examples pi 48 100

## use save_job_dir(), if you want to save the job status.
# save_job_dir
