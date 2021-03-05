#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <zephstocks>

#include <sdkhooks>
#include <thirdperson>

#undef REQUIRE_EXTENSIONS
#include <store>

new bool:GAME_TF2 = false;
#endif

enum Hat
{
	String:szModel[PLATFORM_MAX_PATH],
	String:szAttachment[64],
	Float:fPosition[3],
	Float:fAngles[3],
	bool:bBonemerge,
	iTeam,
	iSlot
}

new Handle:g_hLookupAttachment = INVALID_HANDLE;

new g_eHats[STORE_MAX_ITEMS][Hat];

new g_iClientHats[MAXPLAYERS+1][STORE_MAX_SLOTS];
new g_iHats = 0;

new g_cvarDefaultT = -1;
new g_cvarDefaultCT = -1;
new g_cvarOverrideEnabled = -1;

new bool:g_bTOverride = false;
new bool:g_bCTOverride = false;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Hats_OnPluginStart()
#endif
{
#if !defined STANDALONE_BUILD
	// This is not a standalone build, we don't want hats to kill the whole plugin for us	
	if(GetExtensionFileStatus("sdkhooks.ext")!=1)
	{
		LogError("SDKHooks isn't installed or failed to load. Hats will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
#else
	// TF2 is unsupported
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif

	if(GAME_TF2)
		return;

	new Handle:m_hGameConf = LoadGameConfigFile("store.gamedata");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(m_hGameConf, SDKConf_Signature, "LookupAttachment");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hLookupAttachment = EndPrepSDKCall();
	CloseHandle(m_hGameConf);
		
	if(!g_hLookupAttachment && !GAME_CSGO)
	{
		LogError("LookupAttachment signature is out of date or not supported in this game. Hats will be disabled. Please contact the author.");
		return;
	}
	
	Store_RegisterHandler("hat", "model", Hats_OnMapStart, Hats_Reset, Hats_Config, Hats_Equip, Hats_Remove, true);
		
	g_cvarDefaultT = RegisterConVar("sm_store_hats_default_t", "models/player/t_leet.mdl", "Terrorist model that supports hats", TYPE_STRING);
	g_cvarDefaultCT = RegisterConVar("sm_store_hats_default_ct", "models/player/ct_urban.mdl", "Counter-Terrorist model that supports hats", TYPE_STRING);
	g_cvarOverrideEnabled = RegisterConVar("sm_store_hats_skin_override", "0", "Allow the store to override player model if it doesn't support hats", TYPE_INT);
	
	HookEvent("player_spawn", Hats_PlayerSpawn);
	HookEvent("player_death", Hats_PlayerRemoveEvent);
	HookEvent("player_team", Hats_PlayerRemoveEvent);
}

public Hats_OnMapStart()
{
	for(new a=0;a<=MaxClients;++a)
		for(new b=0;b<STORE_MAX_SLOTS;++b)
			g_iClientHats[a][b]=0;

	for(new i=0;i<g_iHats;++i)
	{
		PrecacheModel2(g_eHats[i][szModel], true);
		Downloader_AddFileToDownloadsTable(g_eHats[i][szModel]);
	}
		
	// Just in case...
	if(FileExists(g_eCvars[g_cvarDefaultT][sCache], true))
	{
		g_bTOverride = true;
		PrecacheModel2(g_eCvars[g_cvarDefaultT][sCache], true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarDefaultT][sCache]);
	}
	else
		g_bTOverride = false;
		
	if(FileExists(g_eCvars[g_cvarDefaultCT][sCache], true))
	{
		g_bCTOverride = true;
		PrecacheModel2(g_eCvars[g_cvarDefaultCT][sCache], true);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarDefaultCT][sCache]);
	}
	else
		g_bCTOverride = false;
}

public Hats_Reset()
{
	g_iHats = 0;
}

