/*
 * Store - Lootbox module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits:
 * Contributer:
 *
 * Original development by Zephyrus - https://github.com/dvarnai/store-plugin
 *
 * Love goes out to the sourcemod team and all other plugin developers!
 * THANKS FOR MAKING FREE SOFTWARE!
 *
 * This file is part of the Store SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <store> 

#include <multicolors>
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

#define MAX_LOOTBOXES 8

#define LEVEL_GREY 0
#define LEVEL_BLUE 1
#define LEVEL_PURPLE 2
#define LEVEL_RED 3
#define LEVEL_GOLD 4
#define LEVEL_AMOUNT 5

ConVar gc_bVisible, gc_bItemSellable;

char g_sChatPrefix[128];
char g_sCreditsName[64] = "Credits";
float g_fSellRatio;

char g_sPickUpSound[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sModel[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sEfxFile[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sEfxName[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sLootboxItems[MAX_LOOTBOXES][STORE_MAX_ITEMS / 4][LEVEL_AMOUNT][PLATFORM_MAX_PATH]; //assuming min 4 item on a box
float g_fChance[MAX_LOOTBOXES][LEVEL_AMOUNT];
int g_iTime[STORE_MAX_ITEMS];
int g_iPriceBack[STORE_MAX_ITEMS];
float g_iSellRatio[STORE_MAX_ITEMS];

int g_iLootboxEntityRef[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hTimerColor[MAXPLAYERS + 1];
int g_iClientSpeed[MAXPLAYERS + 1];
int g_iClientLevel[MAXPLAYERS + 1];
int g_iClientBox[MAXPLAYERS + 1];

int g_iItemID[MAX_LOOTBOXES];

int g_iBoxCount = 0;
int g_iItemLevelCount[MAX_LOOTBOXES][LEVEL_AMOUNT];

bool mapend = false;

int m_iOpenProp[MAXPLAYERS+1] = -1;

Handle gf_hPreviewItem;

public Plugin myinfo = 
{
	name = "Store - Lootbox module [TF2:Modules]",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.5", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gf_hPreviewItem = CreateGlobalForward("Store_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	Store_RegisterHandler("lootbox","lootbox", Lootbox_OnMapStart, Lootbox_Reset, Lootbox_Config, Lootbox_Equip, _, false);

	LoadTranslations("store.phrases");

	AutoExecConfig_SetFile("lootbox", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_bVisible = AutoExecConfig_CreateConVar("store_lootbox_visible_for_all", "1", "1 - the lootbox is visible for all player / 0 - the lootbox is only visible for player who owns it.");
	gc_bItemSellable = AutoExecConfig_CreateConVar("store_lootbox_item_sellable", "1", "1 - the lootbox's item is sellable / 0 - the lootbox is nonsellable.");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	HookEventEx("teamplay_win_panel", Event_End);
	
	if(g_cvarChatTag){}
}

public void OnMapStart()
{
	mapend = false;
}

public void OnMapEnd()
{
	mapend = false;
}

public Action OnLogAction(Handle source, Identity ident,int client,int target, const char[] message)
{
	if( StrContains( message , "changed map to" ) != -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_iLootboxEntityRef[i] != INVALID_ENT_REFERENCE)
			{
				Store_GiveItem(i, g_iItemID[g_iClientBox[i]], 0, 0, 0);

				CPrintToChat(i, "%s%t", g_sChatPrefix, "You haven't opend the box in given time");
			}
			g_iClientBox[i] = -1;

			RequestFrame(Frame_DeleteBox, i);
			
		}
		mapend = true;
	}
}

public void Event_End(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iLootboxEntityRef[i] != INVALID_ENT_REFERENCE)
		{
			Store_GiveItem(i, g_iItemID[g_iClientBox[i]], 0, 0, 0);

			CPrintToChat(i, "%s%t", g_sChatPrefix, "You haven't opend the box in given time");
		}
		g_iClientBox[i] = -1;

		RequestFrame(Frame_DeleteBox, i);
		
	}
	mapend = true;
}

public void OnClientDisconnect(int client)
{
	g_iClientBox[client] = -1;
	RequestFrame(Frame_DeleteBox, client);
}

public void OnClientPostAdminCheck(int client)
{
	m_iOpenProp[client] = -1;
}


public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);

	g_fSellRatio = FindConVar("sm_store_sell_ratio").FloatValue;
	if (g_fSellRatio < 0.1)
	{
		g_fSellRatio = 0.6;
	}
}

public void Lootbox_OnMapStart()
{
	char sBuffer[128];

	for (int i = 0; i < g_iBoxCount; i++)
	{
		PrecacheModel(g_sModel[i], true);
		Downloader_AddFileToDownloadsTable(g_sModel[i]);

		if (!g_sEfxName[i][0])
			continue;

		PrecacheParticleSystem(g_sEfxName[i]);
		if (FileExists(g_sEfxFile[i], true) && g_sEfxFile[i][0])
		{
			Downloader_AddFileToDownloadsTable(g_sEfxFile[i]);
			PrecacheGeneric(g_sEfxFile[i], true);
		}

		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sPickUpSound[i]);
		if (FileExists(sBuffer, true) && g_sPickUpSound[i][0])
		{
			AddFileToDownloadsTable(sBuffer);
			PrecacheSound(g_sPickUpSound[i], true);
		}
	}

	PrecacheSound("ui/csgo_ui_crate_item_scroll.wav", true);
}

public void Lootbox_Reset()
{
	g_iBoxCount = 0;

	for (int i = 0; i < g_iBoxCount; i++)
	{
		for (int j = 0; j < LEVEL_AMOUNT; j++)
		{
			g_iItemLevelCount[i][j] = 0;
		}
	}
}

public bool Lootbox_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iBoxCount);

	kv.GetString("model", g_sModel[g_iBoxCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModel[g_iBoxCount], true))
	{
		Store_SQLLogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModel[g_iBoxCount]);
		return false;
	}

	kv.GetString("file", g_sEfxFile[g_iBoxCount], PLATFORM_MAX_PATH);
	kv.GetString("name", g_sEfxName[g_iBoxCount], PLATFORM_MAX_PATH);
	kv.GetString("sound", g_sPickUpSound[g_iBoxCount], PLATFORM_MAX_PATH, "");
	g_iTime[g_iBoxCount] = kv.GetNum("time", 0);
	g_iPriceBack[g_iBoxCount] = kv.GetNum("price_back", 0);
	g_iSellRatio[g_iBoxCount] = kv.GetFloat("sell_ratio", 0.5);

	float percent = 0.0;
	g_fChance[g_iBoxCount][LEVEL_GREY] = kv.GetFloat("grey", 60.0);
	g_fChance[g_iBoxCount][LEVEL_BLUE] = kv.GetFloat("blue", 22.0);
	g_fChance[g_iBoxCount][LEVEL_PURPLE] = kv.GetFloat("purple", 10.0);
	g_fChance[g_iBoxCount][LEVEL_RED] = kv.GetFloat("red", 6.0);
	g_fChance[g_iBoxCount][LEVEL_GOLD] = kv.GetFloat("gold", 2.0);

	for (int i = 0; i < LEVEL_AMOUNT; i++)
	{
		percent += g_fChance[g_iBoxCount][i];
	}
	if (percent != 100.0)
	{
		Store_SQLLogMessage(0, LOG_ERROR, "Lootbox #%i - Sum of levels is not 100%", g_iBoxCount + 1);
		return false;
	}

	g_iItemID[g_iBoxCount] = itemid;

	kv.JumpToKey("Items");
	kv.GotoFirstSubKey(false);
	do
	{
		char sBuffer[16];
		int lvlindex = -1;

		kv.GetSectionName(sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer,"grey", false))
		{
			lvlindex = LEVEL_GREY;
		}
		else if (StrEqual(sBuffer,"blue", false))
		{
			lvlindex = LEVEL_BLUE;
		}
		else if (StrEqual(sBuffer,"purple", false))
		{
			lvlindex = LEVEL_PURPLE;
		}
		else if (StrEqual(sBuffer,"red", false))
		{
			lvlindex = LEVEL_RED;
		}
		else if (StrEqual(sBuffer,"gold", false))
		{
			lvlindex = LEVEL_GOLD;
		}

		if (lvlindex == -1)
		{
			Store_SQLLogMessage(0, LOG_ERROR, "Lootbox #%i - unknown level color: %s", sBuffer);
			return false;
		}

		kv.GetString(NULL_STRING, g_sLootboxItems[g_iBoxCount][g_iItemLevelCount[g_iBoxCount][lvlindex]][lvlindex], PLATFORM_MAX_PATH);
		g_iItemLevelCount[g_iBoxCount][lvlindex]++;
	}
	while kv.GotoNextKey(false);

	kv.GoBack();
	kv.GoBack();

	g_iBoxCount++;

	return true;
}

public int Lootbox_Equip(int client, int itemid)
{
	if (mapend) // Check if client open in after round end has call ? This also cause massive error log on next round since case's prop are invalid.
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Lootbox map ended");
		return 1;
	}
	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return 1;
	}

	if (g_iLootboxEntityRef[client] != INVALID_ENT_REFERENCE) // Prevent spam. The previous case wont be killed.
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Lootbox case is opening");
		return 1;
	}
	

	if (DropLootbox(client, Store_GetDataIndex(itemid)))
		return 0;

	return 1;
	
}

bool DropLootbox(int client, int index)
{
	int iLootbox = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	if (!iLootbox)
		return false;

//	char sBuffer[32];
//	FormatEx(sBuffer, 32, "lootbox_%d", iLootbox);

	float fOri[3], fAng[3], fRad[2], fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 35;

//	SetEntPropString(iLootbox, Prop_Data, "m_iName", sBuffer);

	DispatchKeyValue(iLootbox, "model", g_sModel[index]);
	DispatchSpawn(iLootbox);
	SetVariantString("fall");
	AcceptEntityInput(iLootbox, "SetAnimation");
	AcceptEntityInput(iLootbox, "Enable");
	ActivateEntity(iLootbox);
	
	EmitAmbientSound("ui/panorama/case_drop_01.wav", fPos, _, _, _, _, _, _);

	TeleportEntity(iLootbox, fPos, fAng, NULL_VECTOR);
	
	//CreateGlow(iLootbox);
	int iLight = CreateLight(iLootbox, fPos);
	int iRotator = CreateRotator(iLootbox, fPos);

	DataPack pack = new DataPack();
	g_iClientBox[client] = index;
	pack.WriteCell(client);
	pack.WriteCell(iLootbox);
	pack.WriteCell(iRotator);
	pack.WriteCell(iLight);
	g_iClientSpeed[client] = 235;
	g_hTimerColor[client] = CreateTimer(0.2, Timer_Color, pack, TIMER_REPEAT);

	if(!gc_bVisible.BoolValue)
	{
		SDKHook(iLootbox, SDKHook_SetTransmit, Hook_SetTransmit);
		SDKHook(iLight, SDKHook_SetTransmit, Hook_SetTransmit);
	}
	
	HookSingleEntityOutput(iLootbox, "OnAnimationDone", Case_OnAnimationDone, true);

	g_iLootboxEntityRef[client] = EntIndexToEntRef(iLootbox);

	return true;
}

public void Case_OnAnimationDone(const char[] output, int caller, int activator, float delay) 
{
	if(IsValidEntity(caller))
	{
		SetVariantString("open");
		AcceptEntityInput(caller, "SetAnimation");
	}
}

/*
void CreateGlow(int ent)
{
	int iOffset = GetEntSendPropOffs(ent, "m_clrGlow");
	SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 2000.0);

	SetEntData(ent, iOffset, 250, _, true);
	SetEntData(ent, iOffset + 1, 210, _, true);
	SetEntData(ent, iOffset + 2, 0, _, true);
	SetEntData(ent, iOffset + 3, 255, _, true);
}
*/

