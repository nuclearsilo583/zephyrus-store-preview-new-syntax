#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new String:g_szKnives[STORE_MAX_ITEMS][64];
new g_unDefIndex[STORE_MAX_ITEMS];
new bool:g_bGivingKnife[MAXPLAYERS+1] = {false,...};
new g_iKnives = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Knives_OnPluginStart()
#endif
{
	if(!GAME_CSGO)
		return;

	Store_RegisterHandler("knife", "entity", Knives_OnMapStart, Knives_Reset, Knives_Config, Knives_Equip, Knives_Remove, true);
}

public Knives_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, Knives_OnPostWeaponEquip);
}

public Knives_OnMapStart()
{
}

public Knives_Reset()
{
	g_iKnives = 0;
}

public Knives_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iKnives);
	
	KvGetString(kv, "entity", g_szKnives[g_iKnives], sizeof(g_szKnives[]));
	g_unDefIndex[g_iKnives] = KvGetNum(kv, "defindex");
	
	++g_iKnives;
	return true;
}

public Knives_Equip(client, id)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		CreateTimer(0.0, Knives_CheckKnife, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	return 0;
}

public Knives_Remove(client)
{
	return 0;
}

stock Knives_GiveClient(client)
{
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return;

	new m_iKnife = GetPlayerWeaponSlot(client, 2);

	if(m_iKnife != -1)
	{
		new m_iItem = Store_GetEquippedItem(client, "knife");
		if(m_iItem < 0) return;
		new m_iData = Store_GetDataIndex(m_iItem);
		RemovePlayerItem(client, m_iKnife);
		RemoveEdict(m_iKnife);
		CreateTimer(0.1, Timer_ResetGivingKnife, client);
		g_bGivingKnife[client]=true;
		m_iKnife = GivePlayerItem(client, g_szKnives[m_iData]);
		EquipPlayerWeapon(client, m_iKnife);
	}
}

public Action:Timer_ResetGivingKnife(Handle:timer, any:data)
{
	g_bGivingKnife[data]=false;
	return Plugin_Stop;
}

public Action:Knives_OnPostWeaponEquip(client, weapon)
{ 
	if(!GAME_CSGO)
		return Plugin_Continue;

	new String:edict[64];
	GetEdictClassname(weapon, STRING(edict));
	if (strcmp(edict, "weapon_knife")!=0)
		return Plugin_Continue;

	if(g_bGivingKnife[client])
	{
		new m_iItem = Store_GetEquippedItem(client, "knife");
		if(m_iItem < 0) return Plugin_Continue;
		new m_iData = Store_GetDataIndex(m_iItem);

		if(g_unDefIndex[m_iData] != 0)
			SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_unDefIndex[m_iData]);
		return Plugin_Continue;
	}

	CreateTimer(0.0, Knives_CheckKnife, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action:Knives_CheckKnife(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	Knives_GiveClient(client);
	
	return Plugin_Handled;
}