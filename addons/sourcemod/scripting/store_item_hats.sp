#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <store>
#include <zephstocks>

#include <sdkhooks>
#include <thirdperson>
#include <colors>


#pragma newdecls required

enum struct Hat
{
	char szModel[PLATFORM_MAX_PATH];
	char szAttachment[64];
	float fPosition[3];
	float fAngles[3];
	bool bBonemerge;
	int iTeam;
	int iSlot;
}

char g_szGameDir[64];

bool GAME_CSGO = false;

Handle g_hLookupAttachment = INVALID_HANDLE;

Hat g_eHats[STORE_MAX_ITEMS];

int g_iClientHats[MAXPLAYERS+1][STORE_MAX_SLOTS];
int g_iHats = 0;

int g_cvarDefaultT = -1;
int g_cvarDefaultCT = -1;
int g_cvarOverrideEnabled = -1;

bool g_bTOverride = false;
bool g_bCTOverride = false;

Handle g_hTimerPreview[MAXPLAYERS + 1];

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

char g_sChatPrefix[128];

public Plugin myinfo = 
{
	name = "Store - Hats Module",
	author = "nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{
	Handle m_hGameConf = LoadGameConfigFile("store.gamedata");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(m_hGameConf, SDKConf_Signature, "LookupAttachment");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hLookupAttachment = EndPrepSDKCall();
	CloseHandle(m_hGameConf);
	
	LoadTranslations("store.phrases");
		
	Store_RegisterHandler("hat", "model", Hats_OnMapStart, Hats_Reset, Hats_Config, Hats_Equip, Hats_Remove, true);
		
	g_cvarDefaultT = RegisterConVar("sm_store_hats_default_t", "models/player/t_leet.mdl", "Terrorist model that supports hats", TYPE_STRING);
	g_cvarDefaultCT = RegisterConVar("sm_store_hats_default_ct", "models/player/ct_urban.mdl", "Counter-Terrorist model that supports hats", TYPE_STRING);
	g_cvarOverrideEnabled = RegisterConVar("sm_store_hats_skin_override", "0", "Allow the store to override player model if it doesn't support hats", TYPE_INT);
	
	HookEvent("player_spawn", Hats_PlayerSpawn);
	HookEvent("player_death", Hats_PlayerRemoveEvent);
	HookEvent("player_team", Hats_PlayerRemoveEvent);
	
	GetGameFolderName(STRING(g_szGameDir));
	if(strcmp(g_szGameDir, "csgo")==0)
		GAME_CSGO = true;
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Hats_OnMapStart()
{
	for(int a=0;a<=MaxClients;++a)
		for(int  b=0;b<STORE_MAX_SLOTS;++b)
			g_iClientHats[a][b]=0;

	for(int i=0;i<g_iHats;++i)
	{
		PrecacheModel2(g_eHats[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_eHats[i].szModel);
	}
		
	// Just in case...
	if(FileExists(g_eCvars[g_cvarDefaultT].sCache, true))
	{
		g_bTOverride = true;
		PrecacheModel2(g_eCvars[g_cvarDefaultT].sCache, true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarDefaultT].sCache);
	}
	else
		g_bTOverride = false;
		
	if(FileExists(g_eCvars[g_cvarDefaultCT].sCache, true))
	{
		g_bCTOverride = true;
		PrecacheModel2(g_eCvars[g_cvarDefaultCT].sCache, true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarDefaultCT].sCache);
	}
	else
		g_bCTOverride = false;
}

public void Hats_Reset()
{
	g_iHats = 0;
}

public bool Hats_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iHats);
	float m_fTemp[3];
	KvGetString(kv, "model", g_eHats[g_iHats].szModel, PLATFORM_MAX_PATH);
	KvGetVector(kv, "position", m_fTemp);
	g_eHats[g_iHats].fPosition = m_fTemp;
	KvGetVector(kv, "angles", m_fTemp);
	g_eHats[g_iHats].fAngles = m_fTemp;
	g_eHats[g_iHats].bBonemerge = (KvGetNum(kv, "bonemerge", 0)?true:false);
	g_eHats[g_iHats].iTeam = KvGetNum(kv, "team", 0);
	g_eHats[g_iHats].iSlot = KvGetNum(kv, "slot");
	KvGetString(kv, "attachment", g_eHats[g_iHats].szAttachment, 64, "");
	
	if(strcmp(g_eHats[g_iHats].szAttachment, "")==0)
	{
		if(GAME_CSGO)
		{
			strcopy(g_eHats[g_iHats].szAttachment, 64, "facemask");
			g_eHats[g_iHats].fPosition[2] -= 4.0;
		}
		else
			strcopy(g_eHats[g_iHats].szAttachment, 64, "forward");
	}

	
	if(!(FileExists(g_eHats[g_iHats].szModel, true)))
		return false;
		
	++g_iHats;
	return true;
}