int CreateRotator(int ent, float pos[3])
{
	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", pos);

	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchKeyValue(iRotator, "maxspeed", "200");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	return iRotator;
}

int CreateLight(int ent, float pos[3])
{
	int iLight = CreateEntityByName("light_dynamic");

	DispatchKeyValue(iLight, "_light", "255 210 0 255");
	DispatchKeyValue(iLight, "brightness", "7");
	DispatchKeyValueFloat(iLight, "spotlight_radius", 260.0);
	DispatchKeyValueFloat(iLight, "distance", 100.0);
	DispatchKeyValue(iLight, "style", "0");

	DispatchSpawn(iLight); 
	TeleportEntity(iLight, pos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iLight, "SetParent", ent, iLight, 0);

	return iLight;
}

public Action Timer_Open(Handle timer, int client)
{
	char temp[64], sUId[64], sParts[2][64];
	strcopy(temp, sizeof(temp), g_sLootboxItems[g_iClientBox[client]][GetRandomInt(0, g_iItemLevelCount[g_iClientBox[client]][g_iClientLevel[client]] - 1)][g_iClientLevel[client]]); // sry
	
	int iCount = ExplodeString(temp, "-", sParts, 2, 64);
	sUId = sParts[0];
	int time = StringToInt(sParts[1]);
	int itemid = Store_GetItemIdbyUniqueId(sUId);
	
	char name[64];
	GetClientName(client, name, sizeof(name));
	
	if (time == 0)
		iCount = 1;

	if (itemid == -1)
	{
		RequestFrame(Frame_DeleteBox, client);
		Store_GiveItem(client, g_iItemID[g_iClientBox[client]], 0, 0, 0);
		CPrintToChat(client, "%s%s", g_sChatPrefix, "Error occured, item back. Inform admin log");

		Store_SQLLogMessage(client, LOG_ERROR, "Can't find item uid %s for lootbox #%i on level #%i.", sUId, g_iClientBox[client], g_iClientLevel[client]);
		return Plugin_Stop;
	}

	Store_Item item;
	Store_GetItem(itemid, item);
	Type_Handler handler;
	Store_GetHandler(item.iHandler, handler);

	if (Store_HasClientItem(client, itemid))
	{
		if (g_iPriceBack[g_iClientBox[client]] <= 0)
		{
			Store_GiveItem(client, g_iItemID[g_iClientBox[client]], 0, 0, 0);
			CPrintToChat(client, "%s%s", g_sChatPrefix, "Error occured, no price back. Inform admin log");
		}
		else
		{
			Store_SetClientCredits(client, Store_GetClientCredits(client) + RoundFloat(g_iPriceBack[g_iClientBox[client]]*view_as<float>(g_iSellRatio[g_iClientBox[client]])));
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Already own item from box. Get Credits price back", item.szName, handler.szType, RoundFloat(g_iPriceBack[g_iClientBox[client]]*view_as<float>(g_iSellRatio[g_iClientBox[client]])), g_sCreditsName);
			
			if (g_iClientLevel[client] == LEVEL_RED)
			CPrintToChatAll("%s%t", g_sChatPrefix, "Chat won lootbox item red", name, item.szName, handler.szType);
			if (g_iClientLevel[client] == LEVEL_GOLD)
			CPrintToChatAll("%s%t", g_sChatPrefix, "Chat won lootbox item gold", name, item.szName, handler.szType);
		}
	}
	else
	{
		if(g_iTime[g_iClientBox[client]] && iCount < 2)
		{
			if(gc_bItemSellable.IntValue)
				Store_GiveItem(client, itemid, _, GetTime() + g_iTime[g_iClientBox[client]], item.iPrice);
			else Store_GiveItem(client, itemid, _, GetTime() + g_iTime[g_iClientBox[client]], 1);
		}
		else if (g_iTime[g_iClientBox[client]] && iCount > 1)
		{
			if(gc_bItemSellable.IntValue)
				Store_GiveItem(client, itemid, _, GetTime() + time, item.iPrice);
			else Store_GiveItem(client, itemid, _, GetTime() + time, 1);
		}
		else 
		{
			if(gc_bItemSellable.IntValue)
				Store_GiveItem(client, itemid, _, _, item.iPrice);
			else Store_GiveItem(client, itemid, _, _, 1);
		}
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "%t", "You won lootbox item", item.szName, handler.szType);

		CPrintToChat(client, "%s%s", g_sChatPrefix, sBuffer);
		Store_SQLLogMessage(client, LOG_EVENT, "Opened a lootbox #%i. Item: %s.", g_iClientBox[client], sUId);
		if (g_iClientLevel[client] == LEVEL_RED)
			CPrintToChatAll("%s%t", g_sChatPrefix, "Chat won lootbox item red", name, item.szName, handler.szType);
		if (g_iClientLevel[client] == LEVEL_GOLD)
			CPrintToChatAll("%s%t", g_sChatPrefix, "Chat won lootbox item gold", name, item.szName, handler.szType);
			
		CRemoveTags(sBuffer, sizeof(sBuffer));
		PrintHintText(client, sBuffer);
	}

	if (item.bPreview && IsPlayerAlive(client))
	{
		Call_StartForward(gf_hPreviewItem);
		Call_PushCell(client);
		Call_PushString(handler.szType);
		Call_PushCell(item.iData);
		Call_Finish();
	}

	float fVec[3];
	GetClientAbsOrigin(client, fVec);
	EmitAmbientSound(g_sPickUpSound[g_iClientBox[client]], fVec, _, _, _, _, _, _);

	RequestFrame(Frame_DeleteBox, client);

	return Plugin_Handled;
}

