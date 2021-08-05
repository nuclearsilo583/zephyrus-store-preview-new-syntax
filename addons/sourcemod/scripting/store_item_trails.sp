#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

#include <colors>

#include <store>
#include <zephstocks>

bool GAME_CSGO = false;
//bool GAME_TF2 = false;

enum struct Trail
{
	char szMaterial[PLATFORM_MAX_PATH];
	char szWidth[16];
	char szColor[16];
	float fWidth;
	int iColor[4];
	int iSlot;
	int iCacheID;
}
Trail g_eTrails[STORE_MAX_ITEMS];

int g_iTrails = 0;
int g_iClientTrails[MAXPLAYERS+1][STORE_MAX_SLOTS];

bool g_bSpawnTrails[MAXPLAYERS+1];

float g_fClientCounters[MAXPLAYERS+1];
float g_fLastPosition[MAXPLAYERS+1][3];

int g_cvarPadding = -1;
int g_cvarMaxColumns = -1;
int g_cvarTrailLife = -1;

int g_iTrailOwners[2048]={-1};

char g_sChatPrefix[128];

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public Plugin myinfo = 
{
	name = "Store - Tracers Module",
	author = "nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}


public void OnPluginStart()
{
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	LoadTranslations("store.phrases");
	
	if(strcmp(m_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	//else if(strcmp(m_szGameDir, "tf")==0)
	//	GAME_TF2 = true;

	g_cvarPadding = RegisterConVar("sm_store_trails_padding", "30.0", "Space between two trails", TYPE_FLOAT);
	g_cvarMaxColumns = RegisterConVar("sm_store_trails_columns", "3", "Number of columns before starting to increase altitude", TYPE_INT);
	g_cvarTrailLife = RegisterConVar("sm_store_trails_life", "1.0", "Life of a trail in seconds", TYPE_FLOAT);
	
	Store_RegisterHandler("trail", "material", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);
	
	RegConsoleCmd("sm_hidetrail", Command_Hide, "Hides the Trails");
	
	HookEvent("player_spawn", Trails_PlayerSpawn);
	HookEvent("player_death", Trails_PlayerDeath);
	
	AutoExecConfig(true, "plugin.store");
	
	g_hHideCookie = RegClientCookie("Trails_Hide_Cookie", "Cookie to check if Trails are blocked", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		switch(g_bHide[client])
		{
			case false: FormatEx(buffer, maxlen, "Hide Trail: Disabled");
			case true: FormatEx(buffer, maxlen, "Hide Trail: Enabled");
		}
	}

	if (actions == CookieMenuAction_SelectOption)
	{
		//ClientCommand(client, "sm_hidetrail");
		CMD_Hide(client);
		ShowCookieMenu(client);
	}
}

void CMD_Hide(int client)
{
	char sCookieValue[8];

	switch(g_bHide[client])
	{
		case false:
		{
			g_bHide[client] = true;
			IntToString(1, sCookieValue, sizeof(sCookieValue));
			SetClientCookie(client, g_hHideCookie, sCookieValue);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "trail");
		}
		case true:
		{
			g_bHide[client] = false;
			IntToString(0, sCookieValue, sizeof(sCookieValue));
			SetClientCookie(client, g_hHideCookie, sCookieValue);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "trail");
		}
	}
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}


public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hHideCookie, sValue, sizeof(sValue));

	g_bHide[client] = (sValue[0] && StringToInt(sValue));
}

public Action Command_Hide(int client, int args)
{
	g_bHide[client] = !g_bHide[client];
	if (g_bHide[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "trail");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "trail");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	g_bHide[client] = false;
}

public void Trails_OnMapStart()
{
	for(int a=0;a<=MaxClients;++a)
		for(int b=0;b<STORE_MAX_SLOTS;++b)
			g_iClientTrails[a][b]=0;

	for(int i=0;i<g_iTrails;++i)
	{
		g_eTrails[i].iCacheID = PrecacheModel2(g_eTrails[i].szMaterial, true);
		Downloader_AddFileToDownloadsTable(g_eTrails[i].szMaterial);
	}
}

public int Trails_Reset()
{
	g_iTrails = 0;
}

