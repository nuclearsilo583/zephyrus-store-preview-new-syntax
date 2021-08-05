#pragma semicolon 1

#define PLUGIN_NAME "Thirdperson Mode"
#define PLUGIN_AUTHOR "Zephyrus"
#define PLUGIN_DESCRIPTION "Thirdperson mode"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_URL ""

#include <sourcemod>
#include <sdktools>
#include <zephstocks>

new bool:g_bThirdperson[MAXPLAYERS+1] = {false,...};

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public OnPluginStart()
{
	IdentifyGame();
	HookEvent("player_spawn", Event_PlayerSpawn);
	RegConsoleCmd("sm_tp", Command_TP);
	RegConsoleCmd("sm_fp", Command_FP);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsPlayerInTP", Native_IsPlayerInTP);
	CreateNative("TogglePlayerTP", Native_TogglePlayerTP);

	return APLRes_Success;
}

public Native_IsPlayerInTP(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return g_bThirdperson[client];
}

public Native_TogglePlayerTP(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	g_bThirdperson[client] = !g_bThirdperson[client];
	ToggleThirdperson(client);
}

public OnClientConnected(client)
{
	g_bThirdperson[client] = false;
}

public Action:Command_TP(client, args)
{
	g_bThirdperson[client] = !g_bThirdperson[client];
	ToggleThirdperson(client);
	return Plugin_Handled;
}

public Action:Command_FP(client, args)
{
	g_bThirdperson[client] = false;
	SetThirdperson(client, false);
	return Plugin_Handled;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	if(g_bThirdperson[client])
		SetThirdperson(client, true);

	return Plugin_Handled;
}

stock ToggleThirdperson(client)
{
	if(g_bThirdperson[client])
		SetThirdperson(client, true);
	else
		SetThirdperson(client, false);
}

stock SetThirdperson(client, bool:tp)
{
	if(g_bCSGO)
	{
		static Handle:m_hAllowTP = INVALID_HANDLE;
		if(m_hAllowTP == INVALID_HANDLE)
			m_hAllowTP = FindConVar("sv_allow_thirdperson");

		SetConVarInt(m_hAllowTP, 1);

		if(tp)
			ClientCommand(client, "thirdperson");
		else
			ClientCommand(client, "firstperson");
	}
	else if(g_bTF)
	{
		if(tp)
			SetVariantInt(1);
		else
			SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}
}