public int Hats_Equip(int client,int id)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return -1;
	int m_iData = Store_GetDataIndex(id);
	RemoveHat(client, g_eHats[m_iData].iSlot);
	CreateHat(client, id);
	return g_eHats[m_iData].iSlot;
}

public int Hats_Remove(int client,int id)
{
	int m_iData = Store_GetDataIndex(id);
	RemoveHat(client, g_eHats[m_iData].iSlot);
	return g_eHats[m_iData].iSlot;
}

public Action Hats_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
		
	// Support for plugins that set client model
	CreateTimer(0.1, Hats_PlayerSpawn_Post, GetClientUserId(client));
		
	return Plugin_Continue;
}

public Action Hats_PlayerSpawn_Post(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Stop;

	for(int i=0;i<STORE_MAX_SLOTS;++i)
	{
		RemoveHat(client, i);
		CreateHat(client, -1, i);
	}
	return Plugin_Stop;
}

public Action Hats_PlayerRemoveEvent(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	for(int i=0;i<STORE_MAX_SLOTS;++i)
		RemoveHat(client, i);
	return Plugin_Continue;
}

void CreateHat(int client,int itemid=-1,int slot=0)
{
	int m_iEquipped = (itemid==-1?Store_GetEquippedItem(client, "hat", slot):itemid);
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		int m_iTeam = GetClientTeam(client);
		
		if(g_eHats[m_iData].iTeam != 0 && m_iTeam!=g_eHats[m_iData].iTeam)
			return;
		
		// If the model doesn't support hats, set the model to one that does
		if(!LookupAttachment(client, g_eHats[m_iData].szAttachment))
		{
			if(g_eCvars[g_cvarOverrideEnabled].aCache)
			{
				if(m_iTeam==2 && g_bTOverride)
					SetEntityModel(client, g_eCvars[g_cvarDefaultT].sCache);
				else if(m_iTeam==3 && g_bCTOverride)
					SetEntityModel(client, g_eCvars[g_cvarDefaultCT].sCache);
				else
					return;
			}
			else
				return;
		}
		
		// Calculate the final position and angles for the hat
		float m_fHatOrigin[3];
		float m_fHatAngles[3];
		float m_fForward[3];
		float m_fRight[3];
		float m_fUp[3];
		GetClientAbsOrigin(client,m_fHatOrigin);
		GetClientAbsAngles(client,m_fHatAngles);
		
		m_fHatAngles[0] += g_eHats[m_iData].fAngles[0];
		m_fHatAngles[1] += g_eHats[m_iData].fAngles[1];
		m_fHatAngles[2] += g_eHats[m_iData].fAngles[2];

		float m_fOffset[3];
		m_fOffset[0] = g_eHats[m_iData].fPosition[0];
		m_fOffset[1] = g_eHats[m_iData].fPosition[1];
		m_fOffset[2] = g_eHats[m_iData].fPosition[2];

		GetAngleVectors(m_fHatAngles, m_fForward, m_fRight, m_fUp);

		m_fHatOrigin[0] += m_fRight[0]*m_fOffset[0]+m_fForward[0]*m_fOffset[1]+m_fUp[0]*m_fOffset[2];
		m_fHatOrigin[1] += m_fRight[1]*m_fOffset[0]+m_fForward[1]*m_fOffset[1]+m_fUp[1]*m_fOffset[2];
		m_fHatOrigin[2] += m_fRight[2]*m_fOffset[0]+m_fForward[2]*m_fOffset[1]+m_fUp[2]*m_fOffset[2];
		
		// Create the hat entity
		int m_iEnt = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(m_iEnt, "model", g_eHats[m_iData].szModel);
		DispatchKeyValue(m_iEnt, "spawnflags", "256");
		DispatchKeyValue(m_iEnt, "solid", "0");
		SetEntPropEnt(m_iEnt, Prop_Send, "m_hOwnerEntity", client);
		
		if(g_eHats[m_iData].bBonemerge)
			Bonemerge(m_iEnt);
		
		DispatchSpawn(m_iEnt);	
		AcceptEntityInput(m_iEnt, "TurnOn", m_iEnt, m_iEnt, 0);
		
		// Save the entity index
		g_iClientHats[client][g_eHats[m_iData].iSlot]=m_iEnt;
		
		// We don't want the client to see his own hat
		SDKHook(m_iEnt, SDKHook_SetTransmit, Hook_SetTransmit);
		
		// Teleport the hat to the right position and attach it
		TeleportEntity(m_iEnt, m_fHatOrigin, m_fHatAngles, NULL_VECTOR); 
		
		SetVariantString("!activator");
		AcceptEntityInput(m_iEnt, "SetParent", client, m_iEnt, 0);
		
		SetVariantString(g_eHats[m_iData].szAttachment);
		AcceptEntityInput(m_iEnt, "SetParentAttachmentMaintainOffset", m_iEnt, m_iEnt, 0);
	}
}