public Hats_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iHats);
	decl Float:m_fTemp[3];
	KvGetString(kv, "model", g_eHats[g_iHats][szModel], PLATFORM_MAX_PATH);
	KvGetVector(kv, "position", m_fTemp);
	g_eHats[g_iHats][fPosition] = m_fTemp;
	KvGetVector(kv, "angles", m_fTemp);
	g_eHats[g_iHats][fAngles] = m_fTemp;
	g_eHats[g_iHats][bBonemerge] = (KvGetNum(kv, "bonemerge", 0)?true:false);
	g_eHats[g_iHats][iTeam] = KvGetNum(kv, "team", 0);
	g_eHats[g_iHats][iSlot] = KvGetNum(kv, "slot");
	KvGetString(kv, "attachment", g_eHats[g_iHats][szAttachment], 64, "");

	if(strcmp(g_eHats[g_iHats][szAttachment], "")==0)
	{
		if(GAME_CSGO)
		{
			strcopy(g_eHats[g_iHats][szAttachment], 64, "facemask");
			g_eHats[g_iHats][fPosition][2] -= 4.0;
		}
		else
			strcopy(g_eHats[g_iHats][szAttachment], 64, "forward");
	}

	
	if(!(FileExists(g_eHats[g_iHats][szModel], true)))
		return false;
		
	++g_iHats;
	return true;
}

public Hats_Equip(client, id)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return -1;
	new m_iData = Store_GetDataIndex(id);
	RemoveHat(client, g_eHats[m_iData][iSlot]);
	CreateHat(client, id);
	return g_eHats[m_iData][iSlot];
}

public Hats_Remove(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	RemoveHat(client, g_eHats[m_iData][iSlot]);
	return g_eHats[m_iData][iSlot];
}

public Action:Hats_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
		
	// Support for plugins that set client model
	CreateTimer(0.1, Hats_PlayerSpawn_Post, GetClientUserId(client));
		
	return Plugin_Continue;
}

public Action:Hats_PlayerSpawn_Post(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Stop;

	for(new i=0;i<STORE_MAX_SLOTS;++i)
	{
		RemoveHat(client, i);
		CreateHat(client, -1, i);
	}
	return Plugin_Stop;
}

public Action:Hats_PlayerRemoveEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	for(new i=0;i<STORE_MAX_SLOTS;++i)
		RemoveHat(client, i);
	return Plugin_Continue;
}

CreateHat(client, itemid=-1, slot=0)
{
	new m_iEquipped = (itemid==-1?Store_GetEquippedItem(client, "hat", slot):itemid);
	if(m_iEquipped >= 0)
	{
		new m_iData = Store_GetDataIndex(m_iEquipped);
		new m_iTeam = GetClientTeam(client);
		
		if(g_eHats[m_iData][iTeam] != 0 && m_iTeam!=g_eHats[m_iData][iTeam])
			return;
		
		// If the model doesn't support hats, set the model to one that does
		if(!LookupAttachment(client, g_eHats[m_iData][szAttachment]))
		{
			if(g_eCvars[g_cvarOverrideEnabled][aCache])
			{
				if(m_iTeam==2 && g_bTOverride)
					SetEntityModel(client, g_eCvars[g_cvarDefaultT][sCache]);
				else if(m_iTeam==3 && g_bCTOverride)
					SetEntityModel(client, g_eCvars[g_cvarDefaultCT][sCache]);
				else
					return;
			}
			else
				return;
		}
		
		// Calculate the final position and angles for the hat
		decl Float:m_fHatOrigin[3];
		decl Float:m_fHatAngles[3];
		decl Float:m_fForward[3];
		decl Float:m_fRight[3];
		decl Float:m_fUp[3];
		GetClientAbsOrigin(client,m_fHatOrigin);
		GetClientAbsAngles(client,m_fHatAngles);
		
		m_fHatAngles[0] += g_eHats[m_iData][fAngles][0];
		m_fHatAngles[1] += g_eHats[m_iData][fAngles][1];
		m_fHatAngles[2] += g_eHats[m_iData][fAngles][2];

		new Float:m_fOffset[3];
		m_fOffset[0] = g_eHats[m_iData][fPosition][0];
		m_fOffset[1] = g_eHats[m_iData][fPosition][1];
		m_fOffset[2] = g_eHats[m_iData][fPosition][2];

		GetAngleVectors(m_fHatAngles, m_fForward, m_fRight, m_fUp);

		m_fHatOrigin[0] += m_fRight[0]*m_fOffset[0]+m_fForward[0]*m_fOffset[1]+m_fUp[0]*m_fOffset[2];
		m_fHatOrigin[1] += m_fRight[1]*m_fOffset[0]+m_fForward[1]*m_fOffset[1]+m_fUp[1]*m_fOffset[2];
		m_fHatOrigin[2] += m_fRight[2]*m_fOffset[0]+m_fForward[2]*m_fOffset[1]+m_fUp[2]*m_fOffset[2];
		
		// Create the hat entity
		new m_iEnt = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(m_iEnt, "model", g_eHats[m_iData][szModel]);
		DispatchKeyValue(m_iEnt, "spawnflags", "256");
		DispatchKeyValue(m_iEnt, "solid", "0");
		SetEntPropEnt(m_iEnt, Prop_Send, "m_hOwnerEntity", client);
		
		if(g_eHats[m_iData][bBonemerge])
			Bonemerge(m_iEnt);
		
		DispatchSpawn(m_iEnt);	
		AcceptEntityInput(m_iEnt, "TurnOn", m_iEnt, m_iEnt, 0);
		
		// Save the entity index
		g_iClientHats[client][g_eHats[m_iData][iSlot]]=m_iEnt;
		
		// We don't want the client to see his own hat
		SDKHook(m_iEnt, SDKHook_SetTransmit, Hook_SetTransmit);
		
		// Teleport the hat to the right position and attach it
		TeleportEntity(m_iEnt, m_fHatOrigin, m_fHatAngles, NULL_VECTOR); 
		
		SetVariantString("!activator");
		AcceptEntityInput(m_iEnt, "SetParent", client, m_iEnt, 0);
		
		SetVariantString(g_eHats[m_iData][szAttachment]);
		AcceptEntityInput(m_iEnt, "SetParentAttachmentMaintainOffset", m_iEnt, m_iEnt, 0);
	}
}

