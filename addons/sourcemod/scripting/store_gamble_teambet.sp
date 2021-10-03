/*
 * Store - Teambet gamble module
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
#include <cstrike>

#include <store>
#include <zephstocks>

#include <colors>

#include <autoexecconfig>

ConVar gc_iBetPeriod;
ConVar gc_iMinPlayer;

char g_sChatPrefix[128];
char g_sCreditsName[64] = "credits";

char g_sMenuItem[64];
char g_sMenuExit[64];

ConVar gc_iMin;
ConVar gc_iMax;
ConVar gc_bAlive;

int g_iTeamBetStart = 0;
int g_iBet[MAXPLAYERS + 1];
int g_iTeam[MAXPLAYERS + 1];

int g_iBetOnT = 0;
int g_iBetOnCT = 0;

public Plugin myinfo = 
{
	name = "Store - Teambet gamble module",
	author = "shanapu, nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Origin code is from Shanapu - I just edit to be compatible with Zephyrus Store, bugfix by AiDN™",
	version = "1.4", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public int PlayerCount()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	
	return count;
}

public void OnPluginStart()
{
	LoadTranslations("store.phrases");

	AutoExecConfig_SetFile("gamble", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_iBetPeriod = AutoExecConfig_CreateConVar("store_teambet_period", "35", "How many seconds teambet should be enabled for after round start", _, true, 5.0);
	gc_iMinPlayer = AutoExecConfig_CreateConVar("store_teambet_player", "4", "min player for allow teambet", _, true, 0.0);
	gc_bAlive = AutoExecConfig_CreateConVar("store_teambet_alive", "1", "0 - Only dead player can start a game. 1 - Allow alive player to start a game.", _, true, 0.0);
	gc_iMin = AutoExecConfig_CreateConVar("store_teambet_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_iMax = AutoExecConfig_CreateConVar("store_teambet_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("round_start", TeamBet_RoundStart);
	HookEvent("round_end", TeamBet_RoundEnd);

	RegConsoleCmd("sm_bet", Command_Bet);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public void OnClientDisconnect(int client)
{
	if (g_iBet[client] < 1)
		return;

	Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iBet[client]);
	g_iBet[client] = 0;
	g_iTeam[client] = 0;
}

public Action Command_Bet(int client, int args)
{
	int count;
	count = PlayerCount();
	// Command comes from console
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Must be dead");

		return Plugin_Handled;
	}

	if (g_iTeamBetStart + gc_iBetPeriod.IntValue < GetTime())
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "TeamBet Period Over");

		return Plugin_Handled;
	}

	if (count < gc_iMinPlayer.IntValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Min Player", gc_iMinPlayer.IntValue);

		return Plugin_Handled;
	}

	if (args < 1 || args > 2)
	{
		Panel_TeamBet(client);
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !bet");

		return Plugin_Handled;
	}

	char sBuffer[32];
	GetCmdArg(1, sBuffer, 32);
	int iBet;
	int iCredits = Store_GetClientCredits(client);


	if (g_iBet[client] > 0)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "TeamBet Already Placed");
		return Plugin_Handled;
	}

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
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You have to spend at least x credits.", gc_iMin.IntValue, g_sCreditsName);

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

	g_iBet[client] = iBet;

	if (args == 1)
	{
		Panel_ChooseTeam(client);
	}
	else if (args == 2)
	{
		GetCmdArg(2, sBuffer, 32);
		if (StrEqual(sBuffer, "t") || StrEqual(sBuffer, "terror"))
		{
			g_iTeam[client] = CS_TEAM_T;
			g_iBetOnT += g_iBet[client];
		}
		else if (StrEqual(sBuffer, "ct") || StrEqual(sBuffer, "counter"))
		{
			g_iTeam[client] = CS_TEAM_CT;
			g_iBetOnCT += g_iBet[client];
		}
		else
		{
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !bet");

			return Plugin_Handled;
		}
		Panel_TeamBet(client);
		Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);

		CPrintToChat(client, "%s%t", g_sChatPrefix, "TeamBet Placed", g_iBet[client]);
	}

	return Plugin_Handled;
}

void Panel_TeamBet(int client)
{
	char sBuffer[255];
	
	int count;
	count = PlayerCount();
	
	int iCredits = Store_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "teambet", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	if ((g_iBetOnT == 0 && g_iBetOnCT == 0) && (g_iTeamBetStart + gc_iBetPeriod.IntValue < GetTime() || count < gc_iMinPlayer.IntValue))
	{
		panel.DrawText(" ");
		if (count < gc_iMinPlayer.IntValue)
		{
			Format(sBuffer, sizeof(sBuffer), "    %t", "Min Player", gc_iMinPlayer.IntValue);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "    %t", "TeamBet Period Over");
		}
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.DrawText(" ");
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
		panel.DrawItem(sBuffer, g_iBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, g_iBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, g_iBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else if (g_iBetOnT == 0 && g_iBetOnCT == 0)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "No active TeamBet");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
		{
			Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
			panel.DrawText(sBuffer);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !bet", "or use buttons below");
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t", "Bet CT win: x Credits", g_iBetOnCT, g_sCreditsName);
		panel.DrawText(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "    %t", "Bet T win: x Credits", g_iBetOnT, g_sCreditsName);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");

		if (g_iBet[client] > 0)
		{
			Format(sBuffer, sizeof(sBuffer), "    %t", "Your bet", g_iBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			panel.DrawText(" ");
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
			panel.DrawItem(sBuffer, g_iBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 4;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, g_iBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 5;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, g_iBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
		else if (g_iBet[client] == 0)
		{
			if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
			{
				Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
				panel.DrawText(sBuffer);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !bet", "or use buttons below");
				panel.DrawText(sBuffer);
			}
			panel.DrawText(" ");
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 4;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 5;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_TeamBet, MENU_TIME_FOREVER);
}


public int Handler_TeamBet(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 3, 4, 5:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_TeamBet(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					int credits = Store_GetClientCredits(client);
					switch(itemNum)
					{
						case 3: g_iBet[client] = gc_iMin.IntValue;
						case 4: g_iBet[client] = credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits;
						case 5: g_iBet[client] = GetRandomInt(gc_iMin.IntValue, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits);
					}

					Panel_ChooseTeam(client);

					//ClientCommand(client, "play sound/%s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 7:
			{
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 8:
			{
				Panel_GameInfo(client);
				//ClientCommand(client, "play sound/%s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

// Open the choose color panel
void Panel_ChooseTeam(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "teambet", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");

	if (g_iBetOnT == 0 && g_iBetOnCT == 0)
	{
		Format(sBuffer, sizeof(sBuffer), "    %t", "No active TeamBet");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t", "Bet CT win: x Credits", g_iBetOnCT, g_sCreditsName);
		panel.DrawText(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "    %t", "Bet T win: x Credits", g_iBetOnT, g_sCreditsName);
		panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !bet", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "Terrorist");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "Counter-Terrorist");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_ChooseTeam, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_ChooseTeam(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		// Item 1 - Roll roulette on red
		switch(itemNum)
		{
			case 3, 4:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_TeamBet(client);

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");
				}
				// Remove Credits & start the game
				else
				{
					int iCredits = Store_GetClientCredits(client);
					if (iCredits >= g_iBet[client])
					{
						switch(itemNum)
						{
							case 3:
							{
								g_iTeam[client] = CS_TEAM_T;
								g_iBetOnT += g_iBet[client];
							}
							case 4:
							{
								g_iTeam[client] = CS_TEAM_CT;
								g_iBetOnCT += g_iBet[client];
							}
						}

						Store_SetClientCredits(client, iCredits - g_iBet[client]);
						CPrintToChat(client, "%s%t", g_sChatPrefix, "TeamBet Placed", g_iBet[client]);
						//ClientCommand(client, "play sound/%s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Panel_TeamBet(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//ClientCommand(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Panel_TeamBet(client);

						CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
					}
				}
			}
			case 7:
			{
				Panel_TeamBet(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
		}
	}

	delete panel;
}

public Action TeamBet_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iTeamBetStart = GetTime();

	// Give back any credits that left in the pot for whatever reason
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || g_iBet[i] == 0)
			continue;

		Store_SetClientCredits(i, Store_GetClientCredits(i) + g_iBet[i]);

		g_iBet[i] = 0;
		g_iTeam[i] = 0;
	}

	return Plugin_Continue;
}

public Action TeamBet_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int iWinner = event.GetInt("winner");
	if (g_iBetOnT == 0 || g_iBetOnCT == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || g_iBet[i] == 0)
				continue;

			Store_SetClientCredits(i, Store_GetClientCredits(i) + g_iBet[i]);
			
			CPrintToChat(i, "%s%t", g_sChatPrefix, "TeamBet not betted");

			g_iBet[i] = 0;
			g_iTeam[i] = 0;
		}

		return Plugin_Continue;
	}

	float fMulti;
	if (iWinner == CS_TEAM_T)
	{
		fMulti = (g_iBetOnT + g_iBetOnCT) / float(g_iBetOnT);
	}
	else
	{
		fMulti = (g_iBetOnT + g_iBetOnCT) / float(g_iBetOnCT);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (g_iTeam[i] == iWinner)
		{
			Store_SetClientCredits(i, Store_GetClientCredits(i) + RoundFloat(g_iBet[i] * fMulti));
			CPrintToChat(i, "%s%t", g_sChatPrefix, "TeamBet Won", RoundFloat(g_iBet[i] * fMulti), g_sCreditsName);
		}
		else if (g_iBet[i] >= 1)
		{
			CPrintToChat(i, "%s%t", g_sChatPrefix, "TeamBet Lost", g_iBet[i], g_sCreditsName);
		}

		g_iBet[i] = 0;
		g_iTeam[i] = 0;
		g_iBetOnT = 0;
		g_iBetOnCT = 0;
	}

	return Plugin_Continue;
}

//Show the games info panel
void Panel_GameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "teambet", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "    %t", "Bet on a team");
	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "    %t", "Mutli = PotCT + PotT / PotWinningTeam");
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "    %t", "Bet * Multi = Your Win");
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");

	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.DrawText(" ");

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_WheelRun, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 7:
			{
				ClientCommand(client, "sm_bet");
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 9 - exit cancel
			case 9:
			{
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
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