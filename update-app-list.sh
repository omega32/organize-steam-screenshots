#!/bin/sh
#==============================================================================
# STEAM API:
# - GetAppList (Steamworks Web):
#   > https://api.steampowered.com/ISteamApps/GetAppList/v2/ <- list of all the apps, with their ids and respective names.
#
# RESOURCES:
# - https://partner.steamgames.com/doc/webapi/ISteamApps <- Steamworks API Documentation
#==============================================================================

curl https://api.steampowered.com/ISteamApps/GetAppList/v2/ > "$(dirname "$0")/applist.json"

exit 0
