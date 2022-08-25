#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new Float:g_flGodmodes[STORE_MAX_ITEMS];
new g_iGodmodes = 0;
new g_iGodmodeRoundLimit[MAXPLAYERS+1] = {0,...};

new g_cvarGodmodeRoundLimit = -1;
new g_cvarGodmodeTeam = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Godmode_OnPluginStart()
#endif
{
	Store_RegisterHandler("godmode", "", Godmode_OnMapStart, Godmode_Reset, Godmode_Config, Godmode_Equip, Godmode_Remove, false);

	g_cvarGodmodeRoundLimit = RegisterConVar("sm_store_godmode_round_limit", "1", "Number of times you can buy godmode in a round", TYPE_INT);
	g_cvarGodmodeTeam = RegisterConVar("sm_store_godmode_team", "0", "Team that can use godmode. 0=Any 2=Terrorist 3=Counter-Terrorist", TYPE_INT);
}

#if defined STANDALONE_BUILD
public Action:Godmode_OnPlayerSpwan(Handle:event, const String:name[], bool:dontBroadcast)
#else
public Godmode_OnPlayerSpawn(client)
#endif
{
#if defined STANDALONE_BUILD
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsClientInGame(client))
		return Plugin_Continue;
#endif

	g_iGodmodeRoundLimit[client] = 0;

#if defined STANDALONE_BUILD
	return Plugin_Continue;
#endif
}

public Godmode_OnMapStart()
{
}

public Godmode_Reset()
{
	g_iGodmodes = 0;
}

public Godmode_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iGodmodes);
	
	g_flGodmodes[g_iGodmodes] = KvGetFloat(kv, "duration");

	++g_iGodmodes;
	return true;
}

public Godmode_Equip(client, id)
{
	if(g_iGodmodeRoundLimit[client] == g_eCvars[g_cvarGodmodeRoundLimit][aCache])
	{
		Chat(client, "%t", "Godmode Round Limit");
		return 1;
	}

	if(g_eCvars[g_cvarGodmodeTeam][aCache] != 0 && g_eCvars[g_cvarGodmodeTeam][aCache]!=GetClientTeam(client))
	{
		Chat(client, "%t", "Godmode Wrong Team");
		return 1;
	}

	new m_iData = Store_GetDataIndex(id);

	SDKHook(client, SDKHook_OnTakeDamage, Godmode_OnTakeDamage);
	CreateTimer(g_flGodmodes[m_iData], Godmode_WearOff, GetClientUserId(client));

	++g_iGodmodeRoundLimit[client];
	return 0;
}

public Godmode_Remove(client)
{
	return 0;
}

public Action:Godmode_WearOff(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	SDKUnhook(client, SDKHook_OnTakeDamage, Godmode_OnTakeDamage);
	return Plugin_Stop;
}

public Action:Godmode_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	damage =  0.0;
	return Plugin_Changed;
}