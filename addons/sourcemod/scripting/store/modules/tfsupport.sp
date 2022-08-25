#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#endif

enum TFWeapon
{
	String:m_szEntity[64],
	String:m_szModel[PLATFORM_MAX_PATH],
	m_unClass,
	m_unItemDefIndex,
	m_unQuality,
	m_unLevel,
	m_unSlot,
	m_unDefIndex[15],
	Float:m_flValue[15],
	m_unAttribs,
	m_unLives,
}

new g_eTFUnusual[STORE_MAX_ITEMS];
new g_eTFHatDye[STORE_MAX_ITEMS][4];
new g_eTFWeapons[STORE_MAX_ITEMS][TFWeapon];
new Float:g_flTFHeads[STORE_MAX_ITEMS];
new Float:g_flTFWeaponSizes[STORE_MAX_ITEMS];
new String:g_szTFHats[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
new g_iClientWeapons[MAXPLAYERS+1][5];
new Float:g_flClientHead[MAXPLAYERS+1];
new Float:g_flClientWeaponSize[MAXPLAYERS+1];
new Float:g_flTFHatsOffset[STORE_MAX_ITEMS];
new g_iTFHatBuilding[STORE_MAX_ITEMS];
new g_iEntHats[2048];

new g_iTFUnusual = 0;
new g_iTFHatDye = 0;
new g_iTFWeapons = 0;
new g_iTFHeads = 0;
new g_iTFHats = 0;
new g_iTFWeaponSizes = 0;

new Handle:g_hSdkEquipWearable;

new Handle:g_hHatIDs = INVALID_HANDLE;
new Handle:g_hRemoveTimer[MAXPLAYERS+1]={INVALID_HANDLE};


new g_bTFHide[2048]={false};
new bool:g_bTF2Enabled = true;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public TFSupport_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif
	if(!GAME_TF2)
		return;	

#if !defined STANDALONE_BUILD
	// This is not a standalone build, we don't want hats to kill the whole plugin for us	
	if(GetExtensionFileStatus("tf2items.ext")!=1)
	{
		g_bTF2Enabled = false;
		LogError("TF2Items isn't installed or failed to load. TF2 support will be disabled. Please install TF2Items. (https://forums.alliedmods.net/showthread.php?t=115100)");
		return;
	}
#endif

	if(!TFSupport_ReadItemSchema())
		return;

	new Handle:m_hGameConf = LoadGameConfigFile("store.gamedata");
	if (m_hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(m_hGameConf, SDKConf_Virtual, "EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();
		
		CloseHandle(m_hGameConf);
	}
	else
		return;
	
	Store_RegisterHandler("tfunusual", "unusual_id", TFSupport_OnMapStart, TFSupport_Reset, TFUnusual_Config, TFSupport_Equip, TFSupport_Remove, true);
	Store_RegisterHandler("tfhatdye", "color", TFSupport_OnMapStart, TFSupport_Reset, TFHatDye_Config, TFSupport_Equip, TFSupport_Remove, true);
	Store_RegisterHandler("tfweapon", "unique_id", TFWeapon_OnMapStart, TFSupport_Reset, TFWeapon_Config, TFWeapon_Equip, TFSupport_Remove, false);
	Store_RegisterHandler("tfhead", "size", TFSupport_OnMapStart, TFSupport_Reset, TFHead_Config, TFHead_Equip, TFHead_Remove, true);
	Store_RegisterHandler("tfhat", "model", TFSupport_OnMapStart, TFSupport_Reset, TFHat_Config, TFHat_Equip, TFSupport_Remove, true);
	Store_RegisterHandler("tfweaponsize", "size", TFSupport_OnMapStart, TFSupport_Reset, TFWeaponSize_Config, TFWeaponSize_Equip, TFWeaponSize_Remove, true);

	HookEvent("player_spawn", TFHead_PlayerSpawn);
	HookEvent("player_death", TFWeapon_PlayerDeath);
	HookEvent("player_builtobject",		TFHat_PlayerBuiltObject);
	HookEvent("player_upgradedobject",	TFHat_UpgradeObject);
	HookEvent("player_dropobject", 		TFHat_DropObject);
	HookEvent("player_carryobject",		TFHat_PickupObject);
}

public TFSupport_OnMapStart()
{
	for(new a=0;a<=MaxClients;++a)
	{
		g_iClientWeapons[a][0]=-1;
		g_iClientWeapons[a][1]=-1;
		g_iClientWeapons[a][2]=-1;
	}
}

public TFWeapon_OnMapStart()
{
	for(new i=0;i<g_iTFWeapons;++i)
	{
		PrecacheModel2(g_eTFWeapons[i][m_szModel]);
		Downloader_AddFileToDownloadsTable(g_eTFWeapons[i][m_szModel]);
	}
}

public TFSupport_Reset()
{
	g_iTFUnusual = 0;
	g_iTFHatDye = 0;
	g_iTFWeapons = 0;
	g_iTFHeads = 0;
	g_iTFHats = 0;
	g_iTFWeaponSizes = 0;
}

public TFUnusual_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTFUnusual);
	
	g_eTFUnusual[g_iTFUnusual] = KvGetNum(kv, "unusual_id");
	
	++g_iTFUnusual;
	return true;
}

