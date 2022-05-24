#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

enum struct WeaponSkin 
{
	int nPaint;
	float flWear;
	int nStattrak;
	int nQuality;
}

WeaponSkin g_eWeaponSkins[STORE_MAX_ITEMS];
int g_iWeaponSkins = 0;

Handle g_hWeaponEnts = INVALID_HANDLE;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void WeaponSkins_OnPluginStart()
#endif
{
#if !defined STANDALONE_BUILD
	// This is not a standalone build, we don't want hats to kill the whole plugin for us	
	if(GetExtensionFileStatus("sdkhooks.ext")!=1)
	{
		LogError("SDKHooks isn't installed or failed to load. Hats will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
#endif

	if(!GAME_CSGO)
		return;	

	Store_RegisterHandler("weaponskin", "paint", WeaponSkins_OnMapStart, WeaponSkins_Reset, WeaponSkins_Config, WeaponSkins_Equip, WeaponSkins_Remove, true);

	g_hWeaponEnts = CreateArray();
}

#if defined STANDALONE_BUILD
public void OnClientPutInServer(client)
#else
public void WeaponSkins_OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_WeaponEquipPost, WeaponSkins_OnPostWeaponEquip);
}

public void WeaponSkins_OnMapStart()
{
	ClearArray(g_hWeaponEnts);
}

public void WeaponSkins_Reset()
{
	g_iWeaponSkins = 0;
}

public bool WeaponSkins_Config(Handle &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iWeaponSkins);
	
	g_eWeaponSkins[g_iWeaponSkins].nPaint=KvGetNum(kv, "paint");
	g_eWeaponSkins[g_iWeaponSkins].flWear=KvGetFloat(kv, "wear", -1.0);
	g_eWeaponSkins[g_iWeaponSkins].nStattrak=KvGetNum(kv, "stattrak", -2);
	g_eWeaponSkins[g_iWeaponSkins].nQuality=KvGetNum(kv, "quality", -2);

	++g_iWeaponSkins;
	return true;
}

public int WeaponSkins_Equip(int client, int id)
{
	if(!IsValidEdict(client))
		return 0;

	int data = Store_GetDataIndex(id);

	for(int i=0;i<48;++i)
	{
		int m_iEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if(m_iEntity == -1)
			continue;

		Handle pack;
		CreateDataTimer(0.1, ApplySkin, pack);
		WritePackCell(pack, GetClientUserId(client));
		WritePackCell(pack, m_iEntity);
		WritePackCell(pack, data);
		ResetPack(pack);		
	}
	return 0;
}

public int WeaponSkins_Remove(int client)
{
	for(int i=0;i<48;++i)
	{
		int m_iEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if(m_iEntity == -1)
			continue;
	}
	return 0;
}

public Action WeaponSkins_OnPostWeaponEquip(int client, int weapon)
{
	if(g_iWeaponSkins==0)
		return Plugin_Continue;

	int m_iEquipped = Store_GetEquippedItem(client, "weaponskin", 0);
	if(m_iEquipped<0)
		return Plugin_Continue;
	int data = Store_GetDataIndex(m_iEquipped);

	Handle pack;
	CreateDataTimer(0.1, ApplySkin, pack);
	WritePackCell(pack, GetClientUserId(client));
	WritePackCell(pack, weapon);
	WritePackCell(pack, data);
	ResetPack(pack);
	
	return Plugin_Continue;
}