public Action Timer_RemoveEfx(Handle timer, int reference)
{
	int iEnt = EntRefToEntIndex(reference);

	if (IsValidEdict(iEnt))
	{
		AcceptEntityInput(iEnt, "kill");
	}
}

int PrecacheParticleSystem(const char[] particleSystem)
{
	static int particleEffectNames = INVALID_STRING_TABLE;

	if (particleEffectNames == INVALID_STRING_TABLE)
	{
		if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
			return INVALID_STRING_INDEX;
	}

	int index = FindStringIndex2(particleEffectNames, particleSystem);
	if (index == INVALID_STRING_INDEX)
	{
		int numStrings = GetStringTableNumStrings(particleEffectNames);
		if (numStrings >= GetStringTableMaxStrings(particleEffectNames))
			return INVALID_STRING_INDEX;

		AddToStringTable(particleEffectNames, particleSystem);
		index = numStrings;
	}

	return index;
}

int FindStringIndex2(int tableidx, const char[] str)
{
	char buf[1024];

	int numStrings = GetStringTableNumStrings(tableidx);
	for (int i = 0; i < numStrings; i++)
	{
		ReadStringTable(tableidx, i, buf, sizeof(buf));

		if (StrEqual(buf, str))
			return i;
	}

	return INVALID_STRING_INDEX;
}