public TFHatDye_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTFHatDye);
	
	KvGetColor(kv, "color", g_eTFHatDye[g_iTFHatDye][0], g_eTFHatDye[g_iTFHatDye][1], g_eTFHatDye[g_iTFHatDye][2], g_eTFHatDye[g_iTFHatDye][3]);
	
	++g_iTFHatDye;
	return true;
}

public TFHead_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTFHeads);
	
	g_flTFHeads[g_iTFHeads] = KvGetFloat(kv, "size", 1.0);
	
	++g_iTFHeads;
	return true;
}

public TFHat_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTFHats);
	
	KvGetString(kv, "model", g_szTFHats[g_iTFHats], PLATFORM_MAX_PATH);
	g_flTFHatsOffset[g_iTFHats] = KvGetFloat(kv, "offset");
	g_iTFHatBuilding[g_iTFHats] = KvGetNum(kv, "building");
	
	++g_iTFHats;
	return true;
}

public TFWeaponSize_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTFWeaponSizes);
	
	g_flTFWeaponSizes[g_iTFWeaponSizes] = KvGetFloat(kv, "size", 1.0);
	
	++g_iTFWeaponSizes;
	return true;
}

public TFWeapon_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTFWeapons);
	
	g_eTFWeapons[g_iTFWeapons][m_unAttribs] = 0;

	KvGetString(kv, "classname", g_eTFWeapons[g_iTFWeapons][m_szEntity], 64);
	KvGetString(kv, "model", g_eTFWeapons[g_iTFWeapons][m_szModel], 256);
	g_eTFWeapons[g_iTFWeapons][m_unItemDefIndex] = KvGetNum(kv, "def_index");
	g_eTFWeapons[g_iTFWeapons][m_unQuality] = KvGetNum(kv, "quality");
	g_eTFWeapons[g_iTFWeapons][m_unLevel] = KvGetNum(kv, "level");
	g_eTFWeapons[g_iTFWeapons][m_unClass] = KvGetNum(kv, "class");
	g_eTFWeapons[g_iTFWeapons][m_unSlot] = KvGetNum(kv, "playerslot");

	if(!FileExists(g_eTFWeapons[g_iTFWeapons][m_szModel], true))
		return false;

	if(!KvGotoFirstSubKey(kv))
		return false;

	do
	{
		g_eTFWeapons[g_iTFWeapons][m_unDefIndex][g_eTFWeapons[g_iTFWeapons][m_unAttribs]] = KvGetNum(kv, "def_index");
		g_eTFWeapons[g_iTFWeapons][m_flValue][g_eTFWeapons[g_iTFWeapons][m_unAttribs]++] = KvGetFloat(kv, "value");
	} while (KvGotoNextKey(kv));

	KvGoBack(kv);
	
	++g_iTFWeapons;
	return true;
}

public TFSupport_Equip(client, id)
{
	return 0;
}


public TFHead_Equip(client, id)
{
	if(IsPlayerAlive(client))
	{
		new m_iData = Store_GetDataIndex(id);
		g_flClientHead[client] = g_flTFHeads[m_iData];
	}
	return 0;
}