public Action ApplySkin(Handle timer, any pack)
{
	int client = GetClientOfUserId(ReadPackCell(pack));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}

	int ent = ReadPackCell(pack);

	int idx = FindValueInArray(g_hWeaponEnts, ent);
	if(idx != -1)
	{
		RemoveFromArray(g_hWeaponEnts, idx);
		return Plugin_Stop;
	}

	if(!IsValidEdict(ent))
		return Plugin_Stop;


	int data = ReadPackCell(pack);

	int m_iItemIDHigh = GetEntProp(ent, Prop_Send, "m_iItemIDHigh");
	int m_iItemIDLow = GetEntProp(ent, Prop_Send, "m_iItemIDLow");

	int m_nEnt = ent;
	//if(ent != GetPlayerWeaponSlot(client, 2))
	{
		char classname[32];
		GetEntPropString(ent, Prop_Data, "m_iClassname", STRING(classname));

		if(strcmp(classname, "weapon_hegrenade")==0 || 
			strcmp(classname, "weapon_flashbang")==0 || 
			strcmp(classname, "weapon_smokegrenade")==0 || 
			strcmp(classname, "weapon_decoy")==0 || 
			strcmp(classname, "weapon_molotov")==0 || 
			strcmp(classname, "weapon_incendiary")==0 || 
			strcmp(classname, "weapon_c4")==0 )
			return Plugin_Stop;

		int Clip1 = -1;
		int Clip2 = -1;
		if(GetEntSendPropOffs(ent, "m_iClip1") != -1)
			Clip1 = GetEntProp(ent, Prop_Send, "m_iClip1");
		
		if(GetEntSendPropOffs(ent, "m_iClip2") != -1)
			Clip2 = GetEntProp(ent, Prop_Send, "m_iClip1");

		RemovePlayerItem(client, ent);
		RemoveEntity(ent);

		m_nEnt = GivePlayerItem(client, classname);
		PushArrayCell(g_hWeaponEnts, m_nEnt);
		PushArrayCell(g_hWeaponEnts, m_nEnt);
		if(Clip1 != -1)
			SetEntProp(m_nEnt, Prop_Send, "m_iClip1", Clip1);
		
		if(Clip2 != -1)
			SetEntProp(m_nEnt, Prop_Send, "m_iClip1", Clip2);

		EquipPlayerWeapon(client, m_nEnt);
	}

	SetEntProp(m_nEnt, Prop_Send, "m_iItemIDLow",2048);
	SetEntProp(m_nEnt, Prop_Send, "m_iItemIDHigh",0);

	SetEntProp(m_nEnt, Prop_Send, "m_nFallbackPaintKit", g_eWeaponSkins[data].nPaint);
	if(g_eWeaponSkins[data].flWear >= 0.0) SetEntPropFloat(m_nEnt, Prop_Send, "m_flFallbackWear", g_eWeaponSkins[data].flWear);
	if(g_eWeaponSkins[data].nStattrak != -2) SetEntProp(m_nEnt, Prop_Send, "m_nFallbackStatTrak", g_eWeaponSkins[data].nStattrak);
	if(g_eWeaponSkins[data].nQuality != -2) SetEntProp(m_nEnt, Prop_Send, "m_iEntityQuality", g_eWeaponSkins[data].nQuality);

	if(ent == GetPlayerWeaponSlot(client, 2))
	{
		int m_iItem = Store_GetEquippedItem(client, "knife");
		if(m_iItem >= 0)
		{
			int m_iData = Store_GetDataIndex(m_iItem);

			if(g_unDefIndex[m_iData] != 0)
				SetEntProp(m_nEnt, Prop_Send, "m_iItemDefinitionIndex", g_unDefIndex[m_iData]);
		}
	}

	Handle pack2;
	CreateDataTimer(0.2, RestoreItemID, pack2);
	WritePackCell(pack2, EntIndexToEntRef(m_nEnt));
	WritePackCell(pack2, m_iItemIDHigh);
	WritePackCell(pack2, m_iItemIDLow);

	return Plugin_Stop;
}

public Action RestoreItemID(Handle timer, Handle pack)
{
    int entity;
    int m_iItemIDHigh;
    int m_iItemIDLow;
    
    ResetPack(pack);
    entity = EntRefToEntIndex(ReadPackCell(pack));
    m_iItemIDHigh = ReadPackCell(pack);
    m_iItemIDLow = ReadPackCell(pack);
    
    if(entity != INVALID_ENT_REFERENCE)
	{
		SetEntProp(entity, Prop_Send, "m_iItemIDHigh", m_iItemIDHigh);
		SetEntProp(entity, Prop_Send, "m_iItemIDLow", m_iItemIDLow);
	}
}