public void RemoveHat(int client,int slot)
{
	if(g_iClientHats[client][slot] != 0 && IsValidEdict(g_iClientHats[client][slot]))
	{
		SDKUnhook(g_iClientHats[client][slot], SDKHook_SetTransmit, Hook_SetTransmit);
		char m_szClassname[64];
		GetEdictClassname(g_iClientHats[client][slot], STRING(m_szClassname));
		if(strcmp("prop_dynamic", m_szClassname)==0)
			AcceptEntityInput(g_iClientHats[client][slot], "Kill");
	}
	g_iClientHats[client][slot]=0;

}

public Action Hook_SetTransmit(int ent,int client)
{
	if(GetFeatureStatus(FeatureType_Native, "IsPlayerInTP")==FeatureStatus_Available)
		if(IsPlayerInTP(client))
			return Plugin_Continue;

	for(int i=0;i<STORE_MAX_SLOTS;++i)
		if(ent == g_iClientHats[client][i])
			return Plugin_Handled;

	if(client && IsClientInGame(client))
	{
		any m_iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		any m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if(m_iObserverMode == 4 && m_hObserverTarget>=0)
		{
			for(int i=0;i<STORE_MAX_SLOTS;++i)
				if(ent == g_iClientHats[m_hObserverTarget][i])
					return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public any LookupAttachment(int client, char[] point)
{
	if(GAME_CSGO)
		return true;
	if(g_hLookupAttachment==INVALID_HANDLE)
		return false;
	if(!client || !IsClientInGame(client))
		return false;
	return SDKCall(g_hLookupAttachment, client, point);
}

public void Bonemerge(int ent)
{
	int m_iEntEffects = GetEntProp(ent, Prop_Send, "m_fEffects"); 
	m_iEntEffects &= ~32;
	m_iEntEffects |= 1;
	m_iEntEffects |= 128;
	SetEntProp(ent, Prop_Send, "m_fEffects", m_iEntEffects); 
}

public void Store_OnClientModelChanged(int client, char[] model)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	if(strcmp(model, g_eCvars[g_cvarDefaultT].sCache)==0 || strcmp(model, g_eCvars[g_cvarDefaultCT].sCache)==0)
		return;

	if(!LookupAttachment(client, "forward"))
	{
		bool m_bHasHats = false;
		for(int i=0;i<STORE_MAX_SLOTS;++i)
		{
			if(Store_GetEquippedItem(client, "hat", i)!=-1)
			{
				m_bHasHats = true;
				RemoveHat(client, i);
				CreateHat(client, -1, i);
			}
		}
		
		if(m_bHasHats)
			if(g_eCvars[g_cvarOverrideEnabled].aCache)
				Chat(client, "%t", "Override Enabled");
			else
				Chat(client, "%t", "Override Disabled");
	}
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "hat"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override
	
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_eHats[index].szModel);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
	//SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	//SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
	//SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);

	//Miku Green
	SetEntData(iPreview, offset, 57, _, true);
	SetEntData(iPreview, offset + 1, 197, _, true);
	SetEntData(iPreview, offset + 2, 187, _, true);
	SetEntData(iPreview, offset + 3, 155, _, true);

	float fOri[3];
	float fAng[3];
	float fRad[2];
	float fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 55;

	TeleportEntity(iPreview, fPos, fAng, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPos);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

	CPrintToChat(client, " %s%t", g_sChatPrefix, "Spawn Preview", client);
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