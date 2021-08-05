#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#include <sdkhooks>
#endif

enum GrenadeTrail
{
	String:szMaterial[PLATFORM_MAX_PATH],
	String:szWidth[16],
	String:szColor[16],
	Float:fWidth,
	iColor[4],
	iSlot,
	iCacheID
}

new g_eGrenadeTrails[STORE_MAX_ITEMS][GrenadeTrail];

new g_iGrenadeTrails = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public GrenadeTrails_OnPluginStart()
#endif
{
#if !defined STANDALONE_BUILD
	// This is not a standalone build, we don't want grenade trails to kill the whole plugin for us	
	if(GetExtensionFileStatus("sdkhooks.ext")!=1)
	{
		LogError("SDKHooks isn't installed or failed to load. Grenade Trails will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
#endif
	
	Store_RegisterHandler("grenadetrail", "material", GrenadeTrails_OnMapStart, GrenadeTrails_Reset, GrenadeTrails_Config, GrenadeTrails_Equip, GrenadeTrails_Remove, true);
}

public GrenadeTrails_OnMapStart()
{
	for(new i=0;i<g_iGrenadeTrails;++i)
	{
		g_eGrenadeTrails[i][iCacheID] = PrecacheModel2(g_eGrenadeTrails[i][szMaterial], true);
		Downloader_AddFileToDownloadsTable(g_eGrenadeTrails[i][szMaterial]);
	}
}

public GrenadeTrails_Reset()
{
	g_iGrenadeTrails = 0;
}

public GrenadeTrails_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iGrenadeTrails);
	KvGetString(kv, "material", g_eGrenadeTrails[g_iGrenadeTrails][szMaterial], PLATFORM_MAX_PATH);
	KvGetString(kv, "width", g_eGrenadeTrails[g_iGrenadeTrails][szWidth], 16, "10.0");
	g_eGrenadeTrails[g_iGrenadeTrails][fWidth] = KvGetFloat(kv, "width", 10.0);
	KvGetString(kv, "color", g_eGrenadeTrails[g_iGrenadeTrails][szColor], 16, "255 255 255 255");
	KvGetColor(kv, "color", g_eGrenadeTrails[g_iGrenadeTrails][iColor][0], g_eGrenadeTrails[g_iGrenadeTrails][iColor][1], g_eGrenadeTrails[g_iGrenadeTrails][iColor][2], g_eGrenadeTrails[g_iGrenadeTrails][iColor][3]);
	g_eGrenadeTrails[g_iGrenadeTrails][iSlot] = KvGetNum(kv, "slot");
	
	if(FileExists(g_eGrenadeTrails[g_iGrenadeTrails][szMaterial], true))
	{
		++g_iGrenadeTrails;
		return true;
	}
	
	return false;
}

public GrenadeTrails_Equip(client, id)
{
	return 0;
}

public GrenadeTrails_Remove(client, id)
{
	return 0;
}

#if defined STANDALONE_BUILD
public OnEntityCreated(entity, const String:classname[])
#else
public GrenadeTrails_OnEntityCreated(entity, const String:classname[])
#endif
{
	if(g_iGrenadeTrails == 0)
		return;
	if(StrContains(classname, "_projectile")>0)
		SDKHook(entity, SDKHook_SpawnPost, GrenadeTrails_OnEntitySpawnedPost);		
}

public GrenadeTrails_OnEntitySpawnedPost(entity)
{
	new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(!(0<client<=MaxClients))
		return;
	
	new m_iEquipped = Store_GetEquippedItem(client, "grenadetrail", 0);
	
	if(m_iEquipped < 0)
		return;
		
	new m_iData = Store_GetDataIndex(m_iEquipped);

	// Ugh...
	decl m_iColor[4];
	m_iColor[0] = g_eGrenadeTrails[m_iData][iColor][0];
	m_iColor[1] = g_eGrenadeTrails[m_iData][iColor][1];
	m_iColor[2] = g_eGrenadeTrails[m_iData][iColor][2];
	m_iColor[3] = g_eGrenadeTrails[m_iData][iColor][3];
	TE_SetupBeamFollow(entity, g_eGrenadeTrails[m_iData][iCacheID], 0, 2.0, g_eGrenadeTrails[m_iData][fWidth], g_eGrenadeTrails[m_iData][fWidth], 10, m_iColor);
	TE_SendToAll();
}