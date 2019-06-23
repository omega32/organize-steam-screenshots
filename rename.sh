#!/bin/sh
#==============================================================================
# Script to rename existing folders that only have the game id, to include the name as well: "<id>" gets renamed to "<safename> [<id>]".
#
# Example:
# 440 -> Team Fortress 2 [440]
# NOTE: the folder name, in its entirety, has to match the game id. Ex: "440" will match, but "[440]" or "TF2 [440]" won't because the extra characters/text.
#
# STEAM API:
# - GetAppList (Steamworks Web):
#   > https://api.steampowered.com/ISteamApps/GetAppList/v2/  <- list of all the apps, with their ids and respective names.
# - GetSchemaForGame (Steam Web):
#   > http://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?key=XXXXXXXXXXXXXXXXX&appid=XXXXX <- includes the game name, but other stuff as well (stats, achievements).
#
# STEAM PAGE (WEB SCRAPING):
# - https://store.steampowered.com/app/<ID>/ <- search the tag with the class "apphub_AppName".
#
# RESOURCES:
# - https://partner.steamgames.com/doc/webapi/ISteamApps   <- Steamworks API Documentation
# - https://developer.valvesoftware.com/wiki/Steam_Web_API <- Steam Web API
#
# TODO:
# [+] Warning if the "applist" should be updated: 1) it's too old, or 2) apps were not found and falling back to "scraping" was necessary.
# [+] At the end, list all the folders / apps for which no name was found.
# [+] Option to always rename as long as a folder includes the game ID in its name (and the resulting name would be different to the current one).
#==============================================================================

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
    local result=$(cat ./Scripts/applist.json | jq -r ".applist.apps[] | select(.appid == $id) | .name")
    [ "$result" = "" ] && return 1 || echo "$result"
}

safe_name () {
    local name=$1
    local result=$(echo "$name" | sed 's/[\\/:*?"<>|]/_/g') # remove invalid characters in file names.
    local result=$(echo "$result" | sed "s/&amp;/\&/g")     # &amp; -> & (html encoded). Useful when getting the name with HTML "scraping".
    local result=$(echo "$result" | xargs)                  # remove trailing and leading spaces [https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable].
    echo "$result"
}

#---------------------------------------------------------------
# script
#---------------------------------------------------------------
cd ..
# This regex finds folders whose names end with a number. Captures only the number.
ls -d */ | grep -oP "\d+(?=/$)" | while read -r folder; do
    id="$folder"
    # NOTE: for some apps, the name obtained through the "applist" doesn't match the one obtained by "scraping" the HTML (so, the order in which this methods are called does affect the end result).
    name=$(app_name_applist "$id" || app_name_scraping "$id" || app_name_steamdb "$id")
    if ! [ "$name" = "" ]; then
        safename=$(safe_name "$name")
        newname="$safename [$id]"
        echo "$newname"
        mv "$folder" "$newname"
    fi
done

exit 0
