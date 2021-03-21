#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#include <sdkhooks>

bool GAME_TF2 = false;
#endif

enum struct GrenadeSkin
{
	char szModel_Grenade[PLATFORM_MAX_PATH];
	char szWeapon[64];
	int iLength;
	int iSlot_Grenade;
}

GrenadeSkin g_eGrenadeSkins[STORE_MAX_ITEMS];

char g_szSlots[16][64];

int g_iGrenadeSkins = 0;
int g_iSlot_Grenades = 0;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void GrenadeSkins_OnPluginStart()
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
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif
	
	Store_RegisterHandler("grenadeskin", "model", GrenadeSkins_OnMapStart, GrenadeSkins_Reset, GrenadeSkins_Config, GrenadeSkins_Equip, GrenadeSkins_Remove, true);
}

public void GrenadeSkins_OnMapStart()
{
	for(int i=0;i<g_iGrenadeSkins;++i)
	{
		PrecacheModel2(g_eGrenadeSkins[i].szModel_Grenade, true);
		Downloader_AddFileToDownloadsTable(g_eGrenadeSkins[i].szModel_Grenade);
	}
}

public void GrenadeSkins_Reset()
{
	g_iGrenadeSkins = 0;
}

public bool GrenadeSkins_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iGrenadeSkins);
	KvGetString(kv, "model", g_eGrenadeSkins[g_iGrenadeSkins].szModel_Grenade, PLATFORM_MAX_PATH);
	KvGetString(kv, "grenade", g_eGrenadeSkins[g_iGrenadeSkins].szWeapon, PLATFORM_MAX_PATH);
	
	g_eGrenadeSkins[g_iGrenadeSkins].iSlot_Grenade = GrenadeSkins_GetSlot(g_eGrenadeSkins[g_iGrenadeSkins].szWeapon);
	g_eGrenadeSkins[g_iGrenadeSkins].iLength = strlen(g_eGrenadeSkins[g_iGrenadeSkins].szWeapon);
	
	if(!(FileExists(g_eGrenadeSkins[g_iGrenadeSkins].szModel_Grenade, true)))
		return false;
		
	++g_iGrenadeSkins;
	return true;
}

public int GrenadeSkins_Equip(int client,int id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)].iSlot_Grenade;
}

public int GrenadeSkins_Remove(int client,int id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)].iSlot_Grenade;
}

public int GrenadeSkins_GetSlot(char[] weapon)
{
	for(int i=0;i<g_iSlot_Grenades;++i)
		if(strcmp(weapon, g_szSlots[i])==0)
			return i;
	
	strcopy(g_szSlots[g_iSlot_Grenades], sizeof(g_szSlots[]), weapon);
	return g_iSlot_Grenades++;
}

#if defined STANDALONE_BUILD
public void OnEntityCreated(int entity, const char[] classname)
#else
public void GrenadeSkins_OnEntityCreated(int entity, const char[] classname)
#endif
{
	if(g_iGrenadeSkins == 0)
		return;
	if(StrContains(classname, "_projectile")>0)
		SDKHook(entity, SDKHook_SpawnPost, GrenadeSkins_OnEntitySpawnedPost);		
}

public void GrenadeSkins_OnEntitySpawnedPost(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(!(0<client<=MaxClients))
		return;
	
	char m_szClassname[64];
	GetEdictClassname(entity, m_szClassname, sizeof(m_szClassname));
	
	any m_iSlot_Grenade;
	
	if(GAME_TF2)
		m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname[14]);
	else
	{
		for(int i=0;i<strlen(m_szClassname);++i)
			if(m_szClassname[i]=='_')
			{
				m_szClassname[i]=0;
				break;
			}
		m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname);
	}	
	
	int m_iEquipped = Store_GetEquippedItem(client, "grenadeskin", m_iSlot_Grenade);
	
	if(m_iEquipped < 0)
		return;
		
	int m_iData = Store_GetDataIndex(m_iEquipped);
	SetEntityModel(entity, g_eGrenadeSkins[m_iData].szModel_Grenade);
}