/*
 * Store - Discount module
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

#include <colors> //https://raw.githubusercontent.com/shanapu/Store/master/scripting/include/colors.inc
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#define MAX_DISCOUNTS 32
#define MAX_DISCOUNTS_EXCLUDES 16

char g_sName[MAX_DISCOUNTS][32];
char g_sTime[MAX_DISCOUNTS][32];
char g_sType[MAX_DISCOUNTS][32];
char g_sItem[MAX_DISCOUNTS][32];
char g_sDiscount[MAX_DISCOUNTS][32];
bool g_bNoMsg[MAX_DISCOUNTS];
bool g_bNoPlan[MAX_DISCOUNTS];
int g_iExcludes[MAX_DISCOUNTS];
int g_iFlagBits[MAX_DISCOUNTS];
int g_iMinPlayer[MAX_DISCOUNTS];

bool g_bActive[MAX_DISCOUNTS];
bool g_bAnnounced[MAX_DISCOUNTS][MAXPLAYERS + 1];

char g_sExcludeType[MAX_DISCOUNTS][MAX_DISCOUNTS_EXCLUDES][32];
char g_sExcludeItem[MAX_DISCOUNTS][MAX_DISCOUNTS_EXCLUDES][32];

char g_sChatPrefix[128];
char g_sCreditsName[64];

static char dateformat[5][] = {"%M", // minute 00-59
							  "%H", // hour 00-23
							  "%d", // day in month 01-31
							  "%m", // month 01-12
							  "%w"};// day in week 0-6

int g_iClientCount;
int g_iCount;

ConVar gc_bEnable;
ConVar gc_bAddDiscount;

public Plugin myinfo = 
{
	name = "Store - Discount module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");

	AutoExecConfig_SetFile("discount", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_bAddDiscount = AutoExecConfig_CreateConVar("store_discount_add", "0", "0 - Only the highest discount is granted / 1 - add all active discounts together", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	LoadConfig();
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void OnMapStart()
{
	CreateTimer(60.0, Timer_CheckDiscount, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, Timer_CheckDiscount);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	for (int i = 0; i < g_iCount; i++)
	{
		g_bAnnounced[i][client] = false;
	}

	CreateTimer(5.0, Timer_Announce, GetClientUserId(client));
	g_iClientCount++;
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;

	g_iClientCount--;
}

public Action Timer_Announce(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	for (int i = 0; i < g_iCount; i++)
	{
		if (g_bNoMsg[i])
			continue;

		if (g_bAnnounced[i][client])
			continue;

		if (!CheckFlagBits(client, g_iFlagBits[i]))
			continue;

		if (g_iClientCount < g_iMinPlayer[i])
			continue;

		if (!IsInTime(g_sTime[i]))
			continue;

		g_bAnnounced[i][client] = true;
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Discount Active", g_sName[i]);
	}

	return Plugin_Handled;
}

// MyLittleCrony
public Action Timer_CheckDiscount(Handle timer)
{

	for (int i = 0; i < g_iCount; i++)
	{
		if (g_iClientCount < g_iMinPlayer[i])
			continue;

		bool active = IsInTime(g_sTime[i]);

		if (active && !g_bActive[i])
		{
			g_bActive[i] = true;
			//Store_LogMessage(0, LOG_EVENT, "Discount Started: %s", g_sName[i]);

			if (g_bNoMsg[i])
				continue;

			for (int j = 1; j <= MaxClients; j++)
			{
				if (!IsClientInGame(j) || g_bAnnounced[i][j])
					continue;

				if (!CheckFlagBits(j, g_iFlagBits[i]))
					continue;

				CPrintToChat(j, "%s%t", g_sChatPrefix, "Discount Started", g_sName[i]);
				g_bAnnounced[i][j] = true;
			}
		}
		else if (!active && g_bActive[i])
		{
			g_bActive[i] = false;
			//Store_LogMessage(0, LOG_EVENT, "Discount Ended: %s", g_sName[i]);

			if (g_bNoMsg[i])
				continue;

			for (int j = 1; j <= MaxClients; j++)
			{
				if (!IsClientInGame(j) || !g_bAnnounced[i][j])
					continue;

				if (!CheckFlagBits(j, g_iFlagBits[i]))
					continue;

				CPrintToChat(j, "%s%t", g_sChatPrefix, "Discount Ended", g_sName[i]);
				g_bAnnounced[i][j] = false;
			}
		}
	}

	return Plugin_Continue;
}

public Action Store_OnGetEndPrice(int client, int itemid, int &price)
{
	float singleDiscount = 0.0;
	float sumDiscount = 0.0;

	for (int i = 0; i < g_iCount; i++)
	{
		if (g_iClientCount < g_iMinPlayer[i])
			continue;

		if (!CheckFlagBits(client, g_iFlagBits[i]))
			continue;

		if (!IsInTime(g_sTime[i]))
			continue;

		any item[Store_Item];
		Store_GetItem(itemid, item);

		any handler[Type_Handler];
		Store_GetHandler(item[iHandler], handler);

		if (g_bNoPlan[i] && item[iPlans] != 0)
			continue;

		bool exluded = false;
		for (int j = 0; j < g_iExcludes[i]; j++)
		{
			if (StrEqual(g_sExcludeType[i][j], handler[szType]) || StrEqual(g_sExcludeItem[i][j], item[szUniqueId]))
			{
				exluded = true;
			}
		}
		if (exluded)
			continue;

		if (StrEqual(g_sType[i], "all") || StrEqual(g_sItem[i], "all") || StrEqual(g_sItem[i], item[szUniqueId]) || StrEqual(g_sType[i], handler[szType]))
		{
			if (StrContains(g_sDiscount[i], "%") != -1)
			{
				char sBuffer[32];
				strcopy(sBuffer, sizeof(sBuffer), g_sDiscount[i]);
				ReplaceString(sBuffer, sizeof(sBuffer), "%", "");
				singleDiscount += price * (StringToInt(sBuffer) / 100.0);
			}
			else
			{
				singleDiscount += StringToInt(g_sDiscount[i]);
			}

			if (gc_bAddDiscount.BoolValue)
			{
				sumDiscount += singleDiscount;
			}
			else if (sumDiscount < singleDiscount)
			{
				sumDiscount = singleDiscount;
			}
		}
	}

	if (sumDiscount != 0)
	{
		price -= RoundToCeil(sumDiscount);

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

bool IsInTime(char[] time) //  "* 13-15 * * *" M H D M W  =  everyday from 13-15h
{
	char times[5][8];
	char start[5][8];
	char end[5][8];
	char now[8];

	ExplodeString(time, " ", times, sizeof(times), sizeof(times[]));

	for (int i = 0; i < 5; i++)
	{
		char timeEx[2][8];
		ExplodeString(times[i], "-", timeEx, sizeof(timeEx), sizeof(timeEx[]));
		strcopy(start[i], sizeof(start), timeEx[0]);
		strcopy(end[i], sizeof(end), timeEx[1]);

		FormatTime(now, sizeof(now), dateformat[i]);
		if (!(StringToInt(start[i]) <= StringToInt(now) <= StringToInt(end[i])) && !StrEqual(times[i], "*"))
			return false;
	}

	return true;
}

void LoadConfig()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/store/discount.txt");
	KeyValues kv = new KeyValues("Discount");
	kv.ImportFromFile(sFile);
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("Failed to read configs/store/discount.txt");
	}

	GoThroughConfig(kv);
	delete kv;
}

void GoThroughConfig(KeyValues &kv)
{
	char sBuffer[64];

	g_iCount = 0;

	do
	{
		// We reached the max amount of items so break and don't add any more items
		if (g_iCount == MAX_DISCOUNTS)
			break;

		kv.GetSectionName(g_sName[g_iCount], 64);

		kv.GetString("flags", sBuffer, sizeof(sBuffer), "");
		g_iFlagBits[g_iCount] = ReadFlagString(sBuffer);

		kv.GetString("time", g_sTime[g_iCount], 64, "");
		kv.GetString("type", g_sType[g_iCount], 64, "");
		kv.GetString("item", g_sItem[g_iCount], 64, "");
		kv.GetString("discount", g_sDiscount[g_iCount], 64, "");
		g_iMinPlayer[g_iCount] = kv.GetNum("player", 0);
		g_bNoPlan[g_iCount] = kv.GetNum("noplans", 0) ? true : false;
		g_bNoMsg[g_iCount] = kv.GetNum("nomsg", 0) ? true : false;

		// Has the Discount any excludes?
		if (kv.JumpToKey("Exclude"))
		{
			kv.GotoFirstSubKey();
			int index = 0;
			do
			{
				kv.GetString("type", g_sExcludeType[g_iCount][index], 64);
				kv.GetString("item", g_sExcludeItem[g_iCount][index], 64);
				index++;
			}
			while kv.GotoNextKey();

			g_iExcludes[g_iCount] = index;

			kv.GoBack();
		}

		g_iCount++;
	}
	while kv.GotoNextKey();
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}

	return false;
}