public bool Trails_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iTrails);
	KvGetString(kv, "material", g_eTrails[g_iTrails].szMaterial, PLATFORM_MAX_PATH);
	KvGetString(kv, "width", g_eTrails[g_iTrails].szWidth, 16, "10.0");
	g_eTrails[g_iTrails].fWidth = KvGetFloat(kv, "width", 10.0);
	KvGetString(kv, "color", g_eTrails[g_iTrails].szColor, 16, "255 255 255");
	KvGetColor(kv, "color", g_eTrails[g_iTrails].iColor[0], g_eTrails[g_iTrails].iColor[1], g_eTrails[g_iTrails].iColor[2], g_eTrails[g_iTrails].iColor[3]);
	g_eTrails[g_iTrails].iSlot = KvGetNum(kv, "slot");
	
	if(FileExists(g_eTrails[g_iTrails].szMaterial, true))
	{
		++g_iTrails;
		return true;
	}
	
	return false;
}

public int Trails_Equip(int client,int id)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return -1;
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	return g_eTrails[Store_GetDataIndex(id)].iSlot;
}

public int Trails_Remove(int client,int id)
{
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	return  g_eTrails[Store_GetDataIndex(id)].iSlot;
}

public Action Timer_CreateTrails(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	for(int i=0;i<STORE_MAX_SLOTS;++i)
	{
		RemoveTrail(client, i);
		CreateTrail(client, -1, i);
	}
	return Plugin_Stop;
}

public Action Trails_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
	
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	
	return Plugin_Continue;
}

public Action Trails_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsPlayerAlive(client))
		for(int i=0;i<STORE_MAX_SLOTS;++i)
			RemoveTrail(client, i);
	return Plugin_Continue;
}

void CreateTrail(int client,int itemid=-1,int slot=0)
{
	int m_iEquipped = (itemid==-1?Store_GetEquippedItem(client, "trail", slot):itemid);
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		
		int m_aEquipped[STORE_MAX_SLOTS] = {-1,...};
		int m_iNumEquipped = 0;
		int m_iCurrent;
		for(int i=0;i<STORE_MAX_SLOTS;++i)
			if((m_aEquipped[m_iNumEquipped] = Store_GetEquippedItem(client, "trail", i))>=0)
			{
				if(i == g_eTrails[m_iData].iSlot)
					m_iCurrent = m_iNumEquipped;
				++m_iNumEquipped;
			}
		
		if(GAME_CSGO)
		{
			if(g_iClientTrails[client][slot] == 0 || !IsValidEdict(g_iClientTrails[client][slot]))
			{
				g_iClientTrails[client][slot] = CreateEntityByName("env_sprite");
				DispatchKeyValue(g_iClientTrails[client][slot], "classname", "env_sprite");
				DispatchKeyValue(g_iClientTrails[client][slot], "spawnflags", "1");
				DispatchKeyValue(g_iClientTrails[client][slot], "scale", "0.0");
				DispatchKeyValue(g_iClientTrails[client][slot], "rendermode", "10");
				DispatchKeyValue(g_iClientTrails[client][slot], "rendercolor", "255 255 255 0");
				DispatchKeyValue(g_iClientTrails[client][slot], "model", g_eTrails[m_iData].szMaterial);
				DispatchSpawn(g_iClientTrails[client][slot]);
				AttachTrail(g_iClientTrails[client][slot], client, m_iCurrent, m_iNumEquipped);	
				SDKHook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
			}
			
			//Ugh...
			int m_iColor[4];
			m_iColor[0] = g_eTrails[m_iData].iColor[0];
			m_iColor[1] = g_eTrails[m_iData].iColor[1];
			m_iColor[2] = g_eTrails[m_iData].iColor[2];
			m_iColor[3] = g_eTrails[m_iData].iColor[3];
			TE_SetupBeamFollow(g_iClientTrails[client][slot], view_as<int>(g_eTrails[m_iData].iCacheID)
								, 0, view_as<float>(g_eCvars[g_cvarTrailLife].aCache), 
								view_as<float>(g_eTrails[m_iData].fWidth), 
								view_as<float>(g_eTrails[m_iData].fWidth), 10, m_iColor);
			TE_SendToAll();
		}
		else
		{
			int m_iEnt = CreateEntityByName("env_spritetrail");
			SetEntPropFloat(m_iEnt, Prop_Send, "m_flTextureRes", 0.05);

			DispatchKeyValue(m_iEnt, "renderamt", "255");
			DispatchKeyValue(m_iEnt, "rendercolor", g_eTrails[m_iData].szColor);
			DispatchKeyValue(m_iEnt, "lifetime", g_eCvars[g_cvarTrailLife].sCache);
			DispatchKeyValue(m_iEnt, "rendermode", "5");
			DispatchKeyValue(m_iEnt, "spritename", g_eTrails[m_iData].szMaterial);
			DispatchKeyValue(m_iEnt, "startwidth", g_eTrails[m_iData].szWidth);
			DispatchKeyValue(m_iEnt, "endwidth", g_eTrails[m_iData].szWidth);
			DispatchSpawn(m_iEnt);
			
			AttachTrail(m_iEnt, client, m_iCurrent, m_iNumEquipped);
				
			g_iClientTrails[client][g_eTrails[m_iData].iSlot]=m_iEnt;
			SDKHook(m_iEnt, SDKHook_SetTransmit, Hook_TrailSetTransmit);	

			g_iTrailOwners[m_iEnt]=client;		
		}
	}
}

