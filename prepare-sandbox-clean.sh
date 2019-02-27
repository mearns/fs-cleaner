#!/bin/bash
###
# See help() function below for docs.
#
# Copyright (c) 2019 Brian Mearns - Licensed under MIT license (see LICENSE file)
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
###

VERSION=1
DATE=2019-02-27

function usage () {
    echo "Usage: `basename $0` [-U] [-d MAX_DEPTH(=${DEFAULT_MAX_DEPTH})] [-a MIN_AGE_DAYS(=${DEFAULT_MIN_DAYS_OLD})] DIR [DIR [...]]"
}

function help () {
    echo "Scan the specified DIR(s) for git repos that can likely be cleaned up"
    echo "and output a cleanup file describing the findings. The generated output"
    echo "should be reviewed and edited before passing it to execute-cleanup"
    echo "to actually perform the cleanup described in the file"
    echo
    echo "Options:"
    echo "  -U              Generate an *unsafe* clean script, which"
    echo "                  removes determined directories by default"
    echo 
    echo "  -d MAX_DEPTH    The maximum recursion depth. Default is ${DEFAULT_MAX_DEPTH}."
    echo
    echo "  -a MIN_AGE_DAYS The minimum age (in days) of directories that"
    echo "                  will be determined eligible for deletion."
    echo "                  Defaut is ${DEFAULT_MIN_DAYS_OLD}."
    echo
    echo "  -u              Print usage message and exit with 0."
    echo
    echo "  -h              Print this help message and exit with 0."
    echo
    echo "By default, the generated cleanup file will use the 'recommend-clean'"
    echo "command for each directory that is considered ready for removal, which"
    echo "will not actually result in any cleanup action being taken by"
    echo "execute-cleanup. This is to give you a chance to review the cleanup"
    echo "before executing it, taking the safe option if you don't do anything."
    echo
    echo "If you trust the results, or are otherwise reckless, you can use"
    echo "the -U option to create an 'unsafe' cleanup file that specifies"
    echo "the 'clean' command."
}

DEFAULT_SAFE=1
DEFAULT_MIN_DAYS_OLD=90
DEFAULT_MAX_DEPTH=4
QUIET=0

SAFE=$DEFAULT_SAFE
MIN_DAYS_OLD=$DEFAULT_MIN_DAYS_OLD
MAX_DEPTH=$DEFAULT_MAX_DEPTH

ORIGINAL_ARGS="$*"
args=`getopt Uuqd:a:h $*`
if [ $? != 0 ]
then
       usage >&2
       exit 2
fi
set -- $args
for i
do
   case "$i"
   in
       -U) SAFE=0; shift ;;
       -q) let "QUIET = $QUIET + 1" ; shift ;;
       -d) MAX_DEPTH=$2; shift ; shift ;;
       -a) MIN_DAYS_OLD=$2; shift ; shift ;;
       -u)
        shift
        usage
        echo
        exit 0
        ;;

       -h)
        shift
        echo "prepare-sandbox-clean v${VERSION} - ${DATE}"
        echo
        usage
        echo
        help
        echo
        exit 0
        ;;

       --) shift; break ;;
       #*) echo "Unhandled option: $i" >&2 ; exit 1 ;;
   esac
done

