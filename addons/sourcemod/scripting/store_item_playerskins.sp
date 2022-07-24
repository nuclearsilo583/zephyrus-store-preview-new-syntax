#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <cstrike>
#include <store>
#include <zephstocks>

//#include <gloves>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

//new GAME_TF2 = false;
native bool ZR_IsClientZombie(int client);
bool g_bZombieMode = false;

native void Gloves_SetArmsModel(int client, const char[] armsModel);
native void Gloves_RegisterCustomArms(int client, const char[] armsModel);
bool g_bGlovesPluginEnable = false;

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

enum struct PlayerArms
{
	char szModel[PLATFORM_MAX_PATH];
	//int iSkin;
	//int iBody;
	int iTeam;
}

PlayerSkin g_ePlayerSkins[STORE_MAX_ITEMS];
PlayerArms g_ePlayerArms[STORE_MAX_ITEMS];

int g_iPlayerSkins = 0;
int g_iPlayerArms = 0;
//int g_iTempSkins[MAXPLAYERS+1];

int g_cvarSkinChangeInstant = -1;
int g_cvarSkinForceChange = -1;
int g_cvarSkinForceChangeCT = -1;
int g_cvarSkinForceChangeCTArms = -1;
int g_cvarSkinForceChangeT = -1;
int g_cvarSkinForceChangeTArms = -1;
int g_cvarSkinDelay = -1;

bool g_bTForcedSkin = false;
bool g_bCTForcedSkin = false;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_bSkinEnable;
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
char g_sChatPrefix[128];
bool GAME_CSGO = false;

bool g_bHide[MAXPLAYERS + 1];
Cookie g_hHideCookie;

