/*
 * MyStore - Jackpot gamble module
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

#include <store>
#include <zephstocks>

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

ConVar gc_fTime;
ConVar gc_iPause;
ConVar gc_iMin;
ConVar gc_iMax;
ConVar gc_iFee;

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

ArrayList g_hJackPot;
Handle g_hTimer;
bool g_bActive = false;
bool g_bUsed[MAXPLAYERS + 1] = {false, ...};
int g_iBet[MAXPLAYERS + 1] = {0, ...};
int g_iPause = 0;
int g_iPlayer = 0;

public Plugin myinfo = 
{
	name = "Store - Jackpot gamble module",
	author = "shanapu, nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Origin code is from Shanapu - I just edit to be compaitble with Zephyrus Store",
	version = "1.3", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_jackpot", Command_JackPot, "Open the jackpot menu and/or set a bet");

	AutoExecConfig_SetFile("gamble", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_fTime = AutoExecConfig_CreateConVar("store_jackpot_time", "60", "how many seconds should the game run until we find a winner?", _, true, 10.0);
	gc_iPause = AutoExecConfig_CreateConVar("store_jackpot_cooldown", "120", "how many seconds should we wait until new game is availble?", _, true, 10.0);
	gc_iMin = AutoExecConfig_CreateConVar("store_jackpot_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_iMax = AutoExecConfig_CreateConVar("store_jackpot_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);
	gc_iFee = AutoExecConfig_CreateConVar("store_jackpot_fee", "5", "The fee in percent that the casino retains from the winpot", _, true, 0.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_hJackPot = new ArrayList();
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public void OnMapStart()
{
	g_hJackPot.Clear();
}

void Panel_JackPot(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "jackpot","Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	if (g_iPause > GetTime())
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot paused");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "%t", "You can start a new Jackpot");
		panel.DrawText(sBuffer);

		SecToTime(g_iPause - GetTime(), sBuffer, sizeof(sBuffer));
		Format(sBuffer, sizeof(sBuffer), "%t", "in x time", sBuffer);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
	}
	else if (!g_bActive)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "No active Jackpot");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Type in chat !jackpot", "or use buttons below");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot: x Credits", g_hJackPot.Length, g_sCreditsName);
		panel.DrawText(sBuffer);

		if (g_bUsed[client])
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Your Bet - Chance", g_iBet[client], g_sCreditsName, GetChance(client));
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");

		for (int i = 0; i <= MaxClients; i++)
		{
			if (!IsValidClient(i, false, true) || !g_bUsed[i])
				continue;

			if (client == i)
				continue;

			Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot chances", i, GetChance(i), g_iBet[i], g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");

		if (!g_bUsed[client])
		{
			Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Type in chat !jackpot", "or use buttons below");
			panel.DrawText(sBuffer);
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 4;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 5;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, PanelHandler_Info, 5);
}

void SetBet(int client, int bet)
{
	g_bUsed[client] = true;
	g_iBet[client] = bet;
	g_iPlayer++;

	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
	Store_SetClientCredits(client, Store_GetClientCredits(client) - bet);

	int iAccountID = GetSteamAccountID(client, true);
	for (int i = 0; i < bet; i++)
	{
		g_hJackPot.Push(iAccountID);
	}

	if (!g_bActive)
	{
		g_bActive = true;
		delete g_hTimer;
		g_hTimer = CreateTimer(gc_fTime.FloatValue, Timer_EndJackPot, TIMER_FLAG_NO_MAPCHANGE);
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player opened jackpot", client, bet, g_sCreditsName);
		char sBuffer[64];
		SecToTime(RoundFloat(gc_fTime.FloatValue), sBuffer, sizeof(sBuffer));
		CPrintToChatAll("%s%t", g_sChatPrefix, "the prize will be drawn in", sBuffer);
	}
	else
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player added to jackpot", client, bet, g_sCreditsName, GetChance(client), g_hJackPot.Length, g_sCreditsName);
		for (int i = 0; i <= MaxClients; i++)
		{
			if (!IsValidClient(i, false, true) || !g_bUsed[i])
				continue;

			CPrintToChat(i, "%s%t", g_sChatPrefix, "Your current winning chance has changed", GetChance(i));
		}
	}

	Panel_JackPot(client);
}

float GetChance(int client)
{
	return float(g_iBet[client]) / float(g_hJackPot.Length) * 100.0;
}

public int PanelHandler_Info(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		int credits = Store_GetClientCredits(client);
		switch(param2)
		{
			case 3: SetBet(client, gc_iMin.IntValue);
			case 4: SetBet(client, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits);
			case 5: SetBet(client, GetRandomInt(gc_iMin.IntValue, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits));
			case 7:
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete menu;
}

public Action Command_JackPot(int client, int args)
{
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (g_iPause > GetTime())
	{
		char sBuffer[64];
		SecToTime(g_iPause - GetTime(), sBuffer, sizeof(sBuffer));
		CPrintToChat(client, "%s%t %t", g_sChatPrefix, "Jackpot paused", "You can start a new Jackpot in", sBuffer);

		return Plugin_Handled;
	}

	Panel_JackPot(client);

	if (g_bUsed[client])
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You already cashed in", g_iBet[client], g_sCreditsName, GetChance(client), g_hJackPot.Length, g_sCreditsName);

		return Plugin_Handled;
	}

	if (args != 1)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !jackpot");

		return Plugin_Handled;
	}

	char sBuffer[32];
	GetCmdArg(1, sBuffer, 32);
	int iBet;
	int iCredits = Store_GetClientCredits(client);

	if (IsCharNumeric(sBuffer[0]))
	{
		iBet = StringToInt(sBuffer);
	}
	else if (StrEqual(sBuffer,"all"))
	{
		iBet = iCredits;
	}
	else if (StrEqual(sBuffer,"half"))
	{
		iBet = RoundFloat(iCredits / 2.0);
	}
	else if (StrEqual(sBuffer,"third"))
	{
		iBet = RoundFloat(iCredits / 3.0);
	}
	else if (StrEqual(sBuffer,"quater"))
	{
		iBet = RoundFloat(iCredits / 4.0);
	}

	if (iBet < gc_iMin.IntValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You have to spend at least x credits", gc_iMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_iMax.IntValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You can't spend that much credits", gc_iMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}

	SetBet(client, iBet);

	return Plugin_Handled;
}

public Action Timer_EndJackPot(Handle timer)
{
	g_hTimer = null;

	PayOut_JackPot();

	return Plugin_Stop;
}

public void OnMapEnd()
{
	if (!g_bActive)
		return;

	delete g_hTimer;

	PayOut_JackPot();
}


public void OnPluginEnd()
{
	if (!g_bActive)
		return;

	delete g_hTimer;

	PayOut_JackPot();
}


int GetClientOfSteamAccountID(int accountID)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, true))
			continue;

		if (accountID == GetSteamAccountID(i, true))
		{
			return i;
		}
	}

	return -1;
}

void PayOut_JackPot()
{
	int jackpot = g_hJackPot.Length;
	int winner_accountID = g_hJackPot.Get(GetRandomInt(0, jackpot - 1));
	int winner = GetClientOfSteamAccountID(winner_accountID);

	if (g_iPlayer < 2)
	{
		if (winner == -1)
		{
			CPrintToChatAll("%s%t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);

			Reset_JackPot();

			return;
		}

		Store_SetClientCredits(winner, Store_GetClientCredits(winner) + jackpot);

		Reset_JackPot();

		CPrintToChat(winner, "%s%t", g_sChatPrefix, "Noone else cashed in", jackpot, g_sCreditsName);
		return;
	}

	if (winner == -1)
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "Winner is not in game anymore");

		int iIndex;
		while ((iIndex = g_hJackPot.FindValue(winner_accountID)) != -1)
		{
			g_hJackPot.Erase(iIndex);
		}

		winner_accountID = g_hJackPot.Get(GetRandomInt(0, g_hJackPot.Length - 1));
		winner = GetClientOfSteamAccountID(winner_accountID);

		if (winner == -1)
		{
			CPrintToChatAll("%s%t", g_sChatPrefix, "Second Winner is not in game anymore");
			for (int i = 0; i <= MaxClients; i++)
			{
				if (!IsValidClient(i, false, true) || !g_bUsed[i])
					continue;

				winner = i;
				break;
			}
		
		}
	}

	if (winner == -1)
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);

		Reset_JackPot();

		return;
	}

	CPrintToChatAll("%s%t", g_sChatPrefix, "Player won the Jackpot", winner, jackpot, g_sCreditsName);

	if (gc_iFee.IntValue != 0)
	{
		int fee = jackpot * gc_iFee.IntValue / 100;
		CPrintToChat(winner, "%s%t", g_sChatPrefix, "You won the Jackpot - Fee", jackpot, g_sCreditsName, fee, g_sCreditsName, gc_iFee.IntValue);
		jackpot -= fee;
	}
	else
	{
		CPrintToChat(winner, "%s%t", g_sChatPrefix, "You won the Jackpot", jackpot, g_sCreditsName);
	}

	Store_SetClientCredits(winner, Store_GetClientCredits(winner) + jackpot);

	Reset_JackPot();
}

void Reset_JackPot()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bUsed[i] = false;
		g_iBet[i] = 0;
	}

	g_iPlayer = 0;
	g_bActive = false;

	g_hJackPot.Clear();
	g_iPause = gc_iPause.IntValue + GetTime();
}

int SecToTime(int time, char[] buffer, int size)
{
	int iHours = 0;
	int iMinutes = 0;
	int iSeconds = time;

	while (iSeconds > 3600)
	{
		iHours++;
		iSeconds -= 3600;
	}
	while (iSeconds > 60)
	{
		iMinutes++;
		iSeconds -= 60;
	}

	if (iHours >= 1)
	{
		Format(buffer, size, "%t", "x hours, x minutes, x seconds", iHours, iMinutes, iSeconds);
	}
	else if (iMinutes >= 1)
	{
		Format(buffer, size, "%t", "x minutes, x seconds", iMinutes, iSeconds);
	}
	else
	{
		Format(buffer, size, "%t", "x seconds", iSeconds);
	}
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}

void ReadCoreCFG()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/core.cfg");

	Handle hParser = SMC_CreateParser();
	char error[128];
	int line = 0;
	int col = 0;

	SMC_SetReaders(hParser, INVALID_FUNCTION, Callback_CoreConfig, INVALID_FUNCTION);
	SMC_SetParseEnd(hParser, INVALID_FUNCTION);

	SMCError result = SMC_ParseFile(hParser, sFile, line, col);
	delete hParser;

	if (result == SMCError_Okay)
		return;

	SMC_GetErrorString(result, error, sizeof(error));
	Store_SQLLogMessage(0, LOG_ERROR, "ReadCoreCFG: Error: %s on line %i, col %i of %s", error, line, col, sFile);
}

public SMCResult Callback_CoreConfig(Handle parser, char[] key, char[] value, bool key_quotes, bool value_quotes)
{
	if (StrEqual(key, "MenuItemSound", false))
	{
		strcopy(g_sMenuItem, sizeof(g_sMenuItem), value);
	}
	else if (StrEqual(key, "MenuExitBackSound", false))
	{
		strcopy(g_sMenuExit, sizeof(g_sMenuExit), value);
	}

	return SMCParse_Continue;
}