public TFWeaponSize_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	g_flClientWeaponSize[client] = g_flTFWeaponSizes[m_iData];
	if(IsPlayerAlive(client))
		TFWeaponSize_ResizeWeapon(client);
	return 0;
}

public TFHat_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	return g_iTFHatBuilding[m_iData];
}

public TFHead_Remove(client, id)
{
	if(IsPlayerAlive(client))
	{
		g_flClientHead[client] = 1.0;
	}
	return 0;
}

public TFWeaponSize_Remove(client, id)
{
	g_flClientWeaponSize[client] = 1.0;
	if(IsPlayerAlive(client))
		TFWeaponSize_ResizeWeapon(client);
	return 0;
}

public TFSupport_Remove(client)
{
	return 0;
}

public TFWeapon_Equip(client, id)
{
	if(!IsPlayerAlive(client))
	{
		Chat(client, "%t", "Must be Alive");
		return 1;
	}

	if(GetFeatureStatus(FeatureType_Native, "VSH_GetSaxtonHaleUserId")==FeatureStatus_Available && VSH_GetSaxtonHaleUserId()==GetClientUserId(client))
		return 1;

	new idx = Store_GetDataIndex(id);

	if(_:TF2_GetPlayerClass(client) != g_eTFWeapons[idx][m_unClass])
	{
		Chat(client, "%t", "TF Wrong Class");
		return 1;
	}

	TFWeapon_RemoveChild(client);
	new Handle:m_hItem = TFSupport_CreateItem(idx);
	TFWeapon_CreateChild(client, idx);

	new ent = GetPlayerWeaponSlot(client, g_eTFWeapons[idx][m_unSlot]);
	if(ent)
		RemovePlayerItem(client, ent);

	new weapon = TF2Items_GiveNamedItem(client, m_hItem);
	if(IsValidEntity(weapon))
	{
		EquipPlayerWeapon(client, weapon);
		g_iClientWeapons[client][3]=weapon;
	}
	g_iClientWeapons[client][4]=idx;

	return 1;
}

public Handle:TFSupport_CreateItem(idx)
{
	new Handle:m_hItem = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(m_hItem, g_eTFWeapons[idx][m_szEntity]);
	TF2Items_SetItemIndex(m_hItem, g_eTFWeapons[idx][m_unItemDefIndex]);
	TF2Items_SetQuality(m_hItem, g_eTFWeapons[idx][m_unQuality]);
	TF2Items_SetLevel(m_hItem, g_eTFWeapons[idx][m_unLevel]);
	TF2Items_SetNumAttributes(m_hItem, g_eTFWeapons[idx][m_unAttribs]);

	for(new i=0;i<g_eTFWeapons[idx][m_unAttribs];++i)
	{
		TF2Items_SetAttribute(m_hItem, i, g_eTFWeapons[idx][m_unDefIndex][i], g_eTFWeapons[idx][m_flValue][i]);
	}

	return m_hItem;
}

public Action:TF2Items_OnGiveNamedItem(client, String:classname[], iItemDefinitionIndex, &Handle:hItem)
{
	new m_iEquippedUnusual = Store_GetEquippedItem(client, "tfunusual");
	new m_iEquippedDye = Store_GetEquippedItem(client, "tfhatdye");

	if(m_iEquippedUnusual < 0 && m_iEquippedDye < 0)
		return Plugin_Continue;

	if(FindValueInArray(g_hHatIDs, iItemDefinitionIndex)==-1)
		return Plugin_Continue;

	hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES | PRESERVE_ATTRIBUTES);
	new m_iDyeId = 0;
	if(m_iEquippedUnusual >=0 && m_iEquippedDye >=0)
	{
		TF2Items_SetNumAttributes(hItem, 2);
		m_iDyeId = 1;
	}
	else
		TF2Items_SetNumAttributes(hItem, 1);

	if(m_iEquippedUnusual >= 0)
	{
		new m_iDataUnusual = Store_GetDataIndex(m_iEquippedUnusual);
		TF2Items_SetQuality(hItem, 5);
		TF2Items_SetAttribute(hItem, 0, 134, float(g_eTFUnusual[m_iDataUnusual]));
	}

	if(m_iEquippedDye >= 0)
	{
		new m_iDataDye = Store_GetDataIndex(m_iEquippedDye);
		TF2Items_SetAttribute(hItem, m_iDyeId, 142, float(RgbToDec(g_eTFHatDye[m_iDataDye][0], g_eTFHatDye[m_iDataDye][1], g_eTFHatDye[m_iDataDye][2])));
	}

	return Plugin_Changed;
}