public Plugin myinfo = 
{
	name = "Store - Player Skin Module (No ZR + ZR, gloves support)",
	author = "nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "2.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{	
	LoadTranslations("store.phrases");
	
	char g_szGameDir[64];
	GetGameFolderName(STRING(g_szGameDir));
	
	if(strcmp(g_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	
	Store_RegisterHandler("playerskin", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, true);
	Store_RegisterHandler("arms", "model", Arms_OnMapStart, Arms_Reset, Arms_Config, Arms_Equip, Arms_Remove, true);
	
	RegConsoleCmd("sm_hidegloves", Command_Hide, "Hides the Gloves");
	
	g_cvarSkinForceChange = RegisterConVar("sm_store_playerskin_force_default", "0", "If it's set to 1, default skins will be enforced.", TYPE_INT);
	
	g_cvarSkinForceChangeCT = RegisterConVar("sm_store_playerskin_default_ct", "models/player/custom_player/legacy/ctm_sas_variant_classic.mdl", "Path of the default CT skin.", TYPE_STRING);
	g_cvarSkinForceChangeCTArms = RegisterConVar("sm_store_playerskin_default_ct_arms", "models/weapons/ct_arms_sas.mdl", "Path of the default CT skin.", TYPE_STRING);
	
	g_cvarSkinForceChangeT = RegisterConVar("sm_store_playerskin_default_t", "models/player/custom_player/legacy/tm_leet_variant_classic.mdl", "Path of the default T skin.", TYPE_STRING);
	g_cvarSkinForceChangeTArms = RegisterConVar("sm_store_playerskin_default_t_arms", "models/weapons/t_arms_leet.mdl", "Path of the default T skin.", TYPE_STRING);
	
	g_cvarSkinDelay = RegisterConVar("sm_store_playerskin_delay", "2", "Delay after spawn before applying the skin. -1 means no delay", TYPE_FLOAT);
	g_bSkinEnable = RegisterConVar("sm_store_playerskin_enable", "1", "Enable the player skin module", TYPE_INT);
	
	g_cvarSkinChangeInstant = RegisterConVar("sm_store_playerskin_instant", "1", "Defines whether the skin should be changed instantly or on next spawn.", TYPE_INT);
	
	g_hHideCookie = new Cookie("PlayerSkin_Hide_Gloves_Cookie", "Cookie to check if Gloves are blocked", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "");
	
	HookEvent("player_spawn", PlayerSkins_PlayerSpawn);
	//HookEvent("player_death", PlayerSkins_PlayerDeath);

	if(FindPluginByFile("zombiereloaded.smx")==INVALID_HANDLE)
	{
		g_bZombieMode = false;
		PrintToServer("No Zombie:Reloaded plugin detected");
	}
	else
	{
		g_bZombieMode = true;
		PrintToServer("Zombie:Reloaded plugin detected");
	}
	
	if(FindPluginByFile("gloves.smx")==INVALID_HANDLE)
	{
		g_bGlovesPluginEnable = false;
		PrintToServer("No gloves plugin detected");
	}
	else 
	{
		g_bGlovesPluginEnable = true;
		PrintToServer("Gloves plugin detected");
	}
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		if (g_bHide[client])
			FormatEx(buffer, maxlen, "%T", "Show gloves", client);
		else
			FormatEx(buffer, maxlen, "%T", "Hide gloves", client);
	}

	if (actions == CookieMenuAction_SelectOption)
	{
		Command_Hide(client, 0);
		ShowCookieMenu(client);
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[4];
	g_hHideCookie.Get(client, sValue, sizeof(sValue));

	if (sValue[0] == '\0' || sValue[0] == '0')
		g_bHide[client] = false;
	else
		g_bHide[client] = true;
}

Action Command_Hide(int client, int args)
{
	g_bHide[client] = !g_bHide[client];
	if (g_bHide[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "gloves");
		g_hHideCookie.Set(client, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "gloves");
		g_hHideCookie.Set(client, "0");
	}

	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("ZR_IsClientZombie");
	MarkNativeAsOptional("Gloves_SetArmsModel");
	MarkNativeAsOptional("Gloves_RegisterCustomArms");
	return APLRes_Success;
} 

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "zombiereloaded")==0)
		g_bZombieMode = true;
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void PlayerSkins_OnMapStart()
{
	for(int i=0;i<g_iPlayerSkins;++i)
	{
		g_ePlayerSkins[i].nModelIndex = PrecacheModel(g_ePlayerSkins[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szModel);

		if(g_ePlayerSkins[i].szArms[0]!=0)
		{
			PrecacheModel(g_ePlayerSkins[i].szArms, true);
			Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szArms);
		}
	}
	
	if(g_eCvars[g_cvarSkinForceChangeT].sCache[0] != 0 && g_eCvars[g_cvarSkinForceChangeTArms].sCache[0] != 0 && 
		(FileExists(g_eCvars[g_cvarSkinForceChangeT].sCache) || FileExists(g_eCvars[g_cvarSkinForceChangeT].sCache, true)) &&
		(FileExists(g_eCvars[g_cvarSkinForceChangeTArms].sCache) || FileExists(g_eCvars[g_cvarSkinForceChangeTArms].sCache, true)))
	{
		g_bTForcedSkin = true;
		PrecacheModel(g_eCvars[g_cvarSkinForceChangeT].sCache, true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarSkinForceChangeT].sCache);
		
		PrecacheModel(g_eCvars[g_cvarSkinForceChangeTArms].sCache, true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarSkinForceChangeTArms].sCache);
	}
	else
		g_bTForcedSkin = false;
		
	if(g_eCvars[g_cvarSkinForceChangeCT].sCache[0] != 0 && g_eCvars[g_cvarSkinForceChangeCTArms].sCache[0] != 0 &&
			(FileExists(g_eCvars[g_cvarSkinForceChangeCT].sCache) || FileExists(g_eCvars[g_cvarSkinForceChangeCT].sCache, true)) &&
			(FileExists(g_eCvars[g_cvarSkinForceChangeCT].sCache) || FileExists(g_eCvars[g_cvarSkinForceChangeCT].sCache, true)))
	{
		g_bCTForcedSkin = true;
		PrecacheModel(g_eCvars[g_cvarSkinForceChangeCT].sCache, true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarSkinForceChangeCT].sCache);
		
		PrecacheModel(g_eCvars[g_cvarSkinForceChangeCTArms].sCache, true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarSkinForceChangeCTArms].sCache);
	}
	else
		g_bCTForcedSkin = false;
}

