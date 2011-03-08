
export TSUDOOP_DIR JAVA_HOME HADOOP_HOME 
export PATH=$HADOOP_HOME/bin:$PATH

[ "X$PBS_NODEFILE" != "X" ] && hosts=`cat $PBS_NODEFILE | tr '' '\n'`

error() {
    echo "ERROR: $1 "
    exit 1
}

cleanup() {
    for host in $hosts
    do
        for job in `jobs -p`; do kill -9 $job; done
        [ "X$job_local_dir" != "X" ] && ssh $host rm -rf $job_local_dir
        ssh $host rm -rf /scr/*
    done

    [ "X$job_dir" != "X" ] && rm -rf $job_dir
}

configure_tsudoop_env() {

    [ "X$PBS_QUEUE" = "XV" -o  "$PBS_QUEUE" = "XG" ] && error "$PBS_QUEUE queue is not supported."

    ## Get jobid
    tsudoop_id=$USER-$PBS_JOBID

    [ "X$TSUDOOP_DIR" = "X" ] && error "TSUDOOP_DIR is not set."
    [ ! -e $TSUDOOP_DIR ] && mkdir -p $TSUDOOP_DIR

        job_dir=$TSUDOOP_DIR/$tsudoop_id
    [ ! -e $job_dir ] && mkdir -p $job_dir
    echo $tsudoop_id > $job_dir/tsudoop_id

    job_local_dir=$TSUDOOP_LOCAL_DIR/$tsudoop_id
    [ ! -e $job_local_dir ] && mkdir -p $job_local_dir

    export HADOOP_CONF_DIR=$job_dir/conf
    [ ! -e $HADOOP_CONF_DIR ] && cp -rp $HADOOP_HOME/conf $HADOOP_CONF_DIR
    [ "X$HADOOP_HOME" = "X" ] && error "HADOOP_HOME is not set."

    export HADOOP_LOG_DIR=$job_dir/logs
    [ ! -e $HADOOP_LOG_DIR ] && mkdir -p $HADOOP_LOG_DIR
    history_dir=$HADOOP_LOG_DIR/history

    export HADOOP_PID_DIR=$job_local_dir/pids
    [ ! -e $HADOOP_PID_DIR ] && mkdir -p $HADOOP_PID_DIR

    ## Get masters and slaves from $PBS_NODEFILE
    masters=`echo $hosts | awk '{ print $1 }'`
    [ "X$masters" = "X" ] && error "no masters."
    echo $masters > $HADOOP_CONF_DIR/masters

    slaves=`echo $hosts | awk '{ $1=""; print }'`
    [ "X$slaves" = "X" ] && error "no slaves."
    echo $slaves > $HADOOP_CONF_DIR/slaves
}

copy_template_file() {
    template_file=$1
    original_file=$2

    [ ! -e $template_file ] && \
	error "$template_file not found."
    cp -p $template_file $original_file
}

confirm_started() {
    tsudoop_started=$job_dir/tsudoop_started
    touch $tsudoop_started
}

confirm_finished() {
    echo "confirm_finished $tsudoop_started"
    rm -rfv $tsudoop_started
}

#is_started() {
#
# }

get_jobid_lists() {
    echo `ls -t $history_dir | grep _conf.xml | sed -e 's/_conf.xml//g'`
}

get_html() {
    target_jsp=$1
    output_html=$2

    jobtracker_http=http://$masters:50030

    wget $jobtracker_http/$target_jsp -O $output_html # > /dev/null  2>&1
}

do_monitor() {
    jobid=$1

    sleep 5

    dir=$html_dir/$jobid
    [ ! -e $dir ] && mkdir -p $dir

    [ ! -e $history_dir/$jobid\_conf.xml ] && return

    jobdetails_file=$dir/jobdetails_$jobid.html
    taskgraph_map_file=$dir/taskgraph_map_$jobid.html
    taskgraph_reduce_file=$dir/taskgraph_reduce_$jobid.html

    get_html "jobdetails.jsp?jobid=$jobid&map.graph=on" \
	$jobdetails_file
    get_html "jobtasks.jsp?jobid=$jobid&type=map&pagenum=1" map.html
    get_html "jobtasks.jsp?jobid=$jobid&type=reduce&pagenum=1"  reduce.html
    get_html "taskgraph?type=map&jobid=$jobid" $taskgraph_map_file
    get_html "taskgraph?type=reduce&jobid=$jobid" \
	$taskgraph_reduce_file

    sed -i "s+/static/hadoop.css+../hadoop.css+g" $jobdetails_file
    sed -i "s+/taskgraph?type=map&jobid=$jobid+taskgraph_map_$jobid.html+g" $jobdetails_file
    sed -i "s+/taskgraph?type=reduce&jobid=$jobid+taskgraph_reduce_$jobid.html+g" $jobdetails_file
    
}

_monitoring() {
    unset http_proxy
    unset https_proxy

    html_dir=$job_dir/html
    mkdir -p $html_dir

    cp -p $HADOOP_HOME/webapps/static/hadoop.css $html_dir/hadoop.css
    
    sleep 5
    while :
    do
	jobid_lists=`get_jobid_lists`
	echo "jobid_lists $jobid_lists"
	[ "X$jobid_lists" = "X" ] && break

	for jobid in $jobid_lists
	do
	    do_monitor $jobid # &
	done
    done
}

monitoring() {
    _monitoring &
}

log() {
    cmd=$*
    id=`echo $PBS_JOBID | sed -e 's/[.].*//'`
    $cmd 2>&1 | tee -a $PBS_O_WORKDIR/$PBS_JOBNAME.t$id
}

_save_job_dir() {
    echo $1
    cp -r $job_dir $PBS_O_WORKDIR
}

save_job_dir() {
    save_job_dir=true
}