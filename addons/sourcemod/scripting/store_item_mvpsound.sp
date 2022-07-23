/*
 * MyStore - MVP sound item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: rogeraabbccdd - https://forums.alliedmods.net/showthread.php?p=2514835
 * Contributer:
 *
 * Original development by Zephyrus - https://github.com/dvarnai/store-plugin
 *
 * Porting from MyStore compatible with origin edited Zephyrus Store with repreview system
 * By: nuclear silo
 * 
 * Love goes out to the sourcemod team and all other plugin developers!
 * THANKS FOR MAKING FREE SOFTWARE!
 *
 * This file is part of the MyStore SourceMod Plugin.
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
#include <clientprefs>

#include <store>
#include <zephstocks>

#include <multicolors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

/*
 * The percentage step between volume choices in the cookie menu (!settings).
 * 1.0 represent 100% volume and 0.0 represents 0% volume. Thus, 0.2 is a 20% step.
 * It is recommended to keep a value that allows the player to set their max volume to 0.0 (so they can mute MVP Sounds if they want to).
 */
#define VOLUME_COOKIE_STEP 0.2 

char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
float g_fVolume[STORE_MAX_ITEMS];
int g_iEquipt[MAXPLAYERS + 1] = {-1, ...};

char g_sChatPrefix[128];

int g_iCount = 0;

float g_fPlayerVolume[MAXPLAYERS + 1] = {1.0, ...};
Cookie g_hHideCookie;

public Plugin myinfo = 
{
	name = "Store - MVP sound item module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Allows players to buy custom MVP sounds. Original code from Shanapu, edited to be compatible with Zephyrus Store",
	version = "1.3", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/nuclearsilo583/zephyrus-store-preview-new-syntax"
};

public void OnPluginStart()
{
	Store_RegisterHandler("mvp_sound", "sound", MVPSounds_OnMapStart, MVPSounds_Reset, MVPSounds_Config, MVPSounds_Equip, MVPSounds_Remove, true);
	
	g_hHideCookie = new Cookie("MVPSound_Volume_Cookie", "Cookie to set the volume of MVP sounds", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "");

	LoadTranslations("store.phrases");

	HookEvent("round_mvp", Event_RoundMVP);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	g_hHideCookie.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0') // If the string is empty, it means that the user has not changed their volume. Don't do anything.
		return;
	
	g_fPlayerVolume[client] = StringToFloat(sValue);
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlen, "MVP Volume: %i%%", RoundToNearest(g_fPlayerVolume[client] * 100)); // Rounding because we never know
	}
	else if (actions == CookieMenuAction_SelectOption)
	{
		CMD_Volume(client);
		ShowCookieMenu(client);
	}
}

void CMD_Volume(int client)
{
	char sCookieValue[8];
	
	g_fPlayerVolume[client] = g_fPlayerVolume[client] - VOLUME_COOKIE_STEP;
	
	if (g_fPlayerVolume[client] < 0.0)
		g_fPlayerVolume[client] = 1.0;
	
	FloatToString(g_fPlayerVolume[client], sCookieValue, sizeof(sCookieValue));
	g_hHideCookie.Set(client, sCookieValue);
	
	char buffer[20];
	FormatEx(buffer, sizeof(buffer), "%i%%", RoundToNearest(g_fPlayerVolume[client] * 100));
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Volume set", "MVP", buffer);
}

public void MVPSounds_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheSound(g_sSound[i], true);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void MVPSounds_Reset()
{
	g_iCount = 0;
}

public bool MVPSounds_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCount);

	kv.GetString("sound", g_sSound[g_iCount], PLATFORM_MAX_PATH);

	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[g_iCount]);

	g_fVolume[g_iCount] = kv.GetFloat("volume", 0.5);

	if (g_fVolume[g_iCount] > 1.0)
	{
		g_fVolume[g_iCount] = 1.0;
	}

	if (g_fVolume[g_iCount] <= 0.0)
	{
		g_fVolume[g_iCount] = 0.05;
	}

	g_iCount++;

	return true;
}

public int MVPSounds_Equip(int client, int itemid)
{
	g_iEquipt[client] = Store_GetDataIndex(itemid);

	return 0;
}

public int MVPSounds_Remove(int client, int itemid)
{
	g_iEquipt[client] = -1;

	return 0;
}

public void OnClientDisconnect(int client)
{
	g_iEquipt[client] = -1;
	g_fPlayerVolume[client] = 1.0;
}


public void Event_RoundMVP(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	if (g_iEquipt[client] == -1)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		//if (g_bHide[client])
		//	continue;

		ClientCommand(i, "playgamesound Music.StopAllMusic");

		if (RoundToNearest(g_fPlayerVolume[i] * 100) != 0) // Rounded because computers struggle with floats and precise values
			EmitSoundToClient(i, g_sSound[g_iEquipt[client]], SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, g_fVolume[g_iEquipt[client]] * g_fPlayerVolume[i]);
	}
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "mvp_sound"))
		return;

	if (RoundToNearest(g_fPlayerVolume[client] * 100) != 0) // Rounded because computers struggle with floats and precise values
		EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] * g_fPlayerVolume[client]);
	else
		EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] * VOLUME_COOKIE_STEP); // Set to the step right above 0%

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Play Preview", client);
}