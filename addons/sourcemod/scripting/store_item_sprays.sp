#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <store>
#include <zephstocks>

#include <colors>

char g_szSprays[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iSprayPrecache[STORE_MAX_ITEMS] = {-1,...};
int g_iSprayCache[MAXPLAYERS+1] = {-1,...};
int g_iSprayLimit[MAXPLAYERS+1] = {0,...};
int g_iSprays = 0;

int g_cvarSprayLimit = -1;
int g_cvarSprayDistance = -1;

bool GAME_CSGO = false;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
char g_sChatPrefix[128];

public void OnPluginStart()
{
	g_cvarSprayLimit = RegisterConVar("sm_store_spray_limit", "30", "Number of seconds between two sprays", TYPE_INT);
	g_cvarSprayDistance = RegisterConVar("sm_store_spray_distance", "115", "Distance from wall to spray", TYPE_FLOAT);
	
	// only CSGO is supported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	LoadTranslations("store.phrases");
	
	
	if(GAME_CSGO)
		Store_RegisterHandler("spray", "material", Sprays_OnMapStart, Sprays_Reset, Sprays_Config, Sprays_Equip, Sprays_Remove, true);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Sprays_OnMapStart()
{
	char m_szDecal[PLATFORM_MAX_PATH];

	for(int i=0;i<g_iSprays;++i)
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

public void Sprays_OnClientConnected(int client)
{
	g_iSprayCache[client]=-1;
}

public Action OnPlayerRunCmd(int client,int &buttons)
{
	if(buttons & IN_USE && g_iSprayCache[client] != -1 && g_iSprayLimit[client]<=GetTime())
	{
		Sprays_Create(client);
	}
}

public void Sprays_Reset()
{
	g_iSprays = 0;
}

public bool Sprays_Config(Handle &kv,int itemid)
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

public int Sprays_Equip(int client,int id)
{
	int m_iData = Store_GetDataIndex(id);
	g_iSprayCache[client]=m_iData;
	return 0;
}

public int Sprays_Remove(int client)
{
	g_iSprayCache[client]=-1;
	return 0;
}

public void Sprays_Create(int client)
{
	if(!IsPlayerAlive(client))
		return;

	float m_flEye[3];
	GetClientEyePosition(client, m_flEye);

	float m_flView[3];
	GetPlayerEyeViewPoint(client, m_flView);

	if(GetVectorDistance(m_flEye, m_flView) > g_eCvars[g_cvarSprayDistance].aCache)
		return;

	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin",m_flView);
	TE_WriteNum("m_nIndex", g_iSprayPrecache[g_iSprayCache[client]]);
	TE_SendToAll();

	EmitSoundToAll("player/sprayer.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

	g_iSprayLimit[client] = GetTime()+g_eCvars[g_cvarSprayLimit].aCache;
}


stock void GetPlayerEyeViewPoint(int client, float m_fPosition[3])
{
	float m_flRotation[3];
	float m_flPosition[3];

	GetClientEyeAngles(client, m_flRotation);
	GetClientEyePosition(client, m_flPosition);

	TR_TraceRayFilter(m_flPosition, m_flRotation, MASK_ALL, RayType_Infinite, TraceRayDontHitSelf, client);
	TR_GetEndPosition(m_fPosition);
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "spray"))
		return;

	int iPreview = CreateEntityByName("env_sprite_oriented");

	DispatchKeyValue(iPreview, "model", g_szSprays[index]);
	DispatchSpawn(iPreview);

	AcceptEntityInput(iPreview, "Enable");

	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fPosition[2] += 35;

	TeleportEntity(iPreview, fPosition, NULL_VECTOR, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;
	
	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}