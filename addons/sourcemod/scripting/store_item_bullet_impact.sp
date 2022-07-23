/*
 * Store - Bullet impact item module
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
#include <clientprefs>

#include <store> 

#include <multicolors>
#include <smartdm>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072

bool g_bEquipt[MAXPLAYERS + 1] = {false, ...};

char g_sPaintballDecals[STORE_MAX_ITEMS][32][PLATFORM_MAX_PATH];

//ConVar gc_bEnable;

int g_iPaintballDecalIDs[STORE_MAX_ITEMS][32];
int g_iPaintballDecals[STORE_MAX_ITEMS] = {0, ...};
int g_iCount = 0;

bool g_bHide[MAXPLAYERS + 1];
Cookie g_hHideCookie;

char g_sChatPrefix[128];


public Plugin myinfo = 
{
	name = "Store - Bullet impact item module",
	author = "shanapu, nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.4", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	Store_RegisterHandler("paintball","bullet", Paintball_OnMapStart, Paintball_Reset, Paintball_Config, Paintball_Equip, Paintball_Remove, true);

	LoadTranslations("store.phrases");

	RegConsoleCmd("sm_hidepaintball", Command_Hide, "Hide the Paintball");

	HookEvent("bullet_impact", Event_BulletImpact);

	g_hHideCookie = new Cookie("Paintball_Hide_Cookie", "Cookie to check if Paintball are blocked", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "");
	for (int i = 1; i <= MaxClients; i++)
	{
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
		if (g_bHide[client])
			FormatEx(buffer, maxlen, "%T", "Show paintball", client);
		else
			FormatEx(buffer, maxlen, "%T", "Hide paintball", client);
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "paintball");
		g_hHideCookie.Set(client, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "paintball");
		g_hHideCookie.Set(client, "0");
	}

	return Plugin_Handled;
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Paintball_OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	for (int a = 0; a < g_iCount; a++)
	{
		for (int i = 0; i < g_iPaintballDecals[a]; i++)
		{
			g_iPaintballDecalIDs[a][i] = PrecacheDecal(g_sPaintballDecals[a][i], true);
			Format(sBuffer, sizeof(sBuffer), "materials/%s", g_sPaintballDecals[a][i]);
			Downloader_AddFileToDownloadsTable(sBuffer);
		}
	}
}

public void Paintball_Reset()
{
	for (int i = 0; i < g_iCount; i++)
	{
		g_iPaintballDecals[i] = 0;
	}

	g_iCount = 0;
}

public bool Paintball_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCount);

	kv.JumpToKey("Decals");
	kv.GotoFirstSubKey();

	do
	{
		kv.GetString("material", g_sPaintballDecals[g_iCount][g_iPaintballDecals[g_iCount]], PLATFORM_MAX_PATH);
		g_iPaintballDecals[g_iCount]++;
	}
	while (kv.GotoNextKey());

	kv.GoBack();
	kv.GoBack();

	g_iCount++;

	return true;
}

public int Paintball_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return 0;
}

public int Paintball_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return 0;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int m_iEquipped = Store_GetEquippedItem(client, "paintball");
	if (!g_bEquipt[client])
		return;
	if (m_iEquipped > 0)
	{
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

		int iIndex = Store_GetDataIndex(m_iEquipped);

		float fImpact[3];
		fImpact[0] = event.GetFloat("x");
		fImpact[1] = event.GetFloat("y");
		fImpact[2] = event.GetFloat("z");

		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin", fImpact);
		TE_WriteNum("m_nIndex", g_iPaintballDecalIDs[iIndex][GetRandomInt(0, g_iPaintballDecals[iIndex]-1)]);

		TE_Send(clients, numClients, 0.0);
	}
}