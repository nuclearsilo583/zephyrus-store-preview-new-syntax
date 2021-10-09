/*
 * Store - Info panel item module
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

#include <store>

char g_sInfoTitle[STORE_MAX_ITEMS][256];
char g_sInfo[STORE_MAX_ITEMS][256];

int g_iCount = 0;

public Plugin myinfo = 
{
	name = "Store - Info panel item module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.1", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	Store_RegisterHandler("info","text", _, Info_Reset, Info_Config, Info_Equip, _, false, true);

	LoadTranslations("store.phrases");
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void Info_Reset()
{
	g_iCount = 0;
}

public bool Info_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCount);

	kv.GetSectionName(g_sInfoTitle[g_iCount], sizeof(g_sInfoTitle[]));
	kv.GetString("text", g_sInfo[g_iCount], sizeof(g_sInfo[]));

	ReplaceString(g_sInfo[g_iCount], sizeof(g_sInfo[]), "\\n", "\n");

	g_iCount++;

	return true;
}

public void Info_Equip(int client, int itemid)
{
	int iIndex = Store_GetDataIndex(itemid);

	Panel panel = new Panel();
	panel.SetTitle(g_sInfoTitle[iIndex]);

	panel.DrawText(g_sInfo[iIndex]);

	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.CurrentKey = 7;
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER);
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.CurrentKey = 9;
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, PanelHandler_Info, MENU_TIME_FOREVER);
}

public int PanelHandler_Info(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 7)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
}