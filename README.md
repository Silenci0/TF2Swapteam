# TF2Swapteam
TF2 swapteam plugin that I made many years ago which inspired the ZPS Swapteam plugin.

This simple plugin allows players to swap teams if they are donators/admins with a cooldown timer. This is only for use in TF2.

# Changelog
1.4.0 Update (12-04-2019)
-----------------
- Updated plugin code to use the new syntax.
- Reworked the timer and cooldown for the plugin.
    * The timer now runs repeatedly every second rather than using the time specified via the cvar for the timer itself.
    * The countdown time warning when players attempt to swap teams after using the swapteam command now shows how long until they can swap again, in seconds.
- Updated the configuration file with adjusted/corrected values.
- Compiled plugins for SM 1.10


1.3 Update (09-30-2019)
-----------------
- No code changes, but I did add a description/license, cleaned up some comments, and recompiled the plugin for Sourcemod 1.9
- Releasing this to public (I forgot to do this a year ago... silly me...)
- Fun fact: The ZPS Swap Team plugin I have on Github was based on this plugin. Not really important, but I figured I'd mention it.


1.3 Initial Commit (06-22-2018)
-----------------
- Added all the files/configuration items for the plugin. The plugin was made in 2012 back when I was running my own servers for TF2.