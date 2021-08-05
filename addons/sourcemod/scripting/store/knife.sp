#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

char g_szKnives[STORE_MAX_ITEMS][64];
int g_unDefIndex[STORE_MAX_ITEMS];
bool g_bGivingKnife[MAXPLAYERS+1] = {false,...};
int g_iKnives = 0;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Knives_OnPluginStart()
#endif
{
	if(!GAME_CSGO)
		return;

	Store_RegisterHandler("knife", "entity", Knives_OnMapStart, Knives_Reset, Knives_Config, Knives_Equip, Knives_Remove, true);
}

public void Knives_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, Knives_OnPostWeaponEquip);
}

public void Knives_OnMapStart()
{
}

public void Knives_Reset()
{
	g_iKnives = 0;
}

public bool Knives_Config(Handle &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iKnives);
	
	KvGetString(kv, "entity", g_szKnives[g_iKnives], sizeof(g_szKnives[]));
	g_unDefIndex[g_iKnives] = KvGetNum(kv, "defindex");
	
	++g_iKnives;
	return true;
}

public int Knives_Equip(int client, int id)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		CreateTimer(0.0, Knives_CheckKnife, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	return 0;
}

public int Knives_Remove(int client)
{
	return 0;
}

stock void Knives_GiveClient(int client)
{
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return;

	int m_iKnife = GetPlayerWeaponSlot(client, 2);

	if(m_iKnife != -1)
	{
		int m_iItem = Store_GetEquippedItem(client, "knife");
		if(m_iItem < 0) return;
		int m_iData = Store_GetDataIndex(m_iItem);
		RemovePlayerItem(client, m_iKnife);
		RemoveEdict(m_iKnife);
		CreateTimer(0.1, Timer_ResetGivingKnife, client);
		g_bGivingKnife[client]=true;
		m_iKnife = GivePlayerItem(client, g_szKnives[m_iData]);
		EquipPlayerWeapon(client, m_iKnife);
	}
}

public Action Timer_ResetGivingKnife(Handle timer, any data)
{
	g_bGivingKnife[data]=false;
	return Plugin_Stop;
}

public Action Knives_OnPostWeaponEquip(int client, int weapon)
{ 
	if(!GAME_CSGO)
		return Plugin_Continue;

	char edict[64];
	GetEdictClassname(weapon, STRING(edict));
	if (strcmp(edict, "weapon_knife")!=0)
		return Plugin_Continue;

	if(g_bGivingKnife[client])
	{
		int m_iItem = Store_GetEquippedItem(client, "knife");
		if(m_iItem < 0) return Plugin_Continue;
		int m_iData = Store_GetDataIndex(m_iItem);

		if(g_unDefIndex[m_iData] != 0)
			SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_unDefIndex[m_iData]);
		return Plugin_Continue;
	}

	CreateTimer(0.0, Knives_CheckKnife, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

public Action Knives_CheckKnife(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	Knives_GiveClient(client);
	
	return Plugin_Handled;
}