public RgbToDec(r, g, b)
{
	decl String:hex[32];
	Format(hex, sizeof(hex), "%02X%02X%02X", r, g, b);
	
	decl ret;
	StringToIntEx(hex, ret, 16);
	
	return ret;
}

public bool:TFSupport_ReadItemSchema()
{
	new Handle:m_hKV = CreateKeyValues("items_game");
	FileToKeyValues(m_hKV, "scripts/items/items_game.txt");

	g_hHatIDs = CreateArray(1);

	KvJumpToKey(m_hKV, "items");
	KvGotoFirstSubKey(m_hKV);

	decl String:m_szItemID[64];
	decl String:m_szSlot[64];
	do
	{
		KvGetSectionName(m_hKV, m_szItemID, sizeof(m_szItemID));
		KvGetString(m_hKV, "item_slot", m_szSlot, sizeof(m_szSlot));
		if(strcmp(m_szSlot, "head")==0)
			PushArrayCell(g_hHatIDs, StringToInt(m_szItemID));
		else
		{
			KvGetString(m_hKV, "prefab", m_szSlot, sizeof(m_szSlot));
			if(strcmp(m_szSlot, "hat")==0 || strcmp(m_szSlot, "base_hat")==0)
				PushArrayCell(g_hHatIDs, StringToInt(m_szItemID));
		}
	} while (KvGotoNextKey(m_hKV));

	CloseHandle(m_hKV);
	return true;
}

public Action:TFHead_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	TFWeaponSize_ResizeWeapon(client);

	g_flClientHead[client]=1.0;

	new m_iEquippedHead = Store_GetEquippedItem(client, "tfhead");
	if(m_iEquippedHead < 0)
		return Plugin_Continue;

	new m_iData = Store_GetDataIndex(m_iEquippedHead);
	g_flClientHead[client] = g_flTFHeads[m_iData];

	return Plugin_Continue;
}

public Action:TFWeapon_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	TFWeapon_RemoveChild(client);
	g_iClientWeapons[client][4]=0;
	return Plugin_Continue;
}

public TFWeapon_RemoveChild(client)
{
	if(g_iClientWeapons[client][0]>0 && IsValidEntity(g_iClientWeapons[client][0]))
	{
		SDKUnhook(g_iClientWeapons[client][0], SDKHook_SetTransmit, Hook_TFSetTransmit);
		TF2_RemoveWearable(client, g_iClientWeapons[client][0]);
		AcceptEntityInput(g_iClientWeapons[client][0], "Kill");
	}
	if(g_iClientWeapons[client][1]>0 && IsValidEntity(g_iClientWeapons[client][1]))
	{
		SDKUnhook(g_iClientWeapons[client][1], SDKHook_SetTransmit, Hook_TFSetTransmit);
		AcceptEntityInput(g_iClientWeapons[client][1], "Kill");
	}
	if(g_iClientWeapons[client][2]>0 && IsValidEntity(g_iClientWeapons[client][2]))
	{
		SDKUnhook(g_iClientWeapons[client][2], SDKHook_SetTransmit, Hook_TFSetTransmit);
		AcceptEntityInput(g_iClientWeapons[client][2], "Kill");
	}
	g_iClientWeapons[client][0] = -1;
	g_iClientWeapons[client][1] = -1;
	g_iClientWeapons[client][2] = -1;
}

