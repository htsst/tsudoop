#!/bin/bash

## include the following script
. $TSUDOOP_HOME/conf/tsudoop.sh

## 
dir=$PBS_O_WORKDIR

program=file:$dir/wordcount
input=$dir/input
output=$dir/output

rm -rf $input
rm -rf $output

cp -r $TSUDOOP_HOME/apps/hadoop-*/conf  $dir/input

log hadoop pipes -D mapreduce.pipes.isjavarecordreader=true -D mapreduce.pipes.isjavarecordwriter=true -program $program -input $input -output $output


