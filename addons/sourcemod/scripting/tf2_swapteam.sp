/************************************************************************
*************************************************************************
TF2 Swap My Team

Description: A very simple swapteam script for TF2.
    Main functionality is to simply allow donators to swap teams.
	Also gives a bit more flexibility/control over how the plugin works.
	Server admins can set a cool down time on how often the functionality 
    is used (to prevent swap abuse).
    
Original Author: 
    Afronanny
    
Current Author: 
    Mr.Silence

*************************************************************************
*************************************************************************
This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************/
#pragma semicolon 1

// Includes
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

// Defines
#define VERSION "1.4.0"
#define TEAM_RED 2
#define TEAM_BLUE 3
#define TEAM_SPEC 1
#define SMTP_PREFIX "\x01\x04[SM]\x01"

// Create our new cvar handles for use later.
ConVar cvar_SwapMyTeamDFlag = null;        // Donator flag that allows people to use the command
ConVar cvar_SwapMyTeamCMD = null;          // Command used to swap teams
ConVar cvar_SwapMyTeamCoolDown = null;     // Cool Down cvar
ConVar cvar_SMTVersion = null;             // Version display cvar

// Create our timer handel for each player.
Handle g_SMTTimerHandle[MAXPLAYERS+1];

// Get a global variable to determine whether cooldown for the player is in effect.
bool g_bCanSwap[MAXPLAYERS+1];
bool g_bSuddenDeathRound;
bool g_bSMTCommandCreated;

float g_fCoolDownTime[MAXPLAYERS+1];

// Global string for swap commands
char g_sSMTCommands[3][65];

// Plugin info/credits.
public Plugin myinfo = 
{
    name = "Swap My Team",
    author = "Mr.Silence",
    description = "Allow donors to swap teams.",
    version = VERSION,
    url = "https://github.com/Silenci0/TF2Swapteam"
}

