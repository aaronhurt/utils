#!/usr/bin/env bash
## upstream-update.sh
## file revision $Id$
#

## upstream origin
UPSTREAM_ORIGIN="upstream"

## fork origin
FORKED_ORIGIN="origin"

## current branch
CURRENT_BRANCH="master"

## branch arrays
declare -a UPSTREAM_BRANCHES=()
declare -a FORKED_BRANCHES=()
declare -a LOCAL_BRANCHES=()

## check for strings in an array
_check_array() {
	## element iterator
	local element
	## check for element in array
	for element in "${@:2}"; do
		if [ "${element}" == "${1}" ]; then
			## return 0 - element found
			return 0
		fi
	done
	## return 1 - element not found
	return 1
}

## get branches
_get_branches() {
	## get current branch
	CURRENT_BRANCH=$(git branch|grep \*|cut -f2 -d' ')
	## array indexes
	local upstream_idx=0
	local fork_idx=0
	local local_idx=0
	## line iterator
	local line
	## get all branches
	for line in $(git branch -a|awk '{gsub(/^\*[[:space:]]+/, ""); print $1;}'); do
		## skip special
		[[ "${line}" == "+" ]] && continue
		## get first level
		local levelone=$(echo $line|cut -f1 -d/)
		## switch based on first level
		case $levelone in
			remotes)
				## get remote branch levels
				local leveltwo=$(echo $line|cut -f2 -d/)
				local levelthree=$(echo $line|cut -f3- -d/)
				## skip 'HEAD'
				if [ "${levelthree}" == 'HEAD' ]; then
					continue
				fi
				## build upstream array
				if [ "${leveltwo}" == "${UPSTREAM_ORIGIN}" ]; then
					## build upstream array
					UPSTREAM_BRANCHES[$upstream_idx]=${levelthree}
					## increase index
					let "upstream_idx += 1"
				fi
				## build fork array
				if [ "${leveltwo}" == "${FORKED_ORIGIN}" ]; then
					## build fork array
					FORKED_BRANCHES[$fork_idx]=${levelthree}
					## increase index
					let "fork_idx += 1"
				fi
			;;
			*)
				## debug
				echo "local branch: $line"
				## build local array
				LOCAL_BRANCHES[$local_idx]=$line
				## increase index
				let "local_idx += 1"
			;;
		esac
	done
}

## merge branches
_sync_branches() {
	## fetch upstream
	git fetch -v "${UPSTREAM_ORIGIN}"
	## branch interator
	local branch
	## check value
	local check
	## loop through local branches
	for branch in ${LOCAL_BRANCHES[@]:0}; do
		## check upstream branches
		_check_array "${branch}" "${UPSTREAM_BRANCHES[@]}"
		## ensure this branch exists in upstream origin
		if [ $? -ne 0 ]; then
			echo "Skipping local branch (${branch}) not found in upstream origin (${UPSTREAM_ORIGIN})"
			continue
		fi
		## check forked branches
		_check_array "${branch}" "${FORKED_BRANCHES[@]}"
		## ensure this branch exists in forked origin
		if [ $? -ne 0 ]; then
			echo "Skipping local branch (${branch}) not found in upstream origin (${UPSTREAM_ORIGIN})"
			continue
		fi
		## checkout branch
		git checkout "${branch}"
		## pull from origin
		git pull "${FORKED_ORIGIN}" "${branch}"
		## merge with upstream
		git merge "${UPSTREAM_ORIGIN}/${branch}"
		## push back to fork
		git push "${FORKED_ORIGIN}" "${branch}"
	done
	## checkout previous branch
	git checkout "${CURRENT_BRANCH}"
}

## get branches
_get_branches;

## sync branches
_sync_branches;

