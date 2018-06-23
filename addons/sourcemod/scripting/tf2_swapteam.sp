/************************************************************************
Plugin: Swap My Team
Description: Main functionality is to simply allow donators to swap teams.
	Also gives a bit more flexibility/control over how the plugin works.
	Users of this plugin can set a cool down time on how often
	the functionality is used (to prevent swap abuse).
Original Author: Afronanny
Current Author: Mr.Silence
*************************************************************************/
// Make sure it reads semicolons as endlines.
#pragma semicolon 1

// Includes
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

// Get some defines up in this piece!
// But seriously, define some common, easier to deal with stuff.
#define VERSION "1.3"
#define TEAM_RED 2
#define TEAM_BLUE 3
#define TEAM_SPEC 1
#define SMTP_PREFIX "\x01\x04[SM]\x01"

// Create our new cvar handles for use later.
new Handle:cvar_SwapMyTeamDFlag     	= INVALID_HANDLE;	// Donator flag that allows people to use the command
new Handle:cvar_SwapMyTeamCMD			= INVALID_HANDLE;	// Command used to swap teams
new	Handle:cvar_SwapMyTeamCoolDown 		= INVALID_HANDLE;	// Cool Down cvar
new	Handle:cvar_SMTVersion 				= INVALID_HANDLE;	// Version display cvar

// Create our timer handel for each player.
new Handle:g_SMTTimerHandle[MAXPLAYERS+1];

// Get a global variable to determine whether cooldown for the player is in effect.
new bool:g_bCanSwap[MAXPLAYERS+1];
new bool:g_bSuddenDeathRound;
new bool:g_bSMTCommandCreated;

// Global string for swap commands
new String:g_sSMTCommands[3][65];

// Plugin info/credits.
public Plugin:myinfo = 
{
	name = "Swap My Team",
	author = "Mr.Silence",
	description = "Allow donors to swap teams.",
	version = VERSION,
	url = "https://wiki.alliedmods.net"
}

// Initialization method, the place where we fill out cvar details and other things.
public OnPluginStart()
{
	// Create our variables for use in the plugin.
	cvar_SwapMyTeamDFlag     	= CreateConVar("sm_swapmyteam_flag", "s", "Flag necessary for admins/donators to use this functionality (use only one flag!).", FCVAR_NOTIFY|FCVAR_REPLICATED);
	cvar_SwapMyTeamCMD			= CreateConVar("sm_swapmyteam_cmd", "swapmyteam", "Command used on the server for donators/admins to swap teams.", FCVAR_NOTIFY|FCVAR_REPLICATED);
	cvar_SwapMyTeamCoolDown		= CreateConVar("sm_swapmyteam_cooldown", "300.0", "Cool down time (in seconds) before the swapteam command can be used. Anything below 30 seconds is disregarded.", FCVAR_NOTIFY|FCVAR_REPLICATED, true, 0.0, false);
	cvar_SMTVersion				= CreateConVar("sm_swapmyteam_version", VERSION, "Swap My Team Version.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Create a config file for the plugin
	AutoExecConfig(true, "plugin.tf2_swapteam");	
	
	// Hook events for sudden death. Don't want them using this during sudden death
	HookEvent("teamplay_round_stalemate", Event_SuddenDeathStart);
	HookEvent("teamplay_round_start", Event_SuddenDeathEnd);
	HookEvent("teamplay_round_win", Event_SuddenDeathEnd);
}

public Action:Command_SwapMyTeam(client, args)
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
		
		// Check to see if the round had ended
		if(g_bSuddenDeathRound)
		{
			ReplyToCommand(client, "%s Swap My Team is not active during Sudden Death.", SMTP_PREFIX);
			return Plugin_Continue;
		}
		
		// Gets the client's current team then determines which to switch too.
		new team = GetClientTeam(client);
		
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
				case 2: ChangeClientTeam(client, TEAM_BLUE);
				case 3: ChangeClientTeam(client, TEAM_RED);
				default: ReplyToCommand(client, "%s Unknown Team.", SMTP_PREFIX);
			}
			
			// Set the flag so that it registers the cooldown effect.
			g_bCanSwap[client] = false;
				
			// Create a timer that will count down and change the flag after the cool down period.
			g_SMTTimerHandle[client] = CreateTimer(GetConVarFloat(cvar_SwapMyTeamCoolDown), Timer_SwapCoolDown, client, TIMER_REPEAT);
			
			return Plugin_Continue;
		}
		
		// If we find out that the cooldown hasn't been reached, tell them they can't use it again for a specific amount of time.
		else
		{
			// Calculate the cooldown time to be displayed to users
			new Float:fTime = GetConVarFloat(cvar_SwapMyTeamCoolDown);
			new iCooldown = RoundToNearest(fTime/60.0);
			
			// If we have 60 seconds or less on the clock, make the displayed time 1 minute
			if(fTime <= 60)
			{
				iCooldown = 1;
			}
			
			ReplyToCommand(client, "%s You must wait %i minutes to use this command again.", SMTP_PREFIX, iCooldown);
		}
		
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

