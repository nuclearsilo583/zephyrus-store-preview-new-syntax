#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new g_iGravity[STORE_MAX_ITEMS];
new g_iGravityIdx = 0;

new Float:g_fGravityTime[STORE_MAX_ITEMS];

new Handle:g_hGravity = INVALID_HANDLE;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Gravity_OnPluginStart()
#endif
{
	Store_RegisterHandler("gravity", "", Gravity_OnMapStart, Gravity_Reset, Gravity_Config, Gravity_Equip, Gravity_Remove, false);

	g_hGravity = FindConVar("sv_gravity");
}

public Gravity_OnMapStart()
{
}

public Gravity_Reset()
{
	g_iGravityIdx = 0;
}

public Gravity_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iGravityIdx);
	
	g_iGravity[g_iGravityIdx] = KvGetNum(kv, "gravity");
	g_fGravityTime[g_iGravityIdx] = KvGetFloat(kv, "duration");

	++g_iGravityIdx;
	return true;
}

public Gravity_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	if(GetConVarInt(g_hGravity)==0)
		SetEntityGravity(client, 0.0);
	else
		SetEntityGravity(client, float(g_iGravity[m_iData])/GetConVarInt(g_hGravity));
	if(g_fGravityTime[m_iData] != 0.0)
		CreateTimer(g_fGravityTime[m_iData], Timer_RemoveGravity, GetClientUserId(client));
	return 0;
}

public Gravity_Remove(client)
{
	return 0;
}

public Action:Timer_RemoveGravity(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntityGravity(client, 1.0);

	return Plugin_Stop;
}