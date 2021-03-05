#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new g_iSpeedIdx = 0;

new Float:g_fSpeed[STORE_MAX_ITEMS];
new Float:g_fSpeedTime[STORE_MAX_ITEMS];

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Speed_OnPluginStart()
#endif
{
	Store_RegisterHandler("speed", "", Speed_OnMapStart, Speed_Reset, Speed_Config, Speed_Equip, Speed_Remove, false);
}

public Speed_OnMapStart()
{
}

public Speed_Reset()
{
	g_iSpeedIdx = 0;
}

public Speed_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iSpeedIdx);
	
	g_fSpeed[g_iSpeedIdx] = KvGetFloat(kv, "speed");
	g_fSpeedTime[g_iSpeedIdx] = KvGetFloat(kv, "duration");

	++g_iSpeedIdx;
	return true;
}

public Speed_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeed[m_iData]);
	if(g_fSpeedTime[m_iData] != 0.0)
		CreateTimer(g_fSpeedTime[m_iData], Timer_RemoveSpeed, GetClientUserId(client));
	return 0;
}

public Speed_Remove(client)
{
	return 0;
}

public Action:Timer_RemoveSpeed(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

	return Plugin_Stop;
}