public RemoveHat(client, slot)
{
	if(g_iClientHats[client][slot] != 0 && IsValidEdict(g_iClientHats[client][slot]))
	{
		SDKUnhook(g_iClientHats[client][slot], SDKHook_SetTransmit, Hook_SetTransmit);
		new String:m_szClassname[64];
		GetEdictClassname(g_iClientHats[client][slot], STRING(m_szClassname));
		if(strcmp("prop_dynamic", m_szClassname)==0)
			AcceptEntityInput(g_iClientHats[client][slot], "Kill");
	}
	g_iClientHats[client][slot]=0;

}

public Action:Hook_SetTransmit(ent, client)
{
	if(GetFeatureStatus(FeatureType_Native, "IsPlayerInTP")==FeatureStatus_Available)
		if(IsPlayerInTP(client))
			return Plugin_Continue;

	for(new i=0;i<STORE_MAX_SLOTS;++i)
		if(ent == g_iClientHats[client][i])
			return Plugin_Handled;

	if(client && IsClientInGame(client))
	{
		new m_iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		new m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if(m_iObserverMode == 4 && m_hObserverTarget>=0)
		{
			for(new i=0;i<STORE_MAX_SLOTS;++i)
				if(ent == g_iClientHats[m_hObserverTarget][i])
					return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public LookupAttachment(client, String:point[])
{
	if(GAME_CSGO)
		return true;
	if(g_hLookupAttachment==INVALID_HANDLE)
		return false;
	if(!client || !IsClientInGame(client))
		return false;
	return SDKCall(g_hLookupAttachment, client, point);
}

public Bonemerge(ent)
{
	new m_iEntEffects = GetEntProp(ent, Prop_Send, "m_fEffects"); 
	m_iEntEffects &= ~32;
	m_iEntEffects |= 1;
	m_iEntEffects |= 128;
	SetEntProp(ent, Prop_Send, "m_fEffects", m_iEntEffects); 
}

public Store_OnClientModelChanged(client, String:model[])
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	if(strcmp(model, g_eCvars[g_cvarDefaultT][sCache])==0 || strcmp(model, g_eCvars[g_cvarDefaultCT][sCache])==0)
		return;

	if(!LookupAttachment(client, "forward"))
	{
		new bool:m_bHasHats = false;
		for(new i=0;i<STORE_MAX_SLOTS;++i)
		{
			if(Store_GetEquippedItem(client, "hat", i)!=-1)
			{
				m_bHasHats = true;
				RemoveHat(client, i);
				CreateHat(client, -1, i);
			}
		}
		
		if(m_bHasHats)
			if(g_eCvars[g_cvarOverrideEnabled][aCache])
				Chat(client, "%t", "Override Enabled");
			else
				Chat(client, "%t", "Override Disabled");
	}
}