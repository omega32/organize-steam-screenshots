#!/bin/sh
#==============================================================================
# Script to organize uncompressed steam screenshots (PNG) into folders (a folder per game).
#
# If no folder is found for a game, a new folder is created with the format: "<safe name> [<id>]".
# But if a folder is found, the screenshots are just moved to the existing one.
# The format of the existing folders may be anything as long as the gameid is part of the name and is between square brackets ([gameid]).
#==============================================================================

declare -A stats=()

#---------------------------------------------------------------
# methods
#---------------------------------------------------------------
app_name_steamdb () {
    # useful if the app is no longer in Steam.
    local id=$1
    local result=$(curl -s "https://steamdb.info/app/$id/" | grep -oP "(?<=<td itemprop=[\"\']name[\"\']>)[^<]+")
    [ "$result" = "" ] && return 1 || echo "$result"
}

app_name_scraping () {
    # useful if the applist hasn't been updated (update-app-list.sh) and the app is not in the local storage.
    local id=$1
    local result=$(curl -s "https://store.steampowered.com/app/$id/" | grep -oP "(?<=<div class=[\"\']apphub_AppName[\"\']>)[^<]+")
    [ "$result" = "" ] && return 1 || echo "$result"
}

app_name_applist () {
    local id=$1
    local result=$(cat "$(dirname "$0")/applist.json" | jq -r ".applist.apps[] | select(.appid == $id) | .name")
    [ "$result" = "" ] && return 1 || echo "$result"
}

safe_name () {
    local name=$1
    local result=$(echo "$name" | sed 's/[\\/:*?"<>|]/_/g')          # remove invalid characters in file names.
    local result=$(echo "$result" | sed "s/&amp;/\&/g")              # &amp; -> & (html encoded). Useful when getting the name with HTML "scraping".
    local result=$(echo "$result" | sed -E "s/(^[ \t]*|[ \t]*$)//g") # remove trailing and leading spaces. Solution constructed with the help of [https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable]. NOTE: "xargs" solutions have problems when the name has single or double quotes.
    echo "$result"
}

increase_stat () {
    local game="$1"
    local count="${stats[$game]}"
    [[ -z "$count" ]] && count=0
    (( count++ ))
    stats+=(["$game"]=$count)
}

print_stats () {
    local count="${#stats[*]}"
    if [ "$count" -gt "0" ]; then
        printf '\nMoved files:\n'
        for key in "${!stats[@]}"; do
            printf '> %s: [%s]\n' "$key" "${stats[$key]}"
        done
    fi
}

move_file () {
    local f_path=$1
    local f_name=$(basename "$f_path")

    # This regex extracts the id (number at the beginning of the screenshot filename). Captures only the number.
    id=$(echo "$f_name" | grep -oP "^[\d]+")

    [ "$id" == "" ] && return # invalid screenshot filename

    # First, check if the folder already exists. If there are multiple folders, the first one is taken (first one returned by find).
    # NOTE (multiple IDs in one folder):
    # - The folder names can be manually customized. Any name is allowed, as long as the game ID is between square brackets.
    #   It's even possible to have multiple IDs in the same folder. For example: "safename [<id1>] + [<id2>] + [<idn>]".
    # - This is useful for non-steam apps (for which the ID may change); and can also be used to consolidate screenshots from multiple games under the same folder.
    ready=false
    if ! [ "$id" = "" ]; then
        # This regex finds folders that have the $id between square brackets (no matter the location). It captures the full folder name.
        folder=$(ls -d */ 2> /dev/null | grep -m1 -P ".*\[$id\].*")
        if ! [ "$folder" = "" ]; then
            mv "$f_path" "$folder$f_name"
            increase_stat "$(basename "$folder")"
            ready=true
        fi
    fi

    # If the folder doesn't exist, get the name of the game and create it.
    # NOTE (non-steam apps): if no name can be retrieved, it may be a non-steam app; and there is the possibility that it's a new ID for an old app. This will happen if the non-steam app is removed from the library and added again.
    # In that case, there may already exist a folder for the same app but with the old ID. TODO?: detect non-steam apps (ID > certain threshold) and do not create new folders?.
    if [ "$ready" = "false" ]; then
        game=$(app_name_applist "$id" || app_name_scraping "$id" || app_name_steamdb "$id")
        if ! [ "$game" = "" ]; then
            safename=$(safe_name "$game")
            newfolder="$safename [$id]"
        else
            newfolder="[$id]"
        fi
        echo folder created: "$newfolder"
        mkdir "$newfolder"; mv "$f_path" "$_"
        increase_stat "$newfolder"
    fi
}

#---------------------------------------------------------------
# script
#---------------------------------------------------------------
cd ..
if [ "$1" = "" ]; then
    # full path to avoid using the Windows built-in "find".
    C:/cygwin/bin/find ./ -maxdepth 1 -type f -name "*.png" | while read -r file; do move_file "$file"; done
else
    for file in "$@"; do move_file "$file"; done
fi

print_stats

exit 0