// Command cool down timer
public Action:Timer_SwapCoolDown(Handle:timer, any:client)
{
	// Set up the cooldown timer
	new Float:fCoolDown = GetConVarFloat(cvar_SwapMyTeamCoolDown);
	
	// Set the variable to the current time
	new Float:fCurrentTime = GetTickedTime();

	// If the time reaches 0 and our flag is still false.
	if(fCurrentTime >= fCoolDown && !g_bCanSwap[client])
	{
		// Reset the current time global and give them back the command.
		fCurrentTime = 0.0;
		g_bCanSwap[client] = true;
		ClearTimer(g_SMTTimerHandle[client]);
		PrintToChat(client, "Swaptimer has ended! HUZZAH!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

// Get the proper info upon our configs being executed.
public OnConfigsExecuted()
{
	// Set our plugins version to display
	SetConVarString(cvar_SMTVersion, VERSION);
	
	// Make sure our timer handles are invalid. Wouldn't want garbage in them.
	for(new i = 1; i <= MaxClients; i++)
	{
		g_SMTTimerHandle[i] = INVALID_HANDLE;
	}
	
	// Create our swap commands
	CreateSwapCommand();
}

public OnMapStart()
{
	// Ensure that the value of CanSwap is, for each client, set to true initially.
	for(new i = 1; i <= MaxClients; i++)
	{
		g_bCanSwap[i] = true;
	}
	
	// Its not sudden death just yet
	g_bSuddenDeathRound = false;
}

public OnMapEnd()
{
	// Clear any timers we may have
	for(new i = 1; i <= MaxClients; i++)
	{
		if(g_SMTTimerHandle[i]!= INVALID_HANDLE)
		{
			ClearTimer(g_SMTTimerHandle[i]);
		}
	}
}

// Kill our client's timer on disconnect
public OnClientDisconnect(client)
{
	if(g_SMTTimerHandle[client]!= INVALID_HANDLE)
	{
		ClearTimer(g_SMTTimerHandle[client]);
		g_bCanSwap[client] = true;
	}
}

public Action:Event_SuddenDeathStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bSuddenDeathRound)
	{
		// Set this to true, we don't want them swapping teams during the round
		g_bSuddenDeathRound = true;
	}
}

public Action:Event_SuddenDeathEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bSuddenDeathRound)
	{
		// Turn it off so swapping can resume!
		g_bSuddenDeathRound = false;
	}
}

// Kill/clear our client's timer handles. Wouldn't want them eating up precious memory.
stock ClearTimer(&Handle:timer)
{
	if (timer != INVALID_HANDLE)
	{
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}     
}

// Create the commands our plugin uses in game
stock CreateSwapCommand()
{
	if (!g_bSMTCommandCreated)
	{
		decl String:sSMTCommand[256];		
		
		GetConVarString(cvar_SwapMyTeamCMD, sSMTCommand, sizeof(sSMTCommand));
		
		// Pull the commmands from the string used in our 
		ExplodeString(sSMTCommand, ",", g_sSMTCommands, 3, sizeof(g_sSMTCommands[]));
		
		// Set all of our commands up for use
		for (new i; i < 3; i++)
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
stock bool:IsDonator(client)
{
	// Get our admin flags
	new String:userFlags[32];
	GetConVarString(cvar_SwapMyTeamDFlag, userFlags, sizeof(userFlags));
	
	// Checks to see if the person has root access 
	new clientFlags = GetUserFlagBits(client);	
	if (clientFlags & ADMFLAG_ROOT)
	{
		return true;
	}
	
	// Checks to see if the user has the appropriate flags
	new iFlags = ReadFlagString(userFlags);
	if (clientFlags & iFlags)
	{
		return true;	
	}
	
	// If no flags, they don't have access
	return false;
}