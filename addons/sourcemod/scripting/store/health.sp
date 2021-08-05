#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new g_iHealths[STORE_MAX_ITEMS];
new g_iHealthIdx = 0;
new g_iRoundLimit[MAXPLAYERS+1] = {0,...};

new g_cvarHealthRoundLimit = -1;
new g_cvarMaximumHealth = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Health_OnPluginStart()
#endif
{
	Store_RegisterHandler("health", "", Health_OnMapStart, Health_Reset, Health_Config, Health_Equip, Health_Remove, false);

	g_cvarHealthRoundLimit = RegisterConVar("sm_store_health_round_limit", "1", "Number of times you can buy health in a round", TYPE_INT);
	g_cvarMaximumHealth = RegisterConVar("sm_store_health_maximum", "0", "Maximum amount of health one can get, 0 means unlimited", TYPE_INT);

#if defined STANDALONE_BUILD
	HookEvent("player_spawn", Health_OnPlayerSpawn);
#endif
}

#if defined STANDALONE_BUILD
public Action:Health_OnPlayerSpwan(Handle:event, const String:name[], bool:dontBroadcast)
#else
public Health_OnPlayerSpawn(client)
#endif
{
#if defined STANDALONE_BUILD
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsClientInGame(client))
		return Plugin_Continue;
#endif

	g_iRoundLimit[client] = 0;

#if defined STANDALONE_BUILD
	return Plugin_Continue;
#endif
}

public Health_OnMapStart()
{
}

public Health_Reset()
{
	g_iHealthIdx = 0;
}

public Health_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iHealthIdx);
	
	g_iHealths[g_iHealthIdx] = KvGetNum(kv, "health");

	++g_iHealthIdx;
	return true;
}

public Health_Equip(client, id)
{
	if(g_iRoundLimit[client] == g_eCvars[g_cvarHealthRoundLimit][aCache])
	{
		Chat(client, "%t", "Health Round Limit");
		return 1;
	}

	new m_iData = Store_GetDataIndex(id);
	new m_iHealth = GetClientHealth(client)+g_iHealths[m_iData];
	if(g_eCvars[g_cvarMaximumHealth][aCache] != 0 && m_iHealth > g_eCvars[g_cvarMaximumHealth][aCache])
		m_iHealth = g_eCvars[g_cvarMaximumHealth][aCache];
	SetEntityHealth(client, m_iHealth);
	++g_iRoundLimit[client];
	return 0;
}

public Health_Remove(client)
{
	return 0;
}