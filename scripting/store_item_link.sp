/*
 * MyStore - Link item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits:
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

#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

int g_iCount = 0;

char g_sCommand[STORE_MAX_ITEMS][64];

public Plugin myinfo = 
{
	name = "Store - Link item module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Origin code is from Shanapu - I just edit to be compaitble with Zephyrus Store",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	Store_RegisterHandler("link", "link", _, Commands_Reset, Commands_Config, Commands_Equip, _, false,true);
}

public void Commands_Reset()
{
	g_iCount = 0;
}

public bool Commands_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCount);

	kv.GetString("command", g_sCommand[g_iCount], 64);

	g_iCount++;

	return true;
}

public int Commands_Equip(int client, int itemid)
{
	int iIndex = Store_GetDataIndex(itemid);

	char sCommand[256];
	strcopy(sCommand, sizeof(sCommand), g_sCommand[iIndex]);

	FakeClientCommandEx(client, sCommand);

	return 0;
}