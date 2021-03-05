#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_TF2 = false;
#endif

new String:g_szPaintballDecals[STORE_MAX_ITEMS][32][PLATFORM_MAX_PATH];

new g_iPaintballDecalIDs[STORE_MAX_ITEMS][32];
new g_iPaintballDecals[STORE_MAX_ITEMS] = {0, ...};
new g_iPaintballItems = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Paintball_OnPluginStart()
#endif
{	
#if defined STANDALONE_BUILD
	// TF2 is unsupported
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif

	if(GAME_TF2)
		return;

	Store_RegisterHandler("paintball", "", Paintball_OnMapStart, Paintball_Reset, Paintball_Config, Paintball_Equip, Paintball_Remove, true);
	
	HookEvent("bullet_impact", Paintball_BulletImpact);
}

public Paintball_OnMapStart()
{
	decl String:m_szFullPath[PLATFORM_MAX_PATH];
	for(new a=0;a<g_iPaintballItems;++a)
		for(new i=0;i<g_iPaintballDecals[a];++i)
		{
			g_iPaintballDecalIDs[a][i] = PrecacheDecal(g_szPaintballDecals[a][i], true);
			Format(m_szFullPath, sizeof(m_szFullPath), "materials/%s", g_szPaintballDecals[a][i]);
			Downloader_AddFileToDownloadsTable(m_szFullPath);
		}
}

public Paintball_Reset()
{
	for(new i=0;i<STORE_MAX_ITEMS;++i)
		g_iPaintballDecals[i] = 0;
	g_iPaintballItems = 0;
}

public Paintball_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iPaintballItems);

	KvJumpToKey(kv, "Decals");
	KvGotoFirstSubKey(kv);

	do
	{
		KvGetString(kv, "material", g_szPaintballDecals[g_iPaintballItems][g_iPaintballDecals[g_iPaintballItems]], PLATFORM_MAX_PATH);
		++g_iPaintballDecals[g_iPaintballItems];
	} while (KvGotoNextKey(kv));
	
	KvGoBack(kv);
	KvGoBack(kv);

	++g_iPaintballItems;

	return true;
}

public Paintball_Equip(client, id)
{
	return -1;
}

public Paintball_Remove(client, id)
{
}

public Action:Paintball_BulletImpact(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new m_iEquipped = Store_GetEquippedItem(client, "paintball");
	if(m_iEquipped >= 0)
	{
		new m_iData = Store_GetDataIndex(m_iEquipped);
		decl Float:m_fImpact[3];
		m_fImpact[0] = GetEventFloat(event, "x");
		m_fImpact[1] = GetEventFloat(event, "y");
		m_fImpact[2] = GetEventFloat(event, "z");
		
		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin", m_fImpact);
		TE_WriteNum("m_nIndex", g_iPaintballDecalIDs[m_iData][GetRandomInt(0, g_iPaintballDecals[m_iData]-1)]);
		TE_SendToAll();
	}

	return Plugin_Continue;
}