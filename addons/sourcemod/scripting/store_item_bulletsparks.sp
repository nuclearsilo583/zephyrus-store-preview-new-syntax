/*
 * Store - Bulletsparks item module
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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

#include <store> 

char g_sChatPrefix[128];


bool g_bEquipt[MAXPLAYERS + 1] = {false, ...};

bool g_bHide[MAXPLAYERS + 1];
Cookie g_hHideCookie;

public Plugin myinfo = 
{
	name = "Store - Bulletsparks item module",
	author = "shanapu, nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.3", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	Store_RegisterHandler("bulletsparks","bullet", _, _, BulletSparks_Config, BulletSparks_Equip, BulletSparks_Remove, true);

	HookEvent("bullet_impact", Event_BulletImpact);
	
	LoadTranslations("store.phrases");
	
	RegConsoleCmd("sm_hidebulletspark", Command_Hide, "Hide the Tracer");
	RegConsoleCmd("sm_hidebulletsparks", Command_Hide, "Hide the Tracer");
	
	g_hHideCookie = new Cookie("Hide_Bullet_Spark", "Hide Bullet Spark", CookieAccess_Protected);
	
	SetCookieMenuItem(PrefMenu, 0, "");
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		if (g_bHide[client])
			FormatEx(buffer, maxlen, "%T", "Show bullet sparks", client);
		else
			FormatEx(buffer, maxlen, "%T", "Hide bullet sparks", client);
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "bulletsparks");
		g_hHideCookie.Set(client, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "bulletsparks");
		g_hHideCookie.Set(client, "0");
	}

	return Plugin_Handled;
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public bool BulletSparks_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, 0);

	return true;
}

public int BulletSparks_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return 0;
}

public int  BulletSparks_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return 0;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_BulletImpact(Event event, char[] sName, bool bDontBroadcast)
{

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	if (!g_bEquipt[client])
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
	
	float startpos[3];
	float dir[3] = {0.0, 0.0, 0.0};

	startpos[0] = event.GetFloat("x");
	startpos[1] = event.GetFloat("y");
	startpos[2] = event.GetFloat("z");

	TE_SetupSparks(startpos, dir, 2500, 5000);

	//TE_SendToAll();
	TE_Send(clients, numClients, 0.0);
}