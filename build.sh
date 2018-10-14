#!/bin/bash

DOCKER=${DOCKER:-docker}
declare -x DOCKER

# Usage: extract_from_image("my-image", "vol0", ["vol1" ...], "image-src-path" "image-dest-path")
#
# Runs a container for the purpose of copying data into or out of specific volumes.
# The volumes are mounted consecutively inside the container as /vol0, /vol1, ...
#
# Example: to copy pgpass from wrms-dash-config-vol into ./secrets/, do
#       extract_from_image(alpine, wrms-dash-config-vol, $PWD/secrets, /vol0/pgpass, /vol1/)
#  - The image used will be "alpine"
#  - wrms-dash-config-vol will be mounted as /vol0/ inside the container
#  - $PWD/secrets will be /vol1/
#  - The function will then copy /vol0/pgpass to /vol1/
function extract_from_image(){
    declare image=$1
    shift

    declare -a argv=("$@")
    declare argc=${#argv[@]}

    declare dest_path=${argv[$(($argc-1))]}
    unset argv[$(($argc-1))]

    declare src_path=${argv[$(($argc-2))]}
    unset argv[$(($argc-2))]

    argc=${#argv[@]}

    if [ $argc -gt 3 ]; then
        return $(error "Too many volumes")
    fi

    for i in $(seq 0 $(($argc-1))); do
        argv[$i]="-v ${argv[$i]}:/vol$i/"
    done

    $DOCKER run -it --rm ${argv[0]} ${argv[1]} ${argv[2]} $image cp -R $src_path $dest_path && \
    $DOCKER run -it --rm ${argv[0]} ${argv[1]} ${argv[2]} $image chown -R $(id -u):$(id -g) $dest_path
}

case $1 in
    build)
        $DOCKER build -t $2 .
        ;;
    error)
        echo "ERROR: $2" >&2
        false
        ;;
    cp)
        shift
        extract_from_image $@
        ;;
    image)
        case $2 in
            exists)
                $DOCKER images | grep -q -E "$3\\s"
                ;;
            pull-if-not-exists)
                $DOCKER images | grep -q -E "$3\\s" || $DOCKER pull $3
                ;;
            delete)
                $DOCKER rmi $3 $($DOCKER images --filter dangling=true -q)
                ;;
        esac
        ;;
    network)
        case $2 in
            exists)
                $DOCKER network list | grep -q -E "$3\\s"
                ;;
            create)
                $DOCKER network list | grep -q -E "$3\\s" || $DOCKER network create $3
                ;;
        esac
        ;;
    volume)
        case $2 in
            exists)
                $DOCKER volume list | grep -q -E "($3\\s|$3$)"
                ;;
            create)
                $DOCKER volume list | grep -q -E "($3\\s|$3$)" || $DOCKER volume create $3
                ;;
            delete)
                $DOCKER volume rm $3
                ;;
        esac
        ;;
esac


