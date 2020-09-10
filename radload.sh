#!/usr/bin/env bash

## default values
auth_num=5
acct_num=5
num_tests=5
acct_match="./radtest/acct-*"
auth_match="./radtest/auth-*"
rad_server="localhost"
rad_secret="testing123"

## show help
_show_help() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "    -u    auth requests per run          (default: ${auth_num})"
    echo "    -c    acct requests per run          (default: ${acct_num})"
    echo "    -s    radius server to load test     (default: ${rad_server})"
    echo "    -e    radius auth secret             (default: ${rad_secret})"
    echo "    -n    total number of test cycles    (default: ${num_tests})"
    echo "    -h    show this help message"
    echo ""
    exit 0
}

## get arguments
while getopts "u:c:s:e:n:h" opt; do
    case $opt in
        u)
            ## set auth number
            auth_num=$OPTARG
        ;;
        c)
            ## set acct number
            acct_num=$OPTARG
        ;;
        s)
            ## set server
            rad_server=$OPTARG
        ;;
        e)
            ## set secret
            rad_secret=$OPTARG
        ;;
        n)
            ## set tests
            num_tests=$OPTARG
        ;;
        h)
            ## show help
            _show_help
        ;;
        *)
            ## oops ... this shouldn't happen
            printf "Invalid argument: ${OPTARG}\n"
            ## show help
            _show_help
        ;;
    esac
done

## shift off options
shift $((OPTIND - 1))

## internal break variable
BREAK=0

## catch ctrl+c
_control_c() {
    BREAK=1
}

## trap keyboard interrupt
trap _control_c SIGINT

## build packet files
## $1 = file pattern
## $2 = packet count
_make_packets() {
    local temps=$(mktemp /tmp/radload-temp.XXXXX)
    local count=0

    ## loop to number
    while [ $count -lt ${2} ]; do
        ## loop across files
        for foo in ${1}; do
            ## append to packet file
            cat ${foo} >> ${temps}
            echo >> ${temps}
            ## increase count
            let "count += 1"
         done
    done

    ## return file
    echo ${temps}
}

## radclient auth
## $1 = packet file
_do_auth() {
    ## timeout after 1/4 second per request
    radclient -q -p $auth_num -f "${1}" -r 1 -t $(bc -l <<< "$auth_num * 0.25") \
    ${rad_server} auth ${rad_secret}
}

## radclient accounting
## $1 = packet file
_do_acct() {
    ## timeout after 1/4 second per request
    radclient -q -p ${acct_num} -f "${1}" -r 1 -t $(bc -l <<< "$acct_num * 0.25") \
    ${rad_server} acct ${rad_secret}
}

## main startup
_main() {
    ## init variables
    local tests=0
    local auth_count=0
    local acct_count=0
    local waited=0

    ## build auth file if needed
    if [ $auth_num -gt 0 ]; then
        local auth_data=$(_make_packets "$auth_match" $auth_num)
    fi

    ## build acct file if needed
    if [ $acct_num -gt 0 ]; then
        local acct_data=$(_make_packets "$acct_match" $acct_num)
    fi

    ## start it up ##
    while [ $tests -lt $num_tests ]; do
        ## check break
        if [ $BREAK -ne 0 ]; then
            printf "*** Interrupted - Breaking ****\n"
            break
        fi
        ## run auth tests
        if [ $auth_num -gt 0 ]; then
            _do_auth "${auth_data}" > /dev/null 2>&1 &
        fi
        ## run acct tests
        if [ $acct_num -gt 0 ]; then
            _do_acct "${acct_data}" > /dev/null 2>&1 &
        fi
        ## get process counts
        auth_count=$(ps auxww|grep radclient|grep auth|grep -v grep|wc -l)
        acct_count=$(ps auxww|grep radclient|grep acct|grep -v grep|wc -l)
        ## increase count
        let "tests += 1"
        ## print status
        printf "completed %d of %d requested cycles (outstanding auth: %d acct: %d)\n" \
               ${tests} ${num_tests} ${auth_count} ${acct_count}
    done

    ## cleanup ...
    printf "waiting for remaining processes"

    while [ 1 ]; do
        ## get process counts
        auth_count=$(ps axww|grep radclient|grep auth|grep -v grep|wc -l)
        acct_count=$(ps axww|grep radclient|grep acct|grep -v grep|wc -l)

        ## check wait time
        if [ $waited -gt 3 ]; then
            ## check auth process count
            if [ $auth_count -gt 0 ] || [ $acct_count -gt 0 ]; then
                ## print warning
                printf "killing remaining processes..."
                ## mass kill processes
                ps axww|grep radclient|grep auth|grep -v grep|awk '{print $1}'|xargs kill -9 > /dev/null 2>&1
                ps axww|grep radclient|grep acct|grep -v grep|awk '{print $1}'|xargs kill -9 > /dev/null 2>&1
            fi
            ## break
            break
        fi

        ## check process counts
        if [ $auth_count -gt 0 ] || [ $acct_count -gt 0 ]; then
            ## sleep
            printf "."; sleep 1
        else
            ## break loop
            break
        fi

        ## increase counter
        let "waited += 1"
    done

    ## remove temp files
    rm ${auth_data} > /dev/null 2>&1
    rm ${acct_data} > /dev/null 2>&1

    ## finish up
    printf "done...exiting!\n"
    exit 0
}

## start
_main