public int RemoveTrail(int client,int slot)
{
	if(g_iClientTrails[client][slot] != 0 && IsValidEdict(g_iClientTrails[client][slot]))
	{
		g_iTrailOwners[g_iClientTrails[client][slot]]=-1;

		char m_szClassname[64];
		GetEdictClassname(g_iClientTrails[client][slot], STRING(m_szClassname));
		if(strcmp("env_spritetrail", m_szClassname)==0)
		{
			SDKUnhook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
			AcceptEntityInput(g_iClientTrails[client][slot], "Kill");
		}
	}
	g_iClientTrails[client][slot]=0;
}

public void AttachTrail(int ent,int client,int current,int num)
{
	float m_fOrigin[3], m_fAngle[3];
	float m_fTemp[3] = {0.0, 90.0, 0.0};
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fTemp);
	float m_fX = (view_as<float>(g_eCvars[g_cvarPadding].aCache)*((num-1)%g_eCvars[g_cvarMaxColumns].aCache))/2-(view_as<float>(g_eCvars[g_cvarPadding].aCache)*(current%g_eCvars[g_cvarMaxColumns].aCache));
	float m_fPosition[3];
	m_fPosition[0] = m_fX;
	m_fPosition[1] = 0.0;
	m_fPosition[2]= 5.0+(current/g_eCvars[g_cvarMaxColumns].aCache)*view_as<float>(g_eCvars[g_cvarPadding].aCache);
	GetClientAbsOrigin(client, m_fOrigin);
	AddVectors(m_fOrigin, m_fPosition, m_fOrigin);
	TeleportEntity(ent, m_fOrigin, m_fTemp, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
}

public void OnGameFrame()
{
	if(!GAME_CSGO)
		return;

	if(GetGameTickCount()%6 != 0)
		return;	

	float m_fTime = GetEngineTime();
	float m_fPosition[3];
	LoopAlivePlayers(i)
	{
		GetClientAbsOrigin(i, m_fPosition);
		if(GetVectorDistance(g_fLastPosition[i], m_fPosition)<=5.0)
		{
			if(!g_bSpawnTrails[i])
				if(m_fTime-g_fClientCounters[i]>=view_as<float>(g_eCvars[g_cvarTrailLife].aCache)/2)
					g_bSpawnTrails[i] = true;
		}
		else
		{
			if(g_bSpawnTrails[i])
			{
				g_bSpawnTrails[i] = false;
				TE_Start("KillPlayerAttachments");
				TE_WriteNum("m_nPlayer",i);
				TE_SendToAll();
				for(int a=0;a<STORE_MAX_SLOTS;++a)
					CreateTrail(i, -1, a);
			}
			else
				g_fClientCounters[i] = m_fTime;
			g_fLastPosition[i] = m_fPosition;
		}
	}
}
/*
public Action Hook_TrailSetTransmit(int ent,int client)
{
	new Hide = ShouldHideTrail(client, ent);
	if(Hide)
	{
		if(Hide == 2)
			return Plugin_Handled;
		else if(Hide == 1)
		{
			for(new i=0;i<STORE_MAX_SLOTS;++i)
				if(g_iClientTrails[client][i]==ent)
					return Plugin_Continue;
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock int ShouldHideTrail(int client,int ent)
{
	if(GAME_TF2)
	{
		if(1<=g_iTrailOwners[ent]<=MaxClients)
		{
			if(TF2_IsPlayerInCondition(g_iTrailOwners[ent], TFCond_Cloaked))
			{
				return 2;
			}
		}
	}

	static Available = -1;
	if(Available==-1)
		Available = GetFeatureStatus(FeatureType_Native, "HideTrails_ShouldHide")==FeatureStatus_Available?1:0;

	if(Available == 1)
	{
		return HideTrails_ShouldHide(client);
	}
	return 0;
}
*/

public Action Hook_TrailSetTransmit(int ent, int client)
{
	Set_EdictFlags(ent);

	return g_bHide[client] ? Plugin_Handled : Plugin_Continue;
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "trail"))
		return;

	int iPreview = CreateEntityByName("env_sprite_oriented");

	DispatchKeyValue(iPreview, "model", g_eTrails[index].szMaterial);
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