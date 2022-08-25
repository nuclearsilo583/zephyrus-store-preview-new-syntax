#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new Float:g_fInvisibilityTime[STORE_MAX_ITEMS]; 

new g_iInvisibility[STORE_MAX_ITEMS];
new g_iInvisibilityIdx = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Invisibility_OnPluginStart()
#endif
{
	Store_RegisterHandler("invisibility", "", Invisibility_OnMapStart, Invisibility_Reset, Invisibility_Config, Invisibility_Equip, Invisibility_Remove, false);
}

public Invisibility_OnMapStart()
{
}

public Invisibility_Reset()
{
	g_iInvisibilityIdx = 0;
}

public Invisibility_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iInvisibilityIdx);
	
	g_iInvisibility[g_iInvisibilityIdx] = KvGetNum(kv, "invisibility");
	g_fInvisibilityTime[g_iInvisibilityIdx] = KvGetFloat(kv, "duration");

	++g_iInvisibilityIdx;
	return true;
}

public Invisibility_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);

	new m_iR = GetEntProp(client, Prop_Data, "m_clrRender", 1, 0);
	new m_iG = GetEntProp(client, Prop_Data, "m_clrRender", 1, 1);
	new m_iB = GetEntProp(client, Prop_Data, "m_clrRender", 1, 2);
	new m_iA = GetEntProp(client, Prop_Data, "m_clrRender", 1, 3);

	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, m_iR, m_iG, m_iB, g_iInvisibility[m_iData]);
	if(g_fInvisibilityTime[m_iData] != 0.0)
	{
		new Handle:m_hData = CreateDataPack();
		WritePackCell(m_hData, GetClientUserId(client));
		WritePackCell(m_hData, m_iR);
		WritePackCell(m_hData, m_iG);
		WritePackCell(m_hData, m_iB);
		WritePackCell(m_hData, m_iA);
		ResetPack(m_hData);
		CreateTimer(g_fGravityTime[m_iData], Timer_RemoveInvisibility, m_hData);
	}

	return 0;
}

public Invisibility_Remove(client)
{
	return 0;
}

public Action:Timer_RemoveInvisibility(Handle:timer, any:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	new m_iR = ReadPackCell(data);
	new m_iG = ReadPackCell(data);
	new m_iB = ReadPackCell(data);
	new m_iA = ReadPackCell(data);
	CloseHandle(data);

	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntityRenderColor(client, m_iR, m_iG, m_iB, m_iA);

	return Plugin_Stop;
}