// Initialization method, the place where we fill out cvar details and other things.
public void OnPluginStart()
{
    // Create our variables for use in the plugin.
    cvar_SwapMyTeamDFlag        = CreateConVar("sm_swapmyteam_flag", "s", "Flag necessary for admins/donators to use this functionality (use only one flag!).", 
                                                FCVAR_NOTIFY|FCVAR_REPLICATED);
    cvar_SwapMyTeamCMD          = CreateConVar("sm_swapmyteam_cmd", "swapmyteam", "Command used on the server for donators/admins to swap teams.", 
                                                FCVAR_NOTIFY|FCVAR_REPLICATED);
    cvar_SwapMyTeamCoolDown     = CreateConVar("sm_swapmyteam_cooldown", "300.0", "Cool down time (in seconds) before the swapteam command can be used.",
                                                FCVAR_NOTIFY|FCVAR_REPLICATED, true, 0.0, false);
    cvar_SMTVersion	            = CreateConVar("sm_swapmyteam_version", VERSION, "Swap My Team Version.", 
                                                FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    // Create a config file for the plugin
    AutoExecConfig(true, "plugin.tf2_swapteam");	

    // Hook events for sudden death. Don't want them using this during sudden death
    HookEvent("teamplay_round_stalemate", Event_SuddenDeathStart);
    HookEvent("teamplay_round_start", Event_SuddenDeathEnd);
    HookEvent("teamplay_round_win", Event_SuddenDeathEnd);
}

public Action Command_SwapMyTeam(int client, any args)
{
    if (!IsFakeClient(client))
    {
        // Check if they have access to the command first
        if (!IsDonator(client))
        {
            ReplyToCommand(client, "%s Only donators can use this command.", SMTP_PREFIX);
            return Plugin_Continue;
        }

        // Check to see if Sudden Death is active.
        if(g_bSuddenDeathRound)
        {
            ReplyToCommand(client, "%s Swap My Team is not active during Sudden Death.", SMTP_PREFIX);
            return Plugin_Continue;
        }

        // Gets the client's current team then determines which to switch too.
        int team = GetClientTeam(client);

        // Check if they are in spectate 
        if(team <= TEAM_SPEC)
        {
            ReplyToCommand(client, "%s Join a team first.", SMTP_PREFIX);
            return Plugin_Continue;
        }

        // If the cooldown has been reached, switch the team
        if(g_bCanSwap[client] && !g_bSuddenDeathRound)
        {
            // Determine which team the player gets swaped to. If in spec, tell them to join a team.
            switch (team)
            {
                case 2: 
                {
                    ChangeClientTeam(client, TEAM_BLUE);
                }
                case 3: 
                {
                    ChangeClientTeam(client, TEAM_RED);
                }
                default: 
                {
                    ReplyToCommand(client, "%s Unknown Team.", SMTP_PREFIX);
                }
            }

            // Set the flag so that it registers the cooldown effect.
            g_bCanSwap[client] = false;
            g_fCoolDownTime[client] = GetConVarFloat(cvar_SwapMyTeamCoolDown);
            
            // Create a timer that will count down and change the flag after the cool down period.
            g_SMTTimerHandle[client] = CreateTimer(1.0, Timer_SwapCoolDown, client, TIMER_REPEAT);

            return Plugin_Continue;
        }

        // If we find out that the cooldown hasn't been reached, tell them they can't use it again for a specific amount of time.
        else
        {
            int iCooldown = RoundToNearest(g_fCoolDownTime[client]);
            ReplyToCommand(client, "%s You must wait %i seconds to use this command again.", SMTP_PREFIX, iCooldown);
        }

        return Plugin_Continue;
    }

    return Plugin_Continue;
}

// Command cool down timer
public Action Timer_SwapCoolDown(Handle timer, int client)
{
    // Decrement the time value
    g_fCoolDownTime[client]--;

    // If the time reaches 0 and our flag is still false.
    if(g_fCoolDownTime[client] <= 0.0 && !g_bCanSwap[client])
    {
        // Reset the current time global and give them back the command.
        g_fCoolDownTime[client] = 0.0;
        g_bCanSwap[client] = true;
        ClearTimer(g_SMTTimerHandle[client]);
        PrintToChat(client, "Swaptimer has ended! HUZZAH!");
    }
}

// Get the proper info upon our configs being executed.
public void OnConfigsExecuted()
{
    // Set our plugins version to display
    SetConVarString(cvar_SMTVersion, VERSION);

    // Make sure our timer handles are invalid. Wouldn't want garbage in them.
    for(int i = 1; i <= MaxClients; i++)
    {
        g_SMTTimerHandle[i] = INVALID_HANDLE;
    }

    // Create our swap commands
    CreateSwapCommand();
}

public void OnMapStart()
{
    // Ensure that the value of CanSwap is, for each client, set to true initially.
    for(int i = 1; i <= MaxClients; i++)
    {
        g_bCanSwap[i] = true;
        g_fCoolDownTime[i] = 0.0;
    }

    // Its not sudden death just yet
    g_bSuddenDeathRound = false;
}

public void OnMapEnd()
{
    // Clear any timers we may have
    for(int i = 1; i <= MaxClients; i++)
    {
        if(g_SMTTimerHandle[i]!= INVALID_HANDLE)
        {
            ClearTimer(g_SMTTimerHandle[i]);
        }
    }
}

// Kill our client's timer on disconnect
public void OnClientDisconnect(int client)
{
    if(g_SMTTimerHandle[client]!= INVALID_HANDLE)
    {
        ClearTimer(g_SMTTimerHandle[client]);
        g_bCanSwap[client] = true;
        g_fCoolDownTime[client] = 0.0;
    }
}

public Action Event_SuddenDeathStart(Handle event, const char[] name, bool dontBroadcast)
{
    if(!g_bSuddenDeathRound)
    {
        // Set this to true, we don't want them swapping teams during the round
        g_bSuddenDeathRound = true;
    }
}

public Action Event_SuddenDeathEnd(Handle event, const char[] name, bool dontBroadcast)
{
    if(g_bSuddenDeathRound)
    {
        // Turn it off so swapping can resume!
        g_bSuddenDeathRound = false;
    }
}

// Kill/clear our client's timer handles. Wouldn't want them eating up precious memory.
stock void ClearTimer(Handle &timer)
{
    if (timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }
}

// Create the commands our plugin uses in game
stock void CreateSwapCommand()
{
    if (!g_bSMTCommandCreated)
    {
        char sSMTCommand[256];		

        GetConVarString(cvar_SwapMyTeamCMD, sSMTCommand, sizeof(sSMTCommand));

        // Pull the commmands from the string used in our 
        ExplodeString(sSMTCommand, ",", g_sSMTCommands, 3, sizeof(g_sSMTCommands[]));

        // Set all of our commands up for use
        for (int i; i < 3; i++)
        {
            if (strlen(g_sSMTCommands[i]) > 2)
            {
                g_bSMTCommandCreated = true;
                RegConsoleCmd(g_sSMTCommands[i], Command_SwapMyTeam);
            }
        }
    }
}

// Method used to check if a player has access to the commands
stock bool IsDonator(int client)
{
    // Get our admin flags
    char userFlags[32];
    GetConVarString(cvar_SwapMyTeamDFlag, userFlags, sizeof(userFlags));

    // Checks to see if the person has root access 
    int clientFlags = GetUserFlagBits(client);	
    if (clientFlags & ADMFLAG_ROOT)
    {
        return true;
    }

    // Checks to see if the user has the appropriate flags
    int iFlags = ReadFlagString(userFlags);
    if (clientFlags & iFlags)
    {
        return true;	
    }

    // If no flags, they don't have access
    return false;
}