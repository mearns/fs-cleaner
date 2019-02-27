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
    echo "Usage: `basename $0` < CLEANUP_FILE"
    echo "   or: `basename $0` -x CMD-ID [CMD-ID [...]] < CLEANUP_FILE"
}

function help () {
    echo
    echo "In the first usage, execute the clean up script as it describes."
    echo "In the second usage, execute specified shell commands from the "
    echo "cleanup script."
    echo
    echo "Options:"
    echo "  -x              Execute the shell commands from the CLEANUP_FILE"
    echo "                  identified by the given CMD-IDs."
    echo 
}

DO_EXEC=0
QUIET=0

args=`getopt xqhu $*`
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
       -x) DO_EXEC=1; shift ;;

       -q) let "QUIET = $QUIET + 1" ; shift ;;

       -u)
        shift
        usage
        echo
        exit 0
        ;;

       -h)
        shift
        echo "execute-cleanup v${VERSION} - ${DATE}"
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

if [[ "$DO_EXEC" -ne "1" ]]
then
    grep -v '[[:space:]]*#' | grep -v '^[[:space:]]*$' | while read -r line
    do
        COMMAND=$( echo "$line" | cut -d ' ' -f 1 )
        TARGET=$( echo "$line" | cut -d ' ' -f 2- )
        case "$COMMAND"
        in
            clean)
                [[ "$QUIET" -lt 1 ]] && echo "Deleting $TARGET..."
                rm -rf $TARGET
                ;;

            recommend-clean)
                [[ "$QUIET" -lt 1 ]] && echo "WARNING: Looks like you didn't make a decision on $TARGET (command is ${COMMAND})."
                ;;

            *)
                echo "ERROR: Unknown command $COMMAND for $TARGET" >&2
                exit 1
                ;;
        esac
    done 
else
    if [[ $# -lt 1 ]]
    then
        echo "ERROR: No command IDs specified for -x." >&2
        usage >&2
        exit 2
    fi

    grep '^[[:space:]]*#> ' | while read -r line
    do
        FIELDS=$( echo "$line" | sed -e 's/^[[:space:]]*#> \([^[:space:]]\{1,\}\)[[:space:]]*\(.*\)/\1 \2/' )
        CMDID=$( echo "$FIELDS" | cut -d ' ' -f 1 )
        for c in $*
        do
            if [[ "$CMDID" == "$c" ]]
            then
                CMD=$( echo "$FIELDS" | cut -d ' ' -f 2- )
                [[ "$QUIET" -lt 2 ]] && echo "#>${CMDID}    $CMD"
                sh -c "$CMD"
                [[ "$QUIET" -lt 1 ]] && echo "#? $?"
                echo
            fi
        done
    done
fi