public void PlayerSkins_Reset()
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
		// NON-ZR MODE
		if(!g_bZombieMode)
		{
			if (g_eCvars[g_cvarSkinChangeInstant].aCache && g_ePlayerSkins[m_iData].iTeam == 4)
			{
				Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
			}
			else if(IsPlayerAlive(client) && IsValidClient(client, true) && GetClientTeam(client)==g_ePlayerSkins[m_iData].iTeam && g_eCvars[g_cvarSkinChangeInstant].aCache)
			{
				Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
			}
			else if(Store_IsClientLoaded(client))
				CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
		}
		else // ZR MODE
		{
			if(IsPlayerAlive(client) && IsValidClient(client, true) && !ZR_IsClientZombie(client) && g_eCvars[g_cvarSkinChangeInstant].aCache) //&& GetClientTeam(client)==g_ePlayerSkins[m_iData][iTeam])
			{
				Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
			}
			else if(Store_IsClientLoaded(client))
				CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
		}
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
	
	return (g_ePlayerSkins[Store_GetDataIndex(id)].iTeam)-2;
}

public int PlayerSkins_Remove(int client,int id)
{
	int m_iData = Store_GetDataIndex(id);
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if (Store_IsClientLoaded(client) && IsValidClient(client, true) && IsPlayerAlive(client) && IsClientInGame(client) && g_eCvars[g_cvarSkinChangeInstant].aCache && (g_ePlayerSkins[m_iData].iTeam == 4 || GetClientTeam(client)==g_ePlayerSkins[m_iData].iTeam))
		{
			// ZR MODE
			if(g_bZombieMode)
			{
				if (!ZR_IsClientZombie(client))
					CS_UpdateClientModel(client);
			}
			else CS_UpdateClientModel(client); // NON ZR MODE
		}
		else CPrintToChat(client, " %s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
	
	return view_as<int>(g_ePlayerSkins[Store_GetDataIndex(id)].iTeam)-2;
}

public void Arms_OnMapStart()
{
	for(int i=0;i<g_iPlayerArms;++i)
	{
		PrecacheModel(g_ePlayerArms[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_ePlayerArms[i].szModel);
	}
}

public void Arms_Reset()
{
	g_iPlayerArms = 0;
}

public bool Arms_Config(Handle &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iPlayerArms);
	
	KvGetString(kv, "model", g_ePlayerArms[g_iPlayerArms].szModel, PLATFORM_MAX_PATH);
	g_ePlayerArms[g_iPlayerArms].iTeam = KvGetNum(kv, "team");
	
	if(FileExists(g_ePlayerArms[g_iPlayerArms].szModel, true))
	{
		++g_iPlayerArms;
		return true;
	}
	
	return false;
}

public int Arms_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);

	if (g_ePlayerArms[m_iData].iTeam == 4)
	{
		Store_SetClientArmsModel(client, g_ePlayerArms[m_iData].szModel, m_iData);
		CPrintToChat(client, " arms team 4");
	}
	else if(IsPlayerAlive(client) && IsValidClient(client, true) && GetClientTeam(client)==g_ePlayerArms[m_iData].iTeam)
	{
		Store_SetClientArmsModel(client, g_ePlayerArms[m_iData].szModel, m_iData);
		CPrintToChat(client, " arms team 2,3");
	}
	else if(Store_IsClientLoaded(client))
		CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
		
	return (g_ePlayerArms[Store_GetDataIndex(id)].iTeam)-2;
}

public int Arms_Remove(int client,int id)
{
	return view_as<int>(g_ePlayerArms[Store_GetDataIndex(id)].iTeam)-2;
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
		CreateTimer(Delay+1, Arms_PlayerSpawnPost, GetClientUserId(client)); // Settings Arms if Player Skin is equipped
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
	
	return Plugin_Continue;
}

public Action Arms_PlayerSpawnPost(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (IsValidClient(client, true) && !IsPlayerAlive(client))
		return Plugin_Stop;
		
	int m_iEquipped = Store_GetEquippedItem(client, "arms", 2);
	if(m_iEquipped < 0)
		m_iEquipped = Store_GetEquippedItem(client, "arms", GetClientTeam(client)-2);
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		Store_SetClientArmsModel(client, g_ePlayerArms[m_iData].szModel, m_iData);
	}
	
	return Plugin_Stop;
}

