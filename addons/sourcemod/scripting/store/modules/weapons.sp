#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new String:g_szWeapons[STORE_MAX_ITEMS][64];

new g_iWeapons = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Weapons_OnPluginStart()
#endif
{
	Store_RegisterHandler("weapon", "", Weapons_OnMapStart, Weapons_Reset, Weapons_Config, Weapons_Equip, Weapons_Remove, false);
}

public Weapons_OnMapStart()
{
}

public Weapons_Reset()
{
	g_iWeapons = 0;
}

public Weapons_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iWeapons);
	
	KvGetString(kv, "weapon", g_szWeapons[g_iWeapons], sizeof(g_szWeapons[]));
	
	++g_iWeapons;
	return true;
}

public Weapons_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	GivePlayerItem(client, g_szWeapons[m_iData]);
	return 0;
}

public Weapons_Remove(client)
{
	return 0;
}