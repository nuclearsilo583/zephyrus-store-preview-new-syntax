#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>

#include <store>
#include <zephstocks>
//#pragma newdecls required
new GAME_TF2 = false;
new GAME_CSGO = false;

enum struct PlayerSkin
{
	char szModel[PLATFORM_MAX_PATH];
	char szArms[PLATFORM_MAX_PATH];
	int iSkin;
	int iBody;
	//bool:bTemporary,
	int iTeam;
	int nModelIndex;
}

PlayerSkin g_ePlayerSkins[STORE_MAX_ITEMS];

int g_iPlayerSkins = 0;
//new g_iTempSkins[MAXPLAYERS+1];

//int g_cvarSkinChangeInstant = -1;
//new g_cvarSkinForceChange = -1;
//new g_cvarSkinForceChangeCT = -1;
//new g_cvarSkinForceChangeT = -1;
int g_cvarSkinDelay = -1;

//new bool:g_bTForcedSkin = false;
//new bool:g_bCTForcedSkin = false;

Handle g_hTimerPreview[MAXPLAYERS + 1];

char m_szGameDir[32];

int g_bSkinEnable;

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

char g_sChatPrefix[128];

public Plugin myinfo = 
{
	name = "Store - Player Skin Module (No ZR version)",
	author = "nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{	
	LoadTranslations("store.phrases");
	
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
	else if(strcmp(m_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	
	Store_RegisterHandler("playerskin", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, true);
	//Store_RegisterHandler("playerskin_temp", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, false);

	//g_cvarSkinChangeInstant = RegisterConVar("sm_store_playerskin_instant", "1", "Defines whether the skin should be changed instantly or on next spawn.", TYPE_INT);
	//g_cvarSkinForceChange = RegisterConVar("sm_store_playerskin_force_default", "0", "If it's set to 1, default skins will be enforced.", TYPE_INT);
	//g_cvarSkinForceChangeCT = RegisterConVar("sm_store_playerskin_default_ct", "", "Path of the default CT skin.", TYPE_STRING);
	//g_cvarSkinForceChangeT = RegisterConVar("sm_store_playerskin_default_t", "", "Path of the default T skin.", TYPE_STRING);
	g_cvarSkinDelay = RegisterConVar("sm_store_playerskin_delay", "2", "Delay after spawn before applying the skin. -1 means no delay", TYPE_FLOAT);
	g_bSkinEnable = RegisterConVar("sm_store_playerskin_enable", "1", "Enable the player skin module", TYPE_INT);
	//g_cvarSkinChangeInstant = RegisterConVar("sm_store_playerskin_instant", "1", "Defines whether the skin should be changed instantly or on next spawn.", TYPE_INT);
	
	
	HookEvent("player_spawn", PlayerSkins_PlayerSpawn);
	//HookEvent("player_death", PlayerSkins_PlayerDeath);

	//g_bZombieMode = (FindPluginByFile("zombiereloaded")==INVALID_HANDLE?false:true);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void PlayerSkins_OnMapStart()
{
	for(int i=0;i<g_iPlayerSkins;++i)
	{
		g_ePlayerSkins[i].nModelIndex = PrecacheModel2(g_ePlayerSkins[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szModel);

		if(g_ePlayerSkins[i].szArms[0]!=0)
		{
			PrecacheModel2(g_ePlayerSkins[i].szArms, true);
			Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szArms);
		}
	}
}

public int PlayerSkins_Reset()
{
	g_iPlayerSkins = 0;
}

public bool PlayerSkins_Config(Handle &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iPlayerSkins);
	
	KvGetString(kv, "model", g_ePlayerSkins[g_iPlayerSkins].szModel, PLATFORM_MAX_PATH);
	KvGetString(kv, "arms", g_ePlayerSkins[g_iPlayerSkins].szArms, PLATFORM_MAX_PATH);
	g_ePlayerSkins[g_iPlayerSkins].iSkin = KvGetNum(kv, "skin");
	g_ePlayerSkins[g_iPlayerSkins].iBody = KvGetNum(kv, "body", -1);
	g_ePlayerSkins[g_iPlayerSkins].iTeam = KvGetNum(kv, "team");
	//g_ePlayerSkins[g_iPlayerSkins][bTemporary] = (KvGetNum(kv, "temporary")?true:false);
	
	if(FileExists(g_ePlayerSkins[g_iPlayerSkins].szModel, true))
	{
		++g_iPlayerSkins;
		return true;
	}
	
	return false;
}

public int PlayerSkins_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	//int iIndex =  Store_GetDataIndex(id);
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if(IsPlayerAlive(client) && IsValidClient(client, true) && GetClientTeam(client)==g_ePlayerSkins[m_iData].iTeam)
		{
			Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
		}
		/*else
		{
			if(Store_IsClientLoaded(client))
				CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");

			if(g_ePlayerSkins[m_iData][bTemporary])
			{
				g_iTempSkins[client] = m_iData;
				return -1;
			}
		}*/
		
		else if(Store_IsClientLoaded(client))
			CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
	
	return (g_ePlayerSkins[Store_GetDataIndex(id)].iTeam)-2;
}

public int PlayerSkins_Remove(int client,int id)
{
	/*if(Store_IsClientLoaded(client) && !g_eCvars[g_cvarSkinChangeInstant].aCache)
		CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");*/
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
	
		if (Store_IsClientLoaded(client) && IsValidClient(client, true) && IsPlayerAlive(client) && IsClientInGame(client))
		{
			CS_UpdateClientModel(client);
		}
		else CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
	
	return view_as<int>(g_ePlayerSkins[Store_GetDataIndex(id)].iTeam)-2;
}

public Action PlayerSkins_PlayerSpawn(Event event,const char[] name,bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
			return Plugin_Continue;
		
		float Delay = view_as<float>(g_eCvars[g_cvarSkinDelay].aCache);
		
		CreateTimer(Delay, PlayerSkins_PlayerSpawnPost, GetClientUserId(client));
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
	
	return Plugin_Continue;
}
/*
public Action:PlayerSkins_PlayerSpawnPost(Handle:timer, any:userid)
{
	int client = GetClientOfUserId(userid);
	//int iIndex =  Store_GetDataIndex(id);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (IsValidClient(client, true) && !IsPlayerAlive(client))
		return Plugin_Stop;
	
	new m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
	if(m_iEquipped < 0)
		return Plugin_Stop;
	
	decl m_iData;
	m_iData = Store_GetDataIndex(m_iEquipped);
	Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);

	else if(g_eCvars[g_cvarSkinForceChange].aCache)
	{
		new m_iTeam = GetClientTeam(client);
		if(m_iTeam == 2 && g_bTForcedSkin)
			Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeT][sCache], m_iData);
		else if(m_iTeam == 3 && g_bCTForcedSkin)
			Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeCT][sCache], m_iData);
	}
	return Plugin_Stop;
}*/

public Action PlayerSkins_PlayerSpawnPost(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	//int iIndex =  Store_GetDataIndex(id);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (IsValidClient(client, true) && !IsPlayerAlive(client))
		return Plugin_Stop;
		
	int m_iEquipped = Store_GetEquippedItem(client, "playerskin", 2);
	if(m_iEquipped < 0)
		m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
	}
	/*else if(g_eCvars[g_cvarSkinForceChange].aCache)
	{
		new m_iTeam = GetClientTeam(client);
		if(m_iTeam == 2 && g_bTForcedSkin)
			Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeT][sCache], m_iData);
		else if(m_iTeam == 3 && g_bCTForcedSkin)
			Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeCT][sCache], m_iData);
	}*/
	return Plugin_Stop;
}

