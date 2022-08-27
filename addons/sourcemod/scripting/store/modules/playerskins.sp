#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new GAME_TF2 = false;
#endif

native bool:ZR_IsClientZombie(client);
//new bool:g_bZombieMode = false;

enum PlayerSkin
{
	String:szModel[PLATFORM_MAX_PATH],
	String:szArms[PLATFORM_MAX_PATH],
	iSkin,
	bool:bTemporary,
	iTeam,
	nModelIndex
}

new g_ePlayerSkins[STORE_MAX_ITEMS][PlayerSkin];

new g_iPlayerSkins = 0;
new g_iTempSkins[MAXPLAYERS+1];

new g_cvarSkinChangeInstant = -1;
new g_cvarSkinForceChange = -1;
new g_cvarSkinForceChangeCT = -1;
new g_cvarSkinForceChangeT = -1;
new g_cvarSkinDelay = -1;

new bool:g_bTForcedSkin = false;
new bool:g_bCTForcedSkin = false;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public PlayerSkins_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
		
	LoadTranslations("store.phrases");
#endif
	
	Store_RegisterHandler("playerskin", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, true);
	Store_RegisterHandler("playerskin_temp", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, false);

	g_cvarSkinChangeInstant = RegisterConVar("sm_store_playerskin_instant", "0", "Defines whether the skin should be changed instantly or on next spawn.", TYPE_INT);
	g_cvarSkinForceChange = RegisterConVar("sm_store_playerskin_force_default", "0", "If it's set to 1, default skins will be enforced.", TYPE_INT);
	g_cvarSkinForceChangeCT = RegisterConVar("sm_store_playerskin_default_ct", "", "Path of the default CT skin.", TYPE_STRING);
	g_cvarSkinForceChangeT = RegisterConVar("sm_store_playerskin_default_t", "", "Path of the default T skin.", TYPE_STRING);
	g_cvarSkinDelay = RegisterConVar("sm_store_playerskin_delay", "2.0", "Delay after spawn before applying the skin. -1 means no delay", TYPE_FLOAT);
	
	HookEvent("player_spawn", PlayerSkins_PlayerSpawn);
	HookEvent("player_death", PlayerSkins_PlayerDeath);

	//g_bZombieMode = (FindPluginByFile("zombiereloaded")==INVALID_HANDLE?false:true);
}

#if defined STANDALONE_BUILD
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("ZR_IsClientZombie");
	return APLRes_Success;
} 
#endif

public PlayerSkins_OnMapStart()
{
	for(new i=0;i<g_iPlayerSkins;++i)
	{
		g_ePlayerSkins[i][nModelIndex] = PrecacheModel2(g_ePlayerSkins[i][szModel], true);
		Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i][szModel]);

		if(g_ePlayerSkins[i][szArms][0]!=0)
		{
			PrecacheModel2(g_ePlayerSkins[i][szArms], true);
			Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i][szArms]);
		}
	}

	if(g_eCvars[g_cvarSkinForceChangeT][sCache][0] != 0 && (FileExists(g_eCvars[g_cvarSkinForceChangeT][sCache]) || FileExists(g_eCvars[g_cvarSkinForceChangeT][sCache], true)))
	{
		g_bTForcedSkin = true;
		PrecacheModel2(g_eCvars[g_cvarSkinForceChangeT][sCache], true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarSkinForceChangeT][sCache]);
	}
	else
		g_bTForcedSkin = false;
		
	if(g_eCvars[g_cvarSkinForceChangeCT][sCache][0] != 0 && (FileExists(g_eCvars[g_cvarSkinForceChangeCT][sCache]) || FileExists(g_eCvars[g_cvarSkinForceChangeCT][sCache], true)))
	{
		g_bCTForcedSkin = true;
		PrecacheModel2(g_eCvars[g_cvarSkinForceChangeCT][sCache], true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarSkinForceChangeCT][sCache]);
	}
	else
		g_bCTForcedSkin = false;
}

#if defined STANDALONE_BUILD
public OnLibraryAdded(const String:name[])
#else
public PlayerSkins_OnLibraryAdded(const String:name[])
#endif
{
	//if(strcmp(name, "zombiereloaded")==0)
		//g_bZombieMode = true;
}

#if defined STANDALONE_BUILD
public OnClientConnected(client)
#else
public PlayerSkins_OnClientConnected(client)
#endif
{
	g_iTempSkins[client] = -1;
}