public TFWeapon_CreateChild(client, idx)
{
	if(g_eTFWeapons[idx][m_szModel][0]==0)
		return;

	new m_iTeam = GetClientTeam(client);
	new parent = CreateEntityByName("tf_wearable");
	
	Bonemerge(parent);
	SetEntProp(parent, Prop_Send, "m_iTeamNum", m_iTeam);
	SetEntProp(parent, Prop_Send, "m_nSkin", (m_iTeam-2));
	SetEntProp(parent, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(parent, Prop_Send, "m_iItemDefinitionIndex", 6);
	DispatchSpawn(parent);

	decl String:m_szModelName[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", STRING(m_szModelName));
	SetEntityModel(parent, m_szModelName);

	g_iClientWeapons[client][0]=parent;

	TF2_EquipWearable(client, parent);

	new Float:pos[3];
	GetClientAbsOrigin(client, pos);
	TeleportEntity(parent, pos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(parent, "SetParent", client, parent, 0);

	SetVariantString("head");
	AcceptEntityInput(parent, "SetParentAttachment", parent, parent, 0);

	//////////////////////
	//		WEAPON		//
	//////////////////////

	new m_iEnt_Hack = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(m_iEnt_Hack, "model", g_eTFWeapons[idx][m_szModel]);
	DispatchKeyValue(m_iEnt_Hack, "spawnflags", "256");
	DispatchKeyValue(m_iEnt_Hack, "solid", "0");
	SetEntPropEnt(m_iEnt_Hack, Prop_Send, "m_hOwnerEntity", client);
	
	Bonemerge(m_iEnt_Hack);
	
	DispatchSpawn(m_iEnt_Hack);	
	AcceptEntityInput(m_iEnt_Hack, "TurnOn", m_iEnt_Hack, m_iEnt_Hack, 0);
	
	// Save the entity index
	g_iClientWeapons[client][2]=m_iEnt_Hack;

	//////////////////////
	//		LINK		//
	//////////////////////

	new m_iEnt = CreateEntityByName("prop_dynamic_override");

	DispatchKeyValue(m_iEnt, "spawnflags", "1");
	//DispatchKeyValue(m_iEnt, "modelscale", "0.000001");
	SetEntProp(m_iEnt, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(m_iEnt, Prop_Send, "m_nSkin", (m_iTeam-2));
	SetEntPropEnt(m_iEnt, Prop_Send, "m_hOwnerEntity", client);
	Bonemerge(m_iEnt);

	SetEntityModel(m_iEnt, m_szModelName);
	
	SetVariantString("!activator");
	AcceptEntityInput(m_iEnt_Hack, "SetParent", m_iEnt, m_iEnt_Hack, 0);
	
	SetVariantString("head");
	AcceptEntityInput(m_iEnt_Hack, "SetParentAttachment", m_iEnt_Hack, m_iEnt_Hack, 0);

	g_iClientWeapons[client][1]=m_iEnt_Hack;

	//////////////////////
	//		PARENT		//
	//////////////////////

	SetVariantString("!activator");
	AcceptEntityInput(m_iEnt, "SetParent", parent, m_iEnt, 0);

	SetVariantString("head");
	AcceptEntityInput(m_iEnt, "SetParentAttachment", m_iEnt, m_iEnt, 0);

	SDKHook(g_iClientWeapons[client][0], SDKHook_SetTransmit, Hook_TFSetTransmit);
	SDKHook(g_iClientWeapons[client][1], SDKHook_SetTransmit, Hook_TFSetTransmit);
	SDKHook(g_iClientWeapons[client][2], SDKHook_SetTransmit, Hook_TFSetTransmit);

	g_hRemoveTimer[client]=INVALID_HANDLE;
}

stock TF2_EquipWearable(iOwner, iItem)
{	
	SDKCall(g_hSdkEquipWearable, iOwner, iItem);
}

public Action:Hook_TFSetTransmit(ent, client)
{
	for(new i=0;i<3;++i)
	{
		if(ent == g_iClientWeapons[client][i])
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public TFHead_OnGameFrame()
{
	if(!GAME_TF2 || !g_bTF2Enabled)
		return;
	LoopAlivePlayers(client)
	{
		if(g_flClientHead[client]!=1.0)
			SetEntPropFloat(client, Prop_Send, "m_flHeadScale", g_flClientHead[client]);
	}
}

public TFWeapon_OnGameFrame()
{
	if(!g_bTF2Enabled)
		return;

	LoopAlivePlayers(m_iOwner)
	{
		if(g_iClientWeapons[m_iOwner][4]==0)
			continue;

		new TFCond:conds[] = {TFCond_Disguised,
							TFCond_Cloaked,
							TFCond_Bonked,
							TFCond_Dazed,
							TFCond_DisguisedAsDispenser,
							TFCond_HalloweenThriller,
							TFCond_Stealthed,
							TFCond_HalloweenGhostMode};


		new bool:m_bHide = false;
		for(new i=0;i<sizeof(conds);++i)
			if(TF2_IsPlayerInCondition(m_iOwner, conds[i]))
			{
				m_bHide = true;
				break;
			}

		if(g_iClientWeapons[m_iOwner][3] != GetEntPropEnt(m_iOwner, Prop_Send, "m_hActiveWeapon"))
			m_bHide = true;

		if(m_bHide && !g_bTFHide[m_iOwner])
		{
			g_bTFHide[m_iOwner] = true;
			if(g_hRemoveTimer[m_iOwner]==INVALID_HANDLE)
				g_hRemoveTimer[m_iOwner]=CreateTimer(0.1, TFWeapon_DeleteChilds, GetClientUserId(m_iOwner));
		}	
		else if(!m_bHide && g_bTFHide[m_iOwner])
		{
			g_bTFHide[m_iOwner] = false;
			if(g_hRemoveTimer[m_iOwner]==INVALID_HANDLE)
				g_hRemoveTimer[m_iOwner]=CreateTimer(0.1, TFWeapon_CreateChilds, GetClientUserId(m_iOwner));
		}
	}
}

public Action:TFWeapon_DeleteChilds(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	TFWeapon_RemoveChild(client);
	g_hRemoveTimer[client]=INVALID_HANDLE;

	return Plugin_Stop;
}

public Action:TFWeapon_CreateChilds(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	TFWeapon_CreateChild(client, g_iClientWeapons[client][4]);
	g_hRemoveTimer[client]=INVALID_HANDLE;

	return Plugin_Stop;
}

public Action:TFHat_PickupObject(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	new m_iBuilding = GetEventInt(event, "index");
	if(!m_iBuilding || !IsValidEntity(m_iBuilding))
		return Plugin_Continue;

	TFHat_Destroy(m_iBuilding);
	
	return Plugin_Continue;
}

public Action:TFHat_DropObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	new TFObjectType:object_s = TFObjectType:GetEventInt(event, "object");
	
	new m_iBuilding = GetEventInt(event, "index");
	if(!m_iBuilding || !IsValidEntity(m_iBuilding))
		return Plugin_Continue;

	new Handle:data = CreateDataPack();
	WritePackCell(data, GetClientUserId(client));
	WritePackCell(data, object_s);
	WritePackCell(data, EntIndexToEntRef(m_iBuilding));
	ResetPack(data);

	CreateTimer(2.0, TFHat_Respawn, data);

	return Plugin_Continue;
}

public Action:TFHat_UpgradeObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new TFObjectType:object_s = TFObjectType:GetEventInt(event, "object");

	new m_iBuilding = GetEventInt(event, "index");
	if(!m_iBuilding || !IsValidEntity(m_iBuilding))
		return Plugin_Continue;

	new Handle:data = CreateDataPack();
	WritePackCell(data, GetClientUserId(client));
	WritePackCell(data, object_s);
	WritePackCell(data, EntIndexToEntRef(m_iBuilding));
	ResetPack(data);

	TFHat_Destroy(m_iBuilding);
	CreateTimer(2.0, TFHat_Respawn, data);
	
	return Plugin_Continue;
}

public Action:TFHat_Respawn(Handle:timer, any:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	new TFObjectType:object_s = ReadPackCell(data);
	new m_iBuilding = EntRefToEntIndex(ReadPackCell(data));

	CloseHandle(data);

	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	if(!m_iBuilding || !IsValidEntity(m_iBuilding))
		return Plugin_Stop;

	if(object_s == TFObject_Sentry || object_s == TFObject_Dispenser)
	{
		TFHat_Spawn(m_iBuilding, client, object_s);
	}

	return Plugin_Stop;
}

public Action:TFHat_PlayerBuiltObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	new TFObjectType:object_s = TFObjectType:GetEventInt(event, "object");
	
		
	new m_iBuilding = GetEventInt(event, "index");
	if(!m_iBuilding || !IsValidEntity(m_iBuilding))
		return Plugin_Continue;

	if(!GetEntProp(m_iBuilding, Prop_Send, "m_bCarryDeploy"))
	{		
		if(object_s == TFObject_Sentry || object_s == TFObject_Dispenser)
		{
			TFHat_Spawn(m_iBuilding, client, object_s);
		}
	}
	
	return Plugin_Continue;
}

public TFHat_Destroy(ent)
{
	if(!ent || !IsValidEntity(ent))
		return;

	new ent2 = EntRefToEntIndex(g_iEntHats[ent]);
	if(ent2 && IsValidEntity(ent2))
		AcceptEntityInput(ent2, "Kill");
	g_iEntHats[ent] = 0;
}

public TFHat_Spawn(ent, owner, TFObjectType:type)
{
	new m_iEquippedHat = Store_GetEquippedItem(owner, "tfhat", _:type);
	if(m_iEquippedHat < 0)
		return;
	new data = Store_GetDataIndex(m_iEquippedHat);	

	new Float:pPos[3], Float:pAng[3];
	new prop = CreateEntityByName("prop_dynamic_override");
	new level = -1;

	level = GetEntProp(ent, Prop_Send, "m_iUpgradeLevel");
	
	if(IsValidEntity(prop))
	{
		DispatchKeyValue(prop, "model", g_szTFHats[data]); 

		DispatchSpawn(prop);
		AcceptEntityInput(prop, "Enable");
		SetEntProp(prop, Prop_Send, "m_nSkin", GetClientTeam(owner) - 2);

		SetVariantString("!activator");
		AcceptEntityInput(prop, "SetParent", ent);
		
		if(type == TFObject_Dispenser)
		{
			SetVariantString("build_point_0");
		}
		else if(type == TFObject_Sentry)
		{
			if(level < 3)
				SetVariantString("build_point_0");
			else
				SetVariantString("rocket_r");
		}
			
		AcceptEntityInput(prop, "SetParentAttachment", ent);
		
		GetEntPropVector(prop, Prop_Send, "m_vecOrigin", pPos);
		GetEntPropVector(prop, Prop_Send, "m_angRotation", pAng);
		
		pPos[2] += g_flTFHatsOffset[data];
			
		if(type == TFObject_Dispenser)
		{
			pPos[2] += 13.0;
			pAng[1] += 180.0;
			
			if(level == 3)
			{
				pPos[2] += 8.0;
			}
		}
		
		if(level == 3 && type != TFObject_Dispenser)
		{
			pPos[2] += 6.5;
			pPos[0] -= 11.0;
		}
		
		SetEntPropVector(prop, Prop_Send, "m_vecOrigin", pPos);
		SetEntPropVector(prop, Prop_Send, "m_angRotation", pAng);

		g_iEntHats[ent]=EntIndexToEntRef(prop);
	}
}

public TFWeaponSize_ResizeWeapon(client)
{
	new m_iEquippedSize = Store_GetEquippedItem(client, "tfweaponsize");
	if(m_iEquippedSize < 0)
		return;

	for(new i=0;i<6;++i)
	{
		new ent = GetPlayerWeaponSlot(client, i);
		if(ent != -1)
		{
			SetEntPropFloat(ent, Prop_Send, "m_flModelScale", g_flClientWeaponSize[client]);
		}
	}
}

#if defined STANDALONE_BUILD
public Bonemerge(ent)
{
	new m_iEntEffects = GetEntProp(ent, Prop_Send, "m_fEffects"); 
	m_iEntEffects &= ~32;
	m_iEntEffects |= 1;
	m_iEntEffects |= 128;
	SetEntProp(ent, Prop_Send, "m_fEffects", m_iEntEffects); 
}
#endif