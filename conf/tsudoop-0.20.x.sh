#!/bin/bash
# Copyright (c) 2010 2011 Hitoshi Sato. All rights reserved.

## Configuration
. $TSUDOOP_HOME/conf/tsudoop-settings-0.20.x.sh
. $TSUDOOP_HOME/conf/tsudoop-common.sh

#
#

start_tsudoop() {
    echo "creating tsudoop..."

    configure_tsudoop_env

    ## Generate hadoop-env.sh
    hadoop_env_template=$TSUDOOP_HOME/share/0.20.x/hadoop-env-template.sh
    hadoop_env=$HADOOP_CONF_DIR/hadoop-env.sh
    copy_template_file $hadoop_env_template $hadoop_env
    sed -i "s+%%JAVA_HOME%%+$JAVA_HOME+g" $hadoop_env
    sed -i "s+%%HADOOP_LOG_DIR%%+$HADOOP_LOG_DIR+g" $hadoop_env
    sed -i "s+%%HADOOP_PID_DIR%%+$HADOOP_PID_DIR+g" $hadoop_env

    ## Generate core-site.xml
    core_site_template=$TSUDOOP_HOME/share/0.20.x/core-site-template.xml
    core_site=$HADOOP_CONF_DIR/core-site.xml
    copy_template_file $core_site_template $core_site

    hadoop_tmp_dir=$job_local_dir
    [ ! -e $hadoop_tmp_dir ] && mkdir -p $hadoop_tmp_dir
    sed -i "s+%%HADOOP_TMP_DIR%%+$hadoop_tmp_dir+g" $core_site
    
    # fs_default.name="file:///"
    # [ "X$TSUDOOP_FS" = "X" ] && TSUDOOP_FS="lfs" ## default
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	hdfs_port=38001
	fs_default_name="hdfs://$masters:$hdfs_port"	
    else
	fs_default_name="file:///"
    fi
    sed -i "s+%%FS_DEFAULT_NAME%%+$fs_default_name+g" $core_site

    ## Generate hdfs-site.xml
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	hdfs_site_template=$TSUDOOP_HOME/share/0.20.x/hdfs-site-template.xml
	hdfs_site=$HADOOP_CONF_DIR/hdfs-site.xml	
	copy_template_file $hdfs_site_template $hdfs_site
    fi

    ## Generate mapred-site.xml
    mapred_site_template=$TSUDOOP_HOME/share/0.20.x/mapred-site-template.xml
    mapred_site=$HADOOP_CONF_DIR/mapred-site.xml
    copy_template_file $mapred_site_template $mapred_site
    
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
    sed -i "s+%%JOBTRACKER_SYSTEM_DIR%%+$jobtracker_system_dir+g" $mapred_site
    sed -i "s+%%JOBTRACKER_STAGING_ROOT_DIR%%+$jobtracker_staging_root_dir+g" $mapred_site

    if [ "X$map_tasks_maximum" = "X" ]; then
	case $PBS_O_QUEUE in
	    S96 | S | X | Y | R*) map_tasks_maximum=8;;
	    L512 | L256 | L128) map_tasks_maximum=24;;
	    *) map_tasks_maximum=8;;
	esac
    fi
    sed -i "s+%%MAP_TASKS_MAXIMUM%%+$map_tasks_maximum+g" $mapred_site

    if [ "X$reduce_tasks_maximum" = "X" ]; then
	case $PBS_O_QUEUE in 
	    S96 | S | X | Y | R*) reduce_tasks_maximum=3;;
	    L512 | L256 | L128) reduce_tasks_maximum=8;;
	    *) reduce_tasks_maximum=3;;
	esac
    fi
    sed -i "s+%%REDUCE_TASKS_MAXIMUM%%+$reduce_tasks_maximum+g" $mapred_site

    ## Start dfs
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	hadoop namenode -format
	start-dfs.sh
    else # if lfs gpfs
	cd $TMPDIR
    fi

    ## Start mapred
    start-mapred.sh

    sleep 30
    if [ "X$TSUDOOP_FS" = "Xhdfs" ]; then
	while : 
	do
	    sleep 5
	    dfs_report=`hadoop dfsadmin -report`
	    n_dnodes=`echo -e "$dfs_report" | grep available | awk '{ print $3 }'`
	    [ $n_dnodes -gt 0 ] && break
	done
    fi

    confirm_started
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
	
	confirm_finished
	[ "X$save_job_dir" != "X" ] && _save_job_dir

	cleanup
    fi
}

trap stop_tsudoop EXIT INT TERM

cleanup

start_tsudoop