public Action Hook_SetTransmit(int ent, int client)
{
	if (g_iLootboxEntityRef[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iLootboxEntityRef[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_Color(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();

	if (g_iClientBox[client] == -1)
		return Plugin_Stop;

	int lootbox = pack.ReadCell();
	int rotator = pack.ReadCell();
	int light = pack.ReadCell();

	int index = g_iClientBox[client];
	float fPos[3];
	GetEntPropVector(lootbox, Prop_Send, "m_vecOrigin", fPos);
	fPos[2] -= 0.2;
	TeleportEntity(lootbox, fPos, NULL_VECTOR, NULL_VECTOR);
	g_iClientSpeed[client] -= 5;
	EmitAmbientSound("ui/csgo_ui_crate_item_scroll.wav", fPos, _, _, _, _, _, _);

	char sBuffer[128];
	IntToString(g_iClientSpeed[client], sBuffer, sizeof(sBuffer));
	DispatchKeyValue(rotator, "maxspeed", sBuffer);
	AcceptEntityInput(rotator, "Start");

	if (g_iClientSpeed[client] < 1)
	{

		if (g_sEfxName[g_iClientBox[client]][0])
		{
			CreateEffect(client, fPos);
		}

		CreateTimer(0.5, Timer_Open, client);

		return Plugin_Stop;
	}

	switch(g_iClientSpeed[client])
	{
		case 120:
		{
			g_hTimerColor[client] = CreateTimer(0.31, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 60:
		{
			g_hTimerColor[client] = CreateTimer(0.35, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 40:
		{
			g_hTimerColor[client] = CreateTimer(0.4, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 10:
		{
			g_hTimerColor[client] = CreateTimer(0.5, Timer_Color, pack, TIMER_REPEAT); //0.6
			return Plugin_Stop;
		}
	}
	
	float percent = GetRandomFloat(0.0001, 100.0);

	if (percent < g_fChance[index][LEVEL_GREY])
	{
		SetEntityRenderColor(lootbox, 155, 255, 255, 255);
		g_iClientLevel[client] = LEVEL_GREY;
		DispatchKeyValue(light, "_light", "155 255 255 255");
		return Plugin_Continue;
	}

	percent -= g_fChance[index][LEVEL_GREY];
	if (percent < g_fChance[index][LEVEL_BLUE])
	{
		SetEntityRenderColor(lootbox, 0, 0, 255, 255);
		DispatchKeyValue(light, "_light", "0 0 255 255");
		g_iClientLevel[client] = LEVEL_BLUE;
		return Plugin_Continue;
	}

	percent -= g_fChance[index][LEVEL_BLUE];
	if (percent < g_fChance[index][LEVEL_PURPLE])
	{
		SetEntityRenderColor(lootbox, 255, 0, 255, 255);
		DispatchKeyValue(light, "_light", "255 0 255 255");
		g_iClientLevel[client] = LEVEL_PURPLE;
		return Plugin_Continue;
	}

	percent -= g_fChance[index][LEVEL_PURPLE];
	if (percent < g_fChance[index][LEVEL_RED])
	{
		SetEntityRenderColor(lootbox, 255, 0, 0, 255);
		DispatchKeyValue(light, "_light", "255 0 0 255");
		g_iClientLevel[client] = LEVEL_RED;
		return Plugin_Continue;
	}
	

	percent -= g_fChance[index][LEVEL_RED];
	if (percent < g_fChance[index][LEVEL_GOLD])
	{
		SetEntityRenderColor(lootbox, 255, 255, 0, 255);
		DispatchKeyValue(light, "_light", "255 255 0 255");
		g_iClientLevel[client] = LEVEL_GOLD;
		return Plugin_Continue;
	}

	return Plugin_Continue;
}

void CreateEffect(int client, float fPos[3])
{
	int iEfx = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iEfx, "start_active", "0");
	DispatchKeyValue(iEfx, "effect_name", g_sEfxName[g_iClientBox[client]]);
	DispatchSpawn(iEfx);
	ActivateEntity(iEfx);
	TeleportEntity(iEfx, fPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iEfx, "Start");

	if(!gc_bVisible.BoolValue)
	{
		SDKHook(iEfx, SDKHook_SetTransmit, Hook_SetTransmit);
	}

	CreateTimer(1.5, Timer_RemoveEfx, EntIndexToEntRef(iEfx));
//	PrintToServer("fired %s", g_sEfxName[g_iClientBox[client]]);
}

public void Frame_DeleteBox(int client)
{
	if (g_iLootboxEntityRef[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iLootboxEntityRef[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iLootboxEntityRef[client] = INVALID_ENT_REFERENCE;
}

stock int GetPlayerFromOpenEntity(int entity)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i)) continue;

		if(m_iOpenProp[i] == entity) return i;
	}

	return -1;
}