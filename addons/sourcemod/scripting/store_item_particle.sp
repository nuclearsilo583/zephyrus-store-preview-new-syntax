/*
 * Store - Particle item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Totenfluch - https://github.com/Totenfluch/StoreParticleExtension
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

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <store> //https://raw.githubusercontent.com/shanapu/Store/master/scripting/include/Store.inc
//#include <zephstocks>

#include <colors> //https://raw.githubusercontent.com/shanapu/Store/master/scripting/include/colors.inc
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576

#define AURA 0
#define TRAIL 1
#define SPAWN 2
#define KILL 3
#define HIT 4

int g_iCount = 0;
int g_iEquipt[MAXPLAYERS + 1][5];
char g_sName[5][STORE_MAX_ITEMS][64];
char g_sFile[5][STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iEntity[2][MAXPLAYERS + 1];
float g_fDuration[3][STORE_MAX_ITEMS];

char g_sChatPrefix[128];

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

int g_iType[STORE_MAX_ITEMS];
int g_iIndexType[STORE_MAX_ITEMS];

public Plugin myinfo = 
{
	name = "Store - Particle item module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.1", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	Store_RegisterHandler("particle", "particle", OnMapStart_Particle, Reset_Particle, Config_Particle, Equip_Particle, UnEquip_Particle, true);


	LoadTranslations("store.phrases");

	RegConsoleCmd("sm_hideparticle", Command_Hide, "Hides the Particles");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("bullet_impact", Event_BulletImpact);

	g_hHideCookie = RegClientCookie("Particle_Hide_Cookie", "Cookie to check if Particles are blocked", CookieAccess_Private);
	
	SetCookieMenuItem(PrefMenu, 0, "");
	for (int i = 1; i <= MaxClients; i++)
	{
		for (int j = 0; j < 5; j++)
		{
			g_iEquipt[i][j] = -1;
		}

		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		switch(g_bHide[client])
		{
			case false: FormatEx(buffer, maxlen, "Hide Shop Particle: Disabled");
			case true: FormatEx(buffer, maxlen, "Hide Shop Particle: Enabled");
		}
	}

	if (actions == CookieMenuAction_SelectOption)
	{
		//ClientCommand(client, "sm_hideparticle");
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
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "particle");
		}
		case true:
		{
			g_bHide[client] = false;
			IntToString(0, sCookieValue, sizeof(sCookieValue));
			SetClientCookie(client, g_hHideCookie, sCookieValue);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "particle");
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "particle");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "particle");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	g_iEntity[AURA][client] = 0;
	g_iEntity[TRAIL][client] = 0;

	g_bHide[client] = false;

	for (int i = 0; i < 5; i++)
	{
		g_iEquipt[client][i] = -1;
	}

	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}
}

public void Reset_Particle()
{
	g_iCount = 0;
}

public bool Config_Particle(KeyValues &kv, int itemid)
{

	char sBuffer[32];
	int type = -1;

	kv.GetString("slot", sBuffer, sizeof(sBuffer));
	if (StrEqual(sBuffer,"aura", false))
	{
		type = AURA;
	}
	else if (StrEqual(sBuffer,"trail", false))
	{
		type = TRAIL;
	}
	else if (StrEqual(sBuffer,"spawn", false))
	{
		type = SPAWN;
		g_fDuration[SPAWN - 2][g_iCount] = kv.GetFloat("duration", 1.5);
	}
	else if (StrEqual(sBuffer,"kill", false))
	{
		type = KILL;
		g_fDuration[KILL - 2][g_iCount] = kv.GetFloat("duration", 1.5);
	}
	else if (StrEqual(sBuffer,"hit", false))
	{
		type = HIT;
		g_fDuration[HIT - 2][g_iCount] = kv.GetFloat("duration", 1.5);
	}

	if (type == -1)
	{
		kv.GetString("name", sBuffer, sizeof(sBuffer));
		//Store_LogMessage(0, LOG_ERROR, "Particle '%s' - unknown type (must be aura,trail,spawn,kill or hit)", sBuffer);
		return false;
	}

	Store_SetDataIndex(itemid, g_iCount);

	g_iType[itemid] = type;
	g_iIndexType[g_iCount] = type;

	kv.GetString("name", g_sName[type][g_iCount], 64);
	kv.GetString("file", g_sFile[type][g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sFile[type][g_iCount], true))
	{
		//Store_LogMessage(0, LOG_ERROR, "Can't find particle file %s.", g_sFile[type][g_iCount]);
		return false;
	}

	g_iCount++;
	return true;
}

public void OnMapStart_Particle()
{
	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheParticleSystem(g_sName[g_iIndexType[i]][i]);

		Downloader_AddFileToDownloadsTable(g_sFile[g_iIndexType[i]][i]);

	//	if (IsGenericPrecached(g_sFile[g_iIndexType[i]][i])) // why this won't work
	//		continue;

		PrecacheGeneric(g_sFile[g_iIndexType[i]][i], true);
	}
}

public int Equip_Particle(int client, int itemid)
{
	switch(g_iType[itemid])
	{
		case AURA, TRAIL:
		{
			Remove_Particle(client, g_iType[itemid]);

			g_iEquipt[client][g_iType[itemid]] = Store_GetDataIndex(itemid);

			Set_Particle(client, g_iType[itemid]);
		}
		default:
		{
			g_iEquipt[client][g_iType[itemid]] = Store_GetDataIndex(itemid);
		}
	}

	return g_iType[itemid];
}

public int UnEquip_Particle(int client, int itemid)
{
	switch(g_iType[itemid])
	{
		case AURA,TRAIL:
		{
			Remove_Particle(client, g_iType[itemid]);

			g_iEquipt[client][g_iType[itemid]] = -1;
		}
		default:
		{
			g_iEquipt[client][g_iType[itemid]] = -1;
		}
	}

	return g_iType[itemid];
}


public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	Remove_Particle(client, AURA);
	Remove_Particle(client, TRAIL);

	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (client == attacker)
		return;

	if (g_iEquipt[attacker][KILL] == -1)
		return;

	float pos[3];
	GetClientAbsOrigin(client, pos);

	int iParticle = CreateEntityByName("info_particle_system");

	DispatchKeyValue(iParticle, "start_active", "0");
	DispatchKeyValue(iParticle, "effect_name", g_sName[KILL][g_iEquipt[attacker][KILL]]);
	DispatchSpawn(iParticle);
	ActivateEntity(iParticle);
	TeleportEntity(iParticle, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iParticle, "Start");

	CreateTimer(g_fDuration[KILL - 2][g_iEquipt[attacker][KILL]], Timer_ClearParticle, EntIndexToEntRef(iParticle));
}

public void Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (g_iEquipt[client][HIT] == -1)
		return;
	
	int[] clients = new int[MaxClients + 1];
	int numClients = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (g_bHide[i])
			continue;

		clients[numClients] = i;
		numClients++;
	}
	
	if (numClients < 1)
		return;
	
	float pos[3];
	pos[0] = event.GetFloat("x");
	pos[1] = event.GetFloat("y");
	pos[2] = event.GetFloat("z");

	int iParticle = CreateEntityByName("info_particle_system");

	DispatchKeyValue(iParticle, "start_active", "0");
	DispatchKeyValue(iParticle, "effect_name", g_sName[HIT][g_iEquipt[client][HIT]]);
	DispatchSpawn(iParticle);
	ActivateEntity(iParticle);
	TeleportEntity(iParticle, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iParticle, "Start");

	CreateTimer(g_fDuration[HIT - 2][g_iEquipt[client][HIT]], Timer_ClearParticle, EntIndexToEntRef(iParticle));
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	Set_Particle(client, AURA);
	Set_Particle(client, TRAIL);

	if (g_iEquipt[client][SPAWN] == -1)
		return;

	float pos[3];
	GetClientAbsOrigin(client, pos);

	int iParticle = CreateEntityByName("info_particle_system");

	DispatchKeyValue(iParticle, "start_active", "0");
	DispatchKeyValue(iParticle, "effect_name", g_sName[SPAWN][g_iEquipt[client][SPAWN]]);
	DispatchSpawn(iParticle);
	ActivateEntity(iParticle);
	TeleportEntity(iParticle, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iParticle, "Start");

	CreateTimer(g_fDuration[SPAWN - 2][g_iEquipt[client][SPAWN]], Timer_ClearParticle, EntIndexToEntRef(iParticle));
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iEntity[AURA][i] = 0;
		g_iEntity[TRAIL][i] = 0;
	}
}

void Set_Particle(int client, int slot)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	Remove_Particle(client, slot);

	if (g_iEquipt[client][slot] == -1)
		return;

	float clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);

	int iParticle = CreateEntityByName("info_particle_system");

	DispatchKeyValue(iParticle, "start_active", "0");
	DispatchKeyValue(iParticle, "effect_name", g_sName[slot][g_iEquipt[client][slot]]);
	DispatchSpawn(iParticle);
	TeleportEntity(iParticle, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	ActivateEntity(iParticle);
	SetVariantString("!activator");

	AcceptEntityInput(iParticle, "SetParent", client, iParticle, 0);

	CreateTimer(0.1, Timer_Enable_Particle, iParticle);

	g_iEntity[slot][client] = iParticle;
}


public Action Timer_Enable_Particle(Handle tmr, int ent)
{
	if (ent > 0 && IsValidEntity(ent))
	{
		AcceptEntityInput(ent, "Start");

		Set_EdictFlags(ent);

		SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

public Action Hook_SetTransmit(int entity, int client)
{
	Set_EdictFlags(entity);

	return g_bHide[client] ? Plugin_Handled : Plugin_Continue;
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

void Remove_Particle(int client, int slot)
{
	if (g_iEntity[slot][client] != 0)
	{
		if (IsClientInGame(client))
		{
			if (IsValidEdict(g_iEntity[slot][client]))
			{
				SDKUnhook(g_iEntity[slot][client], SDKHook_SetTransmit, Hook_SetTransmit);
				AcceptEntityInput(g_iEntity[slot][client], "Kill");
			}
		}
		g_iEntity[slot][client] = 0;
	}
}

public Action Timer_ClearParticle(Handle timer, int reference)
{
	int entity = EntRefToEntIndex(reference);

	if (entity > 0 && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
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
	for (int i=0; i < numStrings; i++)
	{
		ReadStringTable(tableidx, i, buf, sizeof(buf));
		
		if (StrEqual(buf, str))
		{
			return i;
		}
	}

	return INVALID_STRING_INDEX;
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (StrContains(type, "particle") == -1)
		return;

	int iPreview = CreateEntityByName("info_particle_system");

	DispatchKeyValue(iPreview, "start_active", "0");
	DispatchKeyValue(iPreview, "effect_name", g_sName[g_iIndexType[index]][index]);
	DispatchSpawn(iPreview);
	ActivateEntity(iPreview);
	AcceptEntityInput(iPreview, "Start");

	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fPosition[2] += 25;

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