public Action PlayerSkins_PlayerSpawnPost(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (IsValidClient(client, true) && !IsPlayerAlive(client))
		return Plugin_Stop;
	
	// NON ZR MODE
	if(!g_bZombieMode)
	{
		int m_iEquipped = Store_GetEquippedItem(client, "playerskin", 2);
		if(m_iEquipped < 0)
			m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
		if(m_iEquipped >= 0)
		{
			int m_iData = Store_GetDataIndex(m_iEquipped);
			Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
		}
		else if(g_eCvars[g_cvarSkinForceChange].aCache)
		{
			int m_iTeam = GetClientTeam(client);
			if(m_iTeam == 2 && g_bTForcedSkin)
				Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeT].sCache, _, _, g_eCvars[g_cvarSkinForceChangeTArms].sCache, -1);
			else if(m_iTeam == 3 && g_bCTForcedSkin)
				Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeCT].sCache, _, _, g_eCvars[g_cvarSkinForceChangeCTArms].sCache, -1);
		}
	}
	else // ZR MODE
	{
		if(IsPlayerAlive(client))
		if (ZR_IsClientZombie(client))
			return Plugin_Stop;
	
		int m_iEquipped = Store_GetEquippedItem(client, "playerskin", 2);
		if(m_iEquipped < 0)
			m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
		if(m_iEquipped >= 0)
		{
			int m_iData = Store_GetDataIndex(m_iEquipped);
			Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody, g_ePlayerSkins[m_iData].szArms, m_iData);
		}
	}
	return Plugin_Stop;
}

void Store_SetClientArmsModel(int client, const char[] model, int index)
{
	if(index){}
	SetEntPropString(client, Prop_Send, "m_szArmsModel", model);
}

void Store_SetClientModel(int client, const char[] model, const int skin=0, const int body=0, const char[] arms="", int index)
{

	SetEntityModel(client, model);

	SetEntProp(client, Prop_Send, "m_nSkin", skin);
	
	if (body > 0)
    {
        // set?
		SetEntProp(client, Prop_Send, "m_nBody", body);
    }
	
	//CreateTimer(0.15, Timer_RemovePlayerWeapon, GetClientUserId(client));
	
	if(GAME_CSGO && arms[0]!=0)
	{
		if(!g_bGlovesPluginEnable)
		{
			SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
		}
		else 
		{
			Gloves_RegisterCustomArms(client, arms);
			Gloves_SetArmsModel(client, arms);
		}
		
		if(g_bHide[client])
		{
			RemoveClientGloves(client, index);
			SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
		}
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

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	//if (!StrEqual(type, "playerskin"))
	//	return;
		
	if(g_hTimerPreview[client] != null) 
		TriggerTimer(g_hTimerPreview[client], false);

	if (StrEqual(type, "playerskin") || StrEqual(type, "arms"))
	{
		int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer
		
		if (g_hTimerPreview[client] != null) 
		{
			delete g_hTimerPreview[client];
			g_hTimerPreview[client] = null;
		} 

		DispatchKeyValue(iPreview, "spawnflags", "64");
		if(StrEqual(type, "playerskin"))
			DispatchKeyValue(iPreview, "model", g_ePlayerSkins[index].szModel);
		else if(StrEqual(type, "arms"))
			DispatchKeyValue(iPreview, "model", g_ePlayerArms[index].szModel);
			
		DispatchSpawn(iPreview);

		SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

		AcceptEntityInput(iPreview, "Enable");

		SetEntProp(iPreview, Prop_Send, "m_nSkin", g_ePlayerSkins[index].iSkin);
		if (g_ePlayerSkins[index].iBody > 0)
		{
			SetEntProp(iPreview, Prop_Send, "m_nBody", g_ePlayerSkins[index].iBody);
		}
		
		//Only CSGO support for GLOWING preview model
		if(GAME_CSGO)
		{
			int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
			SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
			SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
			SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);

			// Miku green
			SetEntData(iPreview, offset, 57, _, true);
			SetEntData(iPreview, offset + 1, 197, _, true);
			SetEntData(iPreview, offset + 2, 187, _, true);
			SetEntData(iPreview, offset + 3, 155, _, true);
		}

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

		if(StrEqual(type, "playerskin"))
			fPosition[2] += 5;
		else if(StrEqual(type, "arms"))
			fPosition[2] += 45;

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