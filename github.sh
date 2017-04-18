#!/bin/bash
# version 1.0.0


function usage() {
    echo "USAGE: "
    echo "$CMD init"
    echo "$CMD push|pull repo_name"
    echo ""
    echo "$CMD init: Create git.private.pem and git.public.pem under $KEYDIR. Then create leaf directory under this direcotry and git-clone root from Github."
    echo "NOTE: A Github repo called root should be created on github.com beforehand."
    echo ""
    echo "$CMD push repo_name: Make directory repo_name under leaf/ to an compressed archived file into root/ with the same name."
    echo "Then add this archived file to git and push it to remote."
    echo ""
    echo "$CMD pull repo_name: Pull the update files from github to root. Decompress file repo_name under root/ to leaf/."
}


function info() {
    echo "[INFO]$@"
}


function error() {
    echo "[ERROR]$@"
}


function init() {
    cd "$BASE"

    if [ ! -d "$LEAF_DIR" ];
    then
        mkdir "$LEAF_DIR"
    fi

    if [ ! -d "$KEYDIR" ];
    then
        mkdir "$KEYDIR"
    fi

    if [ -e "$GITPRIVATE" ] || [ -e "$GITPUBLIC" ];
    then
        error "Pem files exits with the same name. Exit."
        exit 1
    fi
    info "Create pem files $GITPRIVATE and $GITPUBLIC under $KEYDIR"
    openssl req -x509 -nodes -days 100000 -newkey rsa:2048 -keyout "$GITPRIVATE" -out "$GITPUBLIC" -subj '/'
    info "Pem files created. Please clone 'root' from your Github under $BASE."
}


function push() {
    cd "$BASE"

    info "Push $LEAFREPO to Github"
    if [ ! -d "$LEAFREPO" ];
    then
        error "$LEAFREPO does NOT exist."
        exit 1
    fi

    info "Remove $REPO under $ROOT_DIR/"
    rm -f "$ROOTREPO"
    info "Encrypt $REPO from $LEAF_DIR to $ROOT_DIR"
    tar czf "$LEAFTMP" "$LEAFREPO"
    openssl smime -encrypt -aes256 -binary -outform DEM -in "$LEAFTMP" -out "$ROOTREPO" "$GITPUBLIC"
    rm -f "$LEAFTMP"

    cd "$ROOT_DIR"
    info "Add to Github"
    git add "$REPO"
    git commit -m"Push $REPO"
    git push -u origin master
    info "Finish push $REPO"
}


function pull() {
    cd "$BASE"

    cd "$ROOT_DIR"
    info "Pull from Github"
    git pull --rebase
    if [ ! -e "$REPO" ];
    then
        error "$REPO does NOT exist."
        exit 1
    fi

    cd "$BASE"
    info "Decrypting $ROOTREPO to $REPO"
    info "$LEAFTMP"
    openssl smime -decrypt -binary -inform DEM -inkey "$GITPRIVATE" -in "$ROOTREPO" -out "$LEAFTMP"
    rm -rf "$LEAFREPO"
    tar xzf "$LEAFTMP"
    rm -r "$LEAFTMP"
    info "Finish pull $REPO"
}


BASE="$(pwd)"
info "BASE=$BASE"
CMD="$(basename $0)"
KEYDIR=".keys"
ACTION="$1"
ROOT_DIR="root"
LEAF_DIR="leaf"
REPO="$2"
TMP="$REPO.ttl1"


LEAFREPO="$LEAF_DIR/$REPO"
ROOTREPO="$ROOT_DIR/$REPO"
LEAFTMP="$LEAF_DIR/$TMP"


GITPRIVATE="$KEYDIR/git.private.pem"
GITPUBLIC="$KEYDIR/git.public.pem"


if ( [ "$ACTION" == "push" ] || [ "$ACTION" == "pull" ] ) && [ -z "$REPO" ];
then
    error "Need a repository name."
    exit 1
fi


case $ACTION in
    "init") init ;;
    "push") push "$REPO" ;;
    "pull") pull "$REPO" ;;
         *) usage ;;
esac
