#!/bin/bash
# Copyright (c) 2010 Hitoshi Sato. All rights reserved.

## Configuration
. $TSUDOOP_HOME/conf/tsudoop_settings.sh

[ "X$TSUDOOP_FS" = "X" ] && TSUDOOP_FS="hdfs" ## default
echo $TSUDOOP_FS

#
#

[ "X$PBS_NODEFILE" != "X" ] && hosts=`cat $PBS_NODEFILE | tr '' '\n'`

error() {
    echo "ERROR: $1 "
    exit 1
}

cleanup() {
    for host in $hosts
    do
	killall -9 java
	[ "X$job_local_dir" != "X" ] && ssh $host rm -rf $job_local_dir
	ssh $host rm -rf /scr/*
    done
}

start_tsudoop() {
    echo "creating tsudoop..."

    ## Get jobid ## TODO : use PBS_JOBID 
    # tsudoop_id=$USER-`date "+%Y-%m-%d-%H-%M-%S"`
    tsudoop_id=$USER-$PBS_JOBID

    ## Configure environments
    [ "X$TSUDOOP_DIR" = "X" ] && error "TSUDOOP_DIR is not set."
    [ ! -e $TSUDOOP_DIR ] && mkdir -p $TSUDOOP_DIR

    job_dir=$TSUDOOP_DIR/$tsudoop_id
    [ ! -e $job_dir ] && mkdir -p $job_dir
    echo $tsudoop_id > $job_dir/tsudoop_id

    job_local_dir=$TSUDOOP_LOCAL_DIR/$tsudoop_id
    [ ! -e $job_local_dir ] && mkdir -p $job_local_dir

    export HADOOP_CONF_DIR=$job_dir/conf    
    [ "X$HADOOP_HOME" = "X" ] && error "HADOOP_HOME is not set."
    [ ! -e $HADOOP_CONF_DIR ] && cp -rp $HADOOP_HOME/conf $HADOOP_CONF_DIR

    export HADOOP_LOG_DIR=$job_dir/logs
    [ ! -e $HADOOP_LOG_DIR ] && mkdir -p $HADOOP_LOG_DIR

    export HADOOP_PID_DIR=$job_local_dir/pids
    [ ! -e $HADOOP_PID_DIR ] && mkdir -p $HADOOP_PID_DIR

    ## Get masters and slaves from $PBS_NODEFILE
    masters=`echo $hosts | awk '{ print $1 }'`
    [ "X$masters" = "X" ] && error "no masters."
    echo $masters > $HADOOP_CONF_DIR/masters

    slaves=`echo $hosts | awk '{ $1=""; print }'`
    [ "X$slaves" = "X" ] && error "no slaves."
    echo $slaves > $HADOOP_CONF_DIR/slaves

    ## Generate hadoop-env.sh
    hadoop_env=$HADOOP_CONF_DIR/hadoop-env.sh
    hadoop_env_template=$HADOOP_HOME/conf/hadoop-env-t2.sh
    [ ! -e $hadoop_env_template ] && \
	error "Install hadoop-env-t2.sh to $hadoop_env_template."
    cp -p $hadoop_env_template $HADOOP_CONF_DIR/hadoop-env.sh

    sed -i "s+%%JAVA_HOME%%+$JAVA_HOME+g" $hadoop_env
    sed -i "s+%%HADOOP_LOG_DIR%%+$HADOOP_LOG_DIR+g" $hadoop_env
    sed -i "s+%%HADOOP_PID_DIR%%+$HADOOP_PID_DIR+g" $hadoop_env

    ## Generate core-site.xml
    core_site=$HADOOP_CONF_DIR/core-site.xml
    core_site_template=$HADOOP_HOME/conf/core-site-t2.xml
    [ ! -e $core_site_template ] && \
	error "Install core-site-t2.xml to $core_site_template ."
    cp -p $core_site_template $core_site

    hadoop_tmp_dir=$job_local_dir
    [ ! -e $hadoop_tmp_dir ] && mkdir -p $hadoop_tmp_dir
    sed -i "s+%%HADOOP_TMP_DIR%%+$hadoop_tmp_dir+g" $core_site
    
    # fs_default.name="file:///"
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; 
    then
	fs_default_name="hdfs://$masters:38001"	
    else
	fs_default_name="file:///work0/t2g-compview/sato-h-ac"
    fi
    sed -i "s+%%FS_DEFAULT_NAME%%+$fs_default_name+g" $core_site

 ## Generate hdfs-site.xml
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; 
    then
	echo "test"
	hdfs_site=$HADOOP_CONF_DIR/hdfs-site.xml	
	hdfs_site_template=$HADOOP_HOME/conf/hdfs-site-t2.xml
	[ ! -e $hdfs_site_template ] && \
	    error "Install hdfs-site-t2.xml to $hdfs_site_template ."
	cp -p $hdfs_site_template $hdfs_site
    fi

    ## Generate mapred-site.xml
    mapred_site=$HADOOP_CONF_DIR/mapred-site.xml
    mapred_site_template=$HADOOP_HOME/conf/mapred-site-t2.xml
    [ ! -e $mapred_site_template ] && \
	error "Install mapred-site-t2.xml to $mapred_site_template ."
    cp -p $mapred_site_template $mapred_site
    
    jobtracker_address="$masters:49004"
    sed -i "s+%%JOBTRACKER_ADDRESS%%+$jobtracker_address+g" $mapred_site

    if [ "X$TSUDOOP_FS" = "Xhdfs" ];
    then
	jobtracker_system_dir="/hadoop/mapred/system"
	jobtracker_staging_root_dir="/hadoop/mapred/staging"
    else
	jobtracker_system_dir=$job_dir/mapred/system
	mkdir -p $jobtracker_system_dir

	jobtracker_staging_root_dir=$job_dir/mapred/staging
	mkdir -p $jobtracker_staging_root_dir
    fi
    echo $jobtracker_system_dir
    sed -i "s+%%JOBTRACKER_SYSTEM_DIR%%+$jobtracker_system_dir+g" $mapred_site
    echo $jobtracker_staging_root_dir
    sed -i "s+%%JOBTRACKER_STAGING_ROOT_DIR%%+$jobtracker_staging_root_dir+g" $mapred_site

    case $PBS_O_QUEUE in
	S96) map_tasks_maximum=8; reduce_tasks_maximum=3;;
	*) map_tasks_maximum=8; reduce_tasks_maximum=3;;
    esac
    sed -i "s+%%MAP_TASKS_MAXIMUM%%+$map_tasks_maximum+g" $mapred_site
    sed -i "s+%%REDUCE_TASKS_MAXIMUM%%+$reduce_tasks_maximum+g" $mapred_site

    ## Start dfs
    if [ "X$TSUDOOP_FS" = "Xhdfs" ] 
    then
	hdfs namenode -format
	start-dfs.sh
    fi

    ## Start mapred
    start-mapred.sh

    sleep 60

    tsudoop_started=$job_dir/tsudoop_started
    touch $tsudoop_started
}

stop_tsudoop() {
    echo "destroying tsudoop..."
    
    if [ "X$tsudoop_started" != "X" ]
    then
	stop-mapred.sh
	wait

	if [ "X$TSUDOOP_FS" = "Xhdfs" ]
	then
	    stop-dfs.sh
	    wait
	fi

	cleanup
	
	rm -rf $tsudoop_started
    fi
}

log() {
    cmd=$*
    $cmd 2>&1 | tee -a $HADOOP_LOG_DIR/program.log
}

trap stop_tsudoop EXIT INT TERM

cleanup

start_tsudoop

