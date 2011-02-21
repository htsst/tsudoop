#!/bin/bash
# Copyright (c) 2010 2011 Hitoshi Sato. All rights reserved.

## Configuration
. $TSUDOOP_HOME/conf/tsudoop_settings.sh

#
#

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

    [ "X$job_dir" != "X" ] && rm -rf $job_dir
}

start_tsudoop() {
    echo "creating tsudoop..."

    [ "X$PBS_QUEUE" = "XV" -o  "$PBS_QUEUE" = "XG" ] && error "$PBS_QUEUE queue is not supported."

    ## Get jobid
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
    hadoop_env_template=$TSUDOOP_HOME/share/hadoop-env-t2.sh
    [ ! -e $hadoop_env_template ] && \
	error "hadoop-env-t2.sh not found in $TSUDOOP_HOME/share."
    cp -p $hadoop_env_template $HADOOP_CONF_DIR/hadoop-env.sh

    sed -i "s+%%JAVA_HOME%%+$JAVA_HOME+g" $hadoop_env
    sed -i "s+%%HADOOP_LOG_DIR%%+$HADOOP_LOG_DIR+g" $hadoop_env
    sed -i "s+%%HADOOP_PID_DIR%%+$HADOOP_PID_DIR+g" $hadoop_env

    ## Generate core-site.xml
    core_site=$HADOOP_CONF_DIR/core-site.xml
    core_site_template=$TSUDOOP_HOME/share/core-site-t2.xml
    [ ! -e $core_site_template ] && \
	error "core-site-t2.xml not found in $TSUDOOP_HOME/share."
    cp -p $core_site_template $core_site

    hadoop_tmp_dir=$job_local_dir
    [ ! -e $hadoop_tmp_dir ] && mkdir -p $hadoop_tmp_dir
    sed -i "s+%%HADOOP_TMP_DIR%%+$hadoop_tmp_dir+g" $core_site
    
    # fs_default.name="file:///"
    # [ "X$TSUDOOP_FS" = "X" ] && TSUDOOP_FS="lfs" ## default
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	fs_default_name="hdfs://$masters:38001"	
    else
	fs_default_name="file:///"
    fi
    sed -i "s+%%FS_DEFAULT_NAME%%+$fs_default_name+g" $core_site

    ## Generate hdfs-site.xml
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	hdfs_site=$HADOOP_CONF_DIR/hdfs-site.xml	
	hdfs_site_template=$TSUDOOP_HOME/share/hdfs-site-t2.xml
	[ ! -e $hdfs_site_template ] && \
	    error "hdfs-site-t2.xml not found in $TSUDOOP_HOME/share."
	cp -p $hdfs_site_template $hdfs_site
    fi

    ## Generate mapred-site.xml
    mapred_site=$HADOOP_CONF_DIR/mapred-site.xml
    mapred_site_template=$TSUDOOP_HOME/share/mapred-site-t2.xml
    [ ! -e $mapred_site_template ] && \
	error "mapred-site-t2.xml not found in $TSUDOOP_HOME/share."
    cp -p $mapred_site_template $mapred_site
    
    jobtracker_address="$masters:49004"
    sed -i "s+%%JOBTRACKER_ADDRESS%%+$jobtracker_address+g" $mapred_site

    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
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

    if [ "X$map_tasks_maximum" = "X" ]; then
	case $PBS_O_QUEUE in
	    S96 | S | X) map_tasks_maximum=8;;
	    L512 | L256 | L128) map_tasks_maximum=24;;
	    *) map_tasks_maximum=8;;
	esac
    fi
    sed -i "s+%%MAP_TASKS_MAXIMUM%%+$map_tasks_maximum+g" $mapred_site

    if [ "X$reduce_tasks_maximum" = "X" ]; then
	case $PBS_O_QUEUE in 
	    S96 | S | X) reduce_tasks_maximum=3;;
	    L512 | L256 | L128) reduce_tasks_maximum=8;;
	    *) reduce_tasks_maximum=3;;
	esac
    fi
    sed -i "s+%%REDUCE_TASKS_MAXIMUM%%+$reduce_tasks_maximum+g" $mapred_site

    ## Start dfs
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	hdfs namenode -format
	start-dfs.sh
    fi

    ## Start mapred
    start-mapred.sh

    ## FIXME
    sleep 60

    tsudoop_started=$job_dir/tsudoop_started
    touch $tsudoop_started
}

stop_tsudoop() {
    echo "destroying tsudoop..."
    
    if [ "X$tsudoop_started" != "X" ]; then
	stop-mapred.sh
	wait

	if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	    stop-dfs.sh
	    wait
	fi

	cleanup
	
	rm -rf $tsudoop_started
    fi
}

log() {
    cmd=$*
    id=`echo $PBS_JOBID | sed -e 's/[.].*//'`
    $cmd 2>&1 | tee -a $PBS_O_WORKDIR/$PBS_JOBNAME.t$id
}

trap stop_tsudoop EXIT INT TERM

[ "X$PBS_NODEFILE" != "X" ] && hosts=`cat $PBS_NODEFILE | tr '' '\n'`

cleanup

start_tsudoop

