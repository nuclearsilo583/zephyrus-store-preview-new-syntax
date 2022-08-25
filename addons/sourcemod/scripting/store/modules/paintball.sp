#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

bool GAME_TF2 = false;
#endif

char g_szPaintballDecals[STORE_MAX_ITEMS][32][PLATFORM_MAX_PATH];

int g_iPaintballDecalIDs[STORE_MAX_ITEMS][32];
int g_iPaintballDecals[STORE_MAX_ITEMS] = {0, ...};
int g_iPaintballItems = 0;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Paintball_OnPluginStart()
#endif
{	
#if defined STANDALONE_BUILD
	// TF2 is unsupported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif

	if(GAME_TF2)
		return;

	Store_RegisterHandler("paintball", "", Paintball_OnMapStart, Paintball_Reset, Paintball_Config, Paintball_Equip, Paintball_Remove, true);
	
	HookEvent("bullet_impact", Paintball_BulletImpact);
}

public void Paintball_OnMapStart()
{
	char m_szFullPath[PLATFORM_MAX_PATH];
	for(int a=0;a<g_iPaintballItems;++a)
		for(int i=0;i<g_iPaintballDecals[a];++i)
		{
			g_iPaintballDecalIDs[a][i] = PrecacheDecal(g_szPaintballDecals[a][i], true);
			Format(m_szFullPath, sizeof(m_szFullPath), "materials/%s", g_szPaintballDecals[a][i]);
			Downloader_AddFileToDownloadsTable(m_szFullPath);
		}
}

public void Paintball_Reset()
{
	for(int i=0;i<STORE_MAX_ITEMS;++i)
		g_iPaintballDecals[i] = 0;
	g_iPaintballItems = 0;
}

public bool Paintball_Config(Handle kv,int itemid)
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

public int Paintball_Equip(int client,int id)
{
	return -1;
}

public int Paintball_Remove(int client,int id)
{
}

public Action Paintball_BulletImpact(Handle event,const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int m_iEquipped = Store_GetEquippedItem(client, "paintball");
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		float m_fImpact[3];
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