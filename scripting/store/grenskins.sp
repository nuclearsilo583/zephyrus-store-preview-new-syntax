#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#include <sdkhooks>

new bool:GAME_TF2 = false;
#endif

enum GrenadeSkin
{
	String:szModel_Grenade[PLATFORM_MAX_PATH],
	String:szWeapon[64],
	iLength,
	iSlot_Grenade
}

new g_eGrenadeSkins[STORE_MAX_ITEMS][GrenadeSkin];

new String:g_szSlots[16][64];

new g_iGrenadeSkins = 0;
new g_iSlot_Grenades = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public GrenadeSkins_OnPluginStart()
#endif
{
#if !defined STANDALONE_BUILD
	// This is not a standalone build, we don't want grenade skins to kill the whole plugin for us	
	if(GetExtensionFileStatus("sdkhooks.ext")!=1)
	{
		LogError("SDKHooks isn't installed or failed to load. Grenade Skins will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
#else
	// TF2 is unsupported
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif
	
	Store_RegisterHandler("grenadeskin", "model", GrenadeSkins_OnMapStart, GrenadeSkins_Reset, GrenadeSkins_Config, GrenadeSkins_Equip, GrenadeSkins_Remove, true);
}

public GrenadeSkins_OnMapStart()
{
	for(new i=0;i<g_iGrenadeSkins;++i)
	{
		PrecacheModel2(g_eGrenadeSkins[i][szModel_Grenade], true);
		Downloader_AddFileToDownloadsTable(g_eGrenadeSkins[i][szModel_Grenade]);
	}
}

public GrenadeSkins_Reset()
{
	g_iGrenadeSkins = 0;
}

public GrenadeSkins_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iGrenadeSkins);
	KvGetString(kv, "model", g_eGrenadeSkins[g_iGrenadeSkins][szModel_Grenade], PLATFORM_MAX_PATH);
	KvGetString(kv, "grenade", g_eGrenadeSkins[g_iGrenadeSkins][szWeapon], PLATFORM_MAX_PATH);
	
	g_eGrenadeSkins[g_iGrenadeSkins][iSlot_Grenade] = GrenadeSkins_GetSlot(g_eGrenadeSkins[g_iGrenadeSkins][szWeapon]);
	g_eGrenadeSkins[g_iGrenadeSkins][iLength] = strlen(g_eGrenadeSkins[g_iGrenadeSkins][szWeapon]);
	
	if(!(FileExists(g_eGrenadeSkins[g_iGrenadeSkins][szModel_Grenade], true)))
		return false;
		
	++g_iGrenadeSkins;
	return true;
}

public GrenadeSkins_Equip(client, id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)][iSlot_Grenade];
}

public GrenadeSkins_Remove(client, id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)][iSlot_Grenade];
}

public GrenadeSkins_GetSlot(String:weapon[])
{
	for(new i=0;i<g_iSlot_Grenades;++i)
		if(strcmp(weapon, g_szSlots[i])==0)
			return i;
	
	strcopy(g_szSlots[g_iSlot_Grenades], sizeof(g_szSlots[]), weapon);
	return g_iSlot_Grenades++;
}

#if defined STANDALONE_BUILD
public OnEntityCreated(entity, const String:classname[])
#else
public GrenadeSkins_OnEntityCreated(entity, const String:classname[])
#endif
{
	if(g_iGrenadeSkins == 0)
		return;
	if(StrContains(classname, "_projectile")>0)
		SDKHook(entity, SDKHook_SpawnPost, GrenadeSkins_OnEntitySpawnedPost);		
}

public GrenadeSkins_OnEntitySpawnedPost(entity)
{
	new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(!(0<client<=MaxClients))
		return;
	
	decl String:m_szClassname[64];
	GetEdictClassname(entity, m_szClassname, sizeof(m_szClassname));
	
	decl m_iSlot_Grenade;
	
	if(GAME_TF2)
		m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname[14]);
	else
	{
		for(new i=0;i<strlen(m_szClassname);++i)
			if(m_szClassname[i]=='_')
			{
				m_szClassname[i]=0;
				break;
			}
		m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname);
	}	
	
	new m_iEquipped = Store_GetEquippedItem(client, "grenadeskin", m_iSlot_Grenade);
	
	if(m_iEquipped < 0)
		return;
		
	new m_iData = Store_GetDataIndex(m_iEquipped);
	SetEntityModel(entity, g_eGrenadeSkins[m_iData][szModel_Grenade]);
}