void Store_SetClientModel(int client, const char[] model, const int skin=0, const int body=0, const char[] arms="", int index)
{

	SetEntityModel(client, model);
	//SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
	if (arms[0] == 0)
		return;

	SetEntProp(client, Prop_Send, "m_nSkin", skin);
	
	if (body > 0)
    {
        // set?
		SetEntProp(client, Prop_Send, "m_nBody", body);
    }
	
	//CreateTimer(0.15, Timer_RemovePlayerWeapon, GetClientUserId(client));
	RemoveClientGloves(client, index);
	if(GAME_CSGO & arms[0]!=0)
	{
		SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
	}
}

public Action Timer_RemovePlayerWeapon(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!client || !IsClientConnected(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if (iWeapon == -1)
		return Plugin_Stop;

	RemovePlayerItem(client, iWeapon);
	DataPack pack = new DataPack();
	pack.WriteCell(iWeapon);
	pack.WriteCell(GetClientUserId(client));
	CreateTimer(0.15, Timer_GivePlayerWeapon, pack);

	return Plugin_Stop;
}

public Action Timer_GivePlayerWeapon(Handle timer, DataPack pack)
{
	pack.Reset();
	int iWeapon = pack.ReadCell();
	int client = GetClientOfUserId(pack.ReadCell());
	if (0 < client <= MAXPLAYERS && IsClientConnected(client) && IsPlayerAlive(client))
	{
		EquipPlayerWeapon(client, iWeapon);
	}
	delete pack;

	return Plugin_Stop;
}


void RemoveClientGloves(int client, int index = -1)
{
	if (index == -1 && GetEquippedSkin(client) <= 0)
		return;
	
	if(!IsClientInGame(client) && GetEquippedSkin(client) <= 0)
		return;
	int gloves = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
	if (gloves != -1)
	{
		AcceptEntityInput(gloves, "KillHierarchy");
	}
}

int GetEquippedSkin(int client)
{
	return Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
}

/*
public Action:PlayerSkins_PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iTempSkins[client] = -1;
	return Plugin_Continue;
}*/

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "playerskin"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer
	
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_ePlayerSkins[index].szModel);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	//SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	//SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
	SetEntProp(iPreview, Prop_Send, "m_nSkin", g_ePlayerSkins[index].iSkin);
	if (g_ePlayerSkins[index].iBody > 0)
	{
		SetEntProp(iPreview, Prop_Send, "m_nBody", g_ePlayerSkins[index].iBody);
	}
	//SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);


	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fAngles[0] *= -1.0;
	fAngles[1] *= -1.0;

	fPosition[2] += 5;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

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

stock bool IsValidClient(int client, bool nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    {
        return false; 
    }
    return IsClientInGame(client); 
}