#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new String:g_szSprays[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
new g_iSprayPrecache[STORE_MAX_ITEMS] = {-1,...};
new g_iSprayCache[MAXPLAYERS+1] = {-1,...};
new g_iSprayLimit[MAXPLAYERS+1] = {0,...};
new g_iSprays = 0;

new g_cvarSprayLimit = -1;
new g_cvarSprayDistance = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Sprays_OnPluginStart()
#endif
{
	g_cvarSprayLimit = RegisterConVar("sm_store_spray_limit", "30", "Number of seconds between two sprays", TYPE_INT);
	g_cvarSprayDistance = RegisterConVar("sm_store_spray_distance", "115", "Distance from wall to spray", TYPE_FLOAT);

	if(GAME_CSGO)
		Store_RegisterHandler("spray", "material", Sprays_OnMapStart, Sprays_Reset, Sprays_Config, Sprays_Equip, Sprays_Remove, true);
}

public Sprays_OnMapStart()
{
	new String:m_szDecal[PLATFORM_MAX_PATH];

	for(new i=0;i<g_iSprays;++i)
	{
		if(FileExists(g_szSprays[i], true))
		{
			strcopy(STRING(m_szDecal), g_szSprays[i][10]);
			PrintToServer("%s (%d)", m_szDecal, strlen(m_szDecal)-4);
			m_szDecal[strlen(m_szDecal)-4]=0;

			g_iSprayPrecache[i] = PrecacheDecal(m_szDecal, true);
			Downloader_AddFileToDownloadsTable(g_szSprays[i]);
		}
	}

	PrecacheSound("player/sprayer.wav", true);
}

public Sprays_OnClientConnected(client)
{
	g_iSprayCache[client]=-1;
}

public Sprays_OnPlayerRunCmd(client, buttons)
{
	if(buttons & IN_USE && g_iSprayCache[client] != -1 && g_iSprayLimit[client]<=GetTime())
	{
		Sprays_Create(client);
	}
}

public Sprays_Reset()
{
	g_iSprays = 0;
}

public Sprays_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iSprays);
	KvGetString(kv, "material", g_szSprays[g_iSprays], sizeof(g_szSprays[]));

	if(FileExists(g_szSprays[g_iSprays], true))
	{
		++g_iSprays;
		return true;
	}
	return false;
}

public Sprays_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	g_iSprayCache[client]=m_iData;
	return 0;
}

public Sprays_Remove(client)
{
	g_iSprayCache[client]=-1;
	return 0;
}

public Sprays_Create(client)
{
	if(!IsPlayerAlive(client))
		return;

	decl Float:m_flEye[3];
	GetClientEyePosition(client, m_flEye);

	decl Float:m_flView[3];
	GetPlayerEyeViewPoint(client, m_flView);

	if(GetVectorDistance(m_flEye, m_flView) > Float:g_eCvars[g_cvarSprayDistance][aCache])
		return;

	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin",m_flView);
	TE_WriteNum("m_nIndex", g_iSprayPrecache[g_iSprayCache[client]]);
	TE_SendToAll();

	EmitSoundToAll("player/sprayer.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

	g_iSprayLimit[client] = GetTime()+g_eCvars[g_cvarSprayLimit][aCache];
}


stock GetPlayerEyeViewPoint(client, Float:m_fPosition[3])
{
	decl Float:m_flRotation[3];
	decl Float:m_flPosition[3];

	GetClientEyeAngles(client, m_flRotation);
	GetClientEyePosition(client, m_flPosition);

	TR_TraceRayFilter(m_flPosition, m_flRotation, MASK_ALL, RayType_Infinite, TraceRayDontHitSelf, client);
	TR_GetEndPosition(m_fPosition);
}