if [ $# -lt 1 ]
then
    echo "Error: At least one DIR argument must be specified." >&2
    usage >&2
    exit 2
fi

CLEAN_COMMAND=recommend-clean
if [[ "$SAFE" -eq "0" ]]
then
    CLEAN_COMMAND=clean
fi

for DIR in $*
do
    if [[ "$QUIET" -lt 1 ]]
    then
        echo "#!execute-cleanup.sh"
        echo
        echo "#"
        echo "# This is a cleanup script. Any line starting with '#' will be ignored."
        echo "# Review the contents of this file and ensure that each command is as"
        echo "# it should be for each item, then pass this file to execute-cleanup"
        echo "# to actually execute the included commands."
        echo "#"
        echo "# Commands recognized by execute-cleanup are:"
        echo "#  * 'clean' - Remove the item from the fileystem. This is typically a"
        echo "#     permanent deletion of the directory and all it's contents,"
        echo "#     recursively, but that may depend on the options passed to"
        echo "#     execute-cleanup."
        echo "#"
        echo "#  * 'consider-clean' - These items will not be acted on except for"
        echo "#     a possible warning issued by execute-cleanup that you haven't"
        echo "#     made a decision on them. If you have considered them and decided"
        echo "#     not to have them cleaned, it is generally advisable to delete"
        echo "#     the line form this file (or at least comment it out with a"
        echo "#     leading '#')."
        echo "#"
        echo "# You can execute the suggested commands (lines beginning with '#>')"
        echo "# to gather more information about the item. Copy and paste the"
        echo "# command into your terminal, or use \`execute-cleanup -x CMDID\`"
        echo "# to execute the command in this file with the matching CMDID"
        echo "# following the '#>'."
        echo
    fi

    if [[ "$QUIET" -lt 2 ]]
    then
        echo
        echo "### The following entries were generated on (`date`), by $0 v$VERSION (with args \"$ORIGINAL_ARGS\")"
        echo
    fi

    if [[ "$QUIET" -lt 1 ]]
    then
        echo "# In this section, a \"clean git repo\" is a directory that contains a"
        echo "# git repository (a '.git/' child directory) which has no uncommitted"
        echo "# changes, no untracked files (excluding anything ignored by the repo),"
        echo "# no stashed changes, and no unpushed commits (a repo without any"
        echo "# remote repositories is considered to be unpushed)."
        echo
    fi

    find "$DIR" \
        -maxdepth "$MAX_DEPTH" \
        -type d \
        `# It's not a "hidden" directory` \
        -not -path '*/.*' \
        `# It's not under a node_modules directory` \
        -not -path '*/node_modules/*' -not -path '*/node_modules' \
        `# It has a .git directory` \
        -exec test -d '{}/.git' \; \
        `# It hasn't been modified in at least 90 days` \
        -mtime "+${MIN_DAYS_OLD}" \
        `# It has no uncomitted changes` \
        -not -exec sh -c "git -C {} status --porcelain=v2 | grep . >/dev/null" \; \
        `# It has no unpushed commits on any branches (includes the case where there are no remotes configured)` \
        -not -exec sh -c "git -C {} log --branches --not --remotes --format=oneline | grep . >/dev/null" \; \
        `# It has nothing stashed` \
        -not -exec sh -c "git -C {} stash list --quiet --format=oneline | grep . >/dev/null" \; \
        \
        `# Then do this:` \
        -exec sh -c "if [[ \"$QUIET\" -lt 2 ]]; then echo '# \"'\`basename {}\`'\": a clean git repo, '\`du -ch {} | tail -n 1 | cut -f 1\`', last modified '\`stat -f '%Sm' {}\`; fi" \; \
        -exec sh -c "if [[ \"$QUIET\" -lt 1 ]]; then echo '# To inspect, consider:'; fi" \; \
        -exec sh -c "if [[ \"$QUIET\" -lt 1 ]]; then echo \"#> \`head -c 8 /dev/urandom | xxd -ps\`     git -C {} status\"; fi" \; \
        -exec sh -c "if [[ \"$QUIET\" -lt 1 ]]; then echo \"#> \`head -c 8 /dev/urandom | xxd -ps\`     git -C {} stash list\"; fi" \; \
        -exec sh -c "if [[ \"$QUIET\" -lt 1 ]]; then echo \"#> \`head -c 8 /dev/urandom | xxd -ps\`     git -C {} log --branches --not --remotes\"; fi" \; \
        -exec sh -c "if [[ \"$QUIET\" -lt 1 ]]; then echo \"#> \`head -c 8 /dev/urandom | xxd -ps\`     git -C {} remote --verbose\"; fi" \; \
        -exec echo "${CLEAN_COMMAND} {}" \; \
        -exec sh -c "if [[ \"$QUIET\" -lt 2 ]]; then echo; fi" \;
done