public PlayerSkins_Reset()
{
	g_iPlayerSkins = 0;
}

public PlayerSkins_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iPlayerSkins);
	
	KvGetString(kv, "model", g_ePlayerSkins[g_iPlayerSkins][szModel], PLATFORM_MAX_PATH);
	KvGetString(kv, "arms", g_ePlayerSkins[g_iPlayerSkins][szArms], PLATFORM_MAX_PATH);
	g_ePlayerSkins[g_iPlayerSkins][iSkin] = KvGetNum(kv, "skin");
	g_ePlayerSkins[g_iPlayerSkins][iTeam] = KvGetNum(kv, "team");
	g_ePlayerSkins[g_iPlayerSkins][bTemporary] = (KvGetNum(kv, "temporary")?true:false);
	
	if(FileExists(g_ePlayerSkins[g_iPlayerSkins][szModel], true))
	{
		++g_iPlayerSkins;
		return true;
	}
	
	return false;
}

public PlayerSkins_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	if(g_eCvars[g_cvarSkinChangeInstant][aCache] && IsPlayerAlive(client) && GetClientTeam(client)==g_ePlayerSkins[m_iData][iTeam])
	{
		
		Store_SetClientModel(client, g_ePlayerSkins[m_iData][szModel], g_ePlayerSkins[m_iData][iSkin]);
	}
	else
	{
		if(Store_IsClientLoaded(client))
			Chat(client, "%t", "PlayerSkins Settings Changed");

		if(g_ePlayerSkins[m_iData][bTemporary])
		{
			g_iTempSkins[client] = m_iData;
			return -1;
		}
	}
	return g_ePlayerSkins[Store_GetDataIndex(id)][iTeam]-2;
}

public PlayerSkins_Remove(client, id)
{
	if(Store_IsClientLoaded(client) && g_eCvars[g_cvarSkinChangeInstant][aCache])
		Chat(client, "%t", "PlayerSkins Settings Changed");
	return g_ePlayerSkins[Store_GetDataIndex(id)][iTeam]-2;
}

public Action:PlayerSkins_PlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
			
	new Float:Delay = Float:g_eCvars[g_cvarSkinDelay][aCache];

	//if(Delay < 0 && g_bZombieMode)
		//Delay = 2.0;

	if(Delay < 0)
		PlayerSkins_PlayerSpawnPost(INVALID_HANDLE, GetClientUserId(client));
	else
		CreateTimer(2.0, PlayerSkins_PlayerSpawnPost, GetClientUserId(client));

	return Plugin_Continue;
}

public Action:PlayerSkins_PlayerSpawnPost(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client)
		return Plugin_Stop;

	//if(g_bZombieMode)
	//	if(ZR_IsClientZombie(client))
	//		return Plugin_Continue;
		
	new m_iEquipped = Store_GetEquippedItem(client, "playerskin", 2);
	if(m_iEquipped < 0)
		m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
	if(m_iEquipped >= 0 || g_iTempSkins[client] >= 0)
	{
		decl m_iData;
		if(g_iTempSkins[client]>=0)
			m_iData = g_iTempSkins[client];
		else
			m_iData = Store_GetDataIndex(m_iEquipped);
		Store_SetClientModel(client, g_ePlayerSkins[m_iData][szModel], g_ePlayerSkins[m_iData][iSkin], g_ePlayerSkins[m_iData][szArms]);
	}
	else if(g_eCvars[g_cvarSkinForceChange][aCache])
	{
		new m_iTeam = GetClientTeam(client);
		if(m_iTeam == 2 && g_bTForcedSkin)
			Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeT][sCache]);
		else if(m_iTeam == 3 && g_bCTForcedSkin)
			Store_SetClientModel(client, g_eCvars[g_cvarSkinForceChangeCT][sCache]);
	}
	return Plugin_Stop;
}

Store_SetClientModel(client, const String:model[], const skin=0, const String:arms[]="")
{
	if(GAME_TF2)
	{
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
	}
	else
	{
		SetEntityModel(client, model);
	}

	SetEntProp(client, Prop_Send, "m_nSkin", skin);

	if(GAME_CSGO & arms[0]!=0)
	{
		SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
	}
}

public Action:PlayerSkins_PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iTempSkins[client] = -1;
	return Plugin_Continue;
}