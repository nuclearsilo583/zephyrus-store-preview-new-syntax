/*
 * MyStore - Crowns gamble module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: shanapu
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

//ConVar gc_bEnable;

ConVar gc_iMin;
ConVar gc_iMax;
ConVar gc_fAutoStop;
ConVar gc_fSpeed;
ConVar gc_bAlive;
ConVar gc_iBar;
ConVar gc_iCrown;
ConVar gc_iSmily;

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

Handle g_hTimerRun[MAXPLAYERS+1] = {null, ...};
Handle g_hTimerRollStop[MAXPLAYERS+1] = {null, ...};

int g_iRoll[MAXPLAYERS+1][3];
int g_iBet[MAXPLAYERS+1] = {-1, ...};
int g_iRollStopped[MAXPLAYERS+1] = {-1, ...};

public Plugin myinfo = 
{
	name = "Store - Crowns gamble module",
	author = "shanapu, nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Origin code is from Shanapu - I just edit to be compaitble with Zephyrus Store",
	version = "1.4", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_crowns", Command_Crowns, "Open the Simple Crowns casino game");

	AutoExecConfig_SetFile("gamble", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_fSpeed = AutoExecConfig_CreateConVar("store_crowns_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_fAutoStop = AutoExecConfig_CreateConVar("store_crowns_stop", "4.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_bAlive = AutoExecConfig_CreateConVar("store_crowns_alive", "1", "0 - Only dead player can start a game. 1 - Allow alive player to start a game.", _, true, 0.0);
	gc_iMin = AutoExecConfig_CreateConVar("store_crowns_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_iMax = AutoExecConfig_CreateConVar("store_crowns_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);
	gc_iSmily = AutoExecConfig_CreateConVar("store_crowns_win_smily", "5", "Multiplier when win '㋛  ㋛  ㋛'", _, true, 1.0);
	gc_iBar = AutoExecConfig_CreateConVar("store_crowns_win_bar", "10", "Multiplier when win '㍴  ㍴  ㍴'", _, true, 1.0);
	gc_iCrown = AutoExecConfig_CreateConVar("store_crowns_win_crown", "25", "Multiplier when win '♛  ♛  ♛'", _, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	// Reset all player variables
	g_iRoll[client][0] = -1; // reset all rolls
	g_iRoll[client][1] = -1;
	g_iRoll[client][2] = -1;
	g_iRollStopped[client] = -1;
	g_iBet[client] = 0;
}

public void OnClientDisconnect(int client)
{
	// Stop and close open timer
	delete g_hTimerRun[client];
	delete g_hTimerRollStop[client];
}

public Action Command_Crowns(int client, int args)
{
	// Command comes from console
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}


	//if (args < 1|| args > 1)
	//{
	Panel_Crowns(client);
		//CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !crowns");

		//return Plugin_Handled;
	//}
	return Plugin_Handled;
}

// Open the start crowns panel
void Panel_Crowns(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "crowns","Title Credits" , iCredits);
	panel.SetTitle(sBuffer);

	if (g_iRoll[client][0] < 2)
	{
		g_iRoll[client][0] = GetRandomInt(2, 6);
	}
	if (g_iRoll[client][1] < 2)
	{
		g_iRoll[client][1] = GetRandomInt(2, 6);
	}
	if (g_iRoll[client][2] < 2)
	{
		g_iRoll[client][2] = GetRandomInt(2, 6);
	}

	panel.DrawText(" ");
	// define roll symbols and order
	char sSymbolsRoll1[9][1] = {"㍴", "♛", "㋛", "☠", "㍴", "♛", "㋛", "☠", "㍴"};
	char sSymbolsRoll2[9][1] = {"♛", "☠", "㍴", "㋛", "♛", "☠", "㍴", "㋛", "♛"};
	char sSymbolsRoll3[9][1] = {"☠", "♛", "㋛", "㍴", "☠", "♛", "㋛", "㍴", "☠"};
							    //0    1    2     3    4    5     6    7     8

	// draw slot machine
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] - 2], sSymbolsRoll2[g_iRoll[client][1] - 2], sSymbolsRoll3[g_iRoll[client][2] - 2]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] - 1], sSymbolsRoll2[g_iRoll[client][1] - 1], sSymbolsRoll3[g_iRoll[client][2] - 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    -  %s   %s   %s    - ", sSymbolsRoll1[g_iRoll[client][0]], sSymbolsRoll2[g_iRoll[client][1]], sSymbolsRoll3[g_iRoll[client][2]]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] + 1], sSymbolsRoll2[g_iRoll[client][1] + 1], sSymbolsRoll3[g_iRoll[client][2] + 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] + 2], sSymbolsRoll2[g_iRoll[client][1] + 2], sSymbolsRoll3[g_iRoll[client][2] + 2]);
	panel.DrawText(sBuffer);

	// draw slot machine buttons
	panel.DrawText(" ");

	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !crowns", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
	panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 6;
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iBet[client] > iCredits || g_iBet[client] == 0 || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
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

	panel.Send(client, Handler_Crowns, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Crowns(Menu panel, MenuAction action, int client, int itemNum)
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
					Panel_Crowns(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
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

					Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
					Start_Crowns(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Crowns(client);
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
					Start_Crowns(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 7:
			{
				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 8:
			{
				Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

void Start_Crowns(int client)
{
	g_iRollStopped[client] = -1;

	// end possible still running timers
	delete g_hTimerRollStop[client];
	delete g_hTimerRun[client];

	//Store_SetClientRecurringMenu(client, true);

	//play a start sound
	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hTimerRun[client] = CreateTimer(gc_fSpeed.FloatValue, Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hTimerRun[client]);

	g_hTimerRollStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopRoll, GetClientUserId(client)); // stop first roll
}

void Panel_RunAndWin(int client)
{
	char sBuffer[128];
	bool bMatch = false;
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "crowns", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When bowl is running step postion by one
	if (g_iRollStopped[client] < 1)
	{
		g_iRoll[client][0]++;
		if (g_iRoll[client][0] >= 6)
		{
			g_iRoll[client][0] = 2;
		}
	}
	if (g_iRollStopped[client] < 2)
	{
		g_iRoll[client][1]++;
		if (g_iRoll[client][1] >= 6)
		{
			g_iRoll[client][1] = 2;
		}
	}
	if (g_iRollStopped[client] < 3)
	{
		g_iRoll[client][2]++;
		if (g_iRoll[client][2] >= 6)
		{
			g_iRoll[client][2] = 2;
		}
	}

	char sSymbolsRoll1[9][] = {"㍴", "♛", "㋛", "☠", "㍴", "♛", "㋛", "☠", "㍴"};
	char sSymbolsRoll2[9][] = {"♛", "☠", "㍴", "㋛", "♛", "☠", "㍴", "㋛", "♛"};
	char sSymbolsRoll3[9][] = {"☠", "♛", "㋛", "㍴", "☠", "♛", "㋛", "㍴", "☠"};
							// 0    1    2     3    4    5     6    7     8

	if (g_iRollStopped[client] > 2)
	{
		if (StrEqual(sSymbolsRoll1[g_iRoll[client][0]], sSymbolsRoll2[g_iRoll[client][1]]) && StrEqual(sSymbolsRoll3[g_iRoll[client][1]], sSymbolsRoll2[g_iRoll[client][2]]))
		{
			bMatch = true;
		}
		else
		{
			Panel_Crowns(client);
			delete panel;
			return;
		}

		g_iRollStopped[client] = 4;
	}

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] - 2], sSymbolsRoll2[g_iRoll[client][1] - 2], sSymbolsRoll3[g_iRoll[client][2] - 2]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] - 1], sSymbolsRoll2[g_iRoll[client][1] - 1], sSymbolsRoll3[g_iRoll[client][2] - 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    -  %s   %s   %s    - ", sSymbolsRoll1[g_iRoll[client][0]], sSymbolsRoll2[g_iRoll[client][1]], sSymbolsRoll3[g_iRoll[client][2]]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] + 1], sSymbolsRoll2[g_iRoll[client][1] + 1], sSymbolsRoll3[g_iRoll[client][2] + 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "    |  %s   %s   %s    | ", sSymbolsRoll1[g_iRoll[client][0] + 2], sSymbolsRoll2[g_iRoll[client][1] + 2], sSymbolsRoll3[g_iRoll[client][2] + 2]);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	// When bowl is still running
	if (g_iRollStopped[client] < 3)
	{
		panel.DrawText(" ");
		panel.DrawText(" ");

		Format(sBuffer, sizeof(sBuffer), "    %t", "Your bet", g_iBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");


		panel.DrawText(" ");
		panel.CurrentKey = 6;
		Format(sBuffer, sizeof(sBuffer), "%t", "Press to Stop");
		panel.DrawItem(sBuffer);
	}
	else if (bMatch)
	{
		panel.DrawText(" ");
		if (StrEqual(sSymbolsRoll1[g_iRoll[client][0]], "♛", true))
		{
			ProcessWin(client, g_iBet[client], gc_iCrown.IntValue);

			panel.DrawText("    !!  ♛  ♛  ♛  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t", "You win x Credits", g_iBet[client] * gc_iCrown.IntValue, g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		else if (StrEqual(sSymbolsRoll1[g_iRoll[client][0]], "㍴", true))
		{
			ProcessWin(client, g_iBet[client], gc_iBar.IntValue);

			panel.DrawText("    !!  ㍴  ㍴  ㍴  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t", "You win x Credits", g_iBet[client] * gc_iBar.IntValue, g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		else if (StrEqual(sSymbolsRoll1[g_iRoll[client][0]], "㋛", true))
		{
			ProcessWin(client, g_iBet[client], gc_iSmily.IntValue);

			panel.DrawText("    !!  ㋛  ㋛  ㋛  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t", "You win x Credits", g_iBet[client] * gc_iSmily.IntValue, g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		else if (StrEqual(sSymbolsRoll1[g_iRoll[client][0]], "☠", true))
		{
			FakeClientCommandEx(client, "play %s", g_sMenuItem);

			panel.DrawText("    !!  ☠  ☠  ☠  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t", "Lost bet");
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");
		panel.CurrentKey = 6;
		//Draw item rerun when already have bet - Panel line #14 - Panel item #4
		Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iBet[client], g_sCreditsName);
		panel.DrawItem(sBuffer, g_iBet[client] > iCredits || g_iRollStopped[client] < 3 || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	}
	//Draw item info - Panel line #15 - Panel item #5
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_iRollStopped[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_iRollStopped[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", g_iRollStopped[client] < 3 ? "Cancel" : "Exit");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_WheelRun, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			// Item 4 - Rerun bet
			case 6:
			{
				// Decline when player come back to life
				if (g_iRollStopped[client] < 3)
				{
					delete g_hTimerRollStop[client];

					if (g_iRollStopped[client] == -1) // when all rolls roll
					{
						g_iRollStopped[client] = 1; // stop first roll

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);

						delete g_hTimerRollStop[client];
						g_hTimerRollStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopRoll, GetClientUserId(client)); // stop second roll
					}
					else if (g_iRollStopped[client] == 1) // when first roll stopped
					{
						g_iRollStopped[client] = 2; // stop second roll

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);

						delete g_hTimerRollStop[client];
						g_hTimerRollStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopRoll, GetClientUserId(client)); // stop third roll
					}
					else if (g_iRollStopped[client] == 2) // when first and second roll stopped
					{
						g_iRollStopped[client] = 3; // stop third roll

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);

						delete g_hTimerRun[client];
						delete g_hTimerRollStop[client];
						//Store_SetClientRecurringMenu(client, false);

						Panel_RunAndWin(client);  // show result
					}
				}
				else
				{
					if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
					{
						Panel_Crowns(client);
						CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
					}
					// rerun
					else
					{
						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
						Start_Crowns(client);
						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
					}
				}
			}
			// Item 6 - go back to casino
			case 7:
			{
				Panel_Crowns(client);

				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			case 8:
			{
				Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 9 - exit cancel
			case 9:
			{
				delete g_hTimerRun[client];
				delete g_hTimerRollStop[client];
				//Store_SetClientRecurringMenu(client, false);

				if (g_iRollStopped[client] < 3)
				{
					Panel_Crowns(client);
				}

				g_iRollStopped[client] = -1;
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
		}
	}

	delete panel;
}

/******************************************************************************
                   functions
******************************************************************************/

//Randomize the stop time to the next number isn't predictable
float GetAutoStopTime()
{
	return GetRandomFloat(gc_fAutoStop.FloatValue/2 - 0.8, gc_fAutoStop.FloatValue/2 + 1.2);
}

void ProcessWin(int client, int bet, int multiply)
{
	char sBuffer[255];
	int iProfit = bet * multiply;

	// Add profit to balance
	Store_SetClientCredits(client, Store_GetClientCredits(client) + iProfit);

	// Play sound and notify other player abot this win
	Format(sBuffer, sizeof(sBuffer), "%t", "crowns");
	CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits", client, iProfit, g_sCreditsName, sBuffer);

	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
}

/******************************************************************************
                   Panel
******************************************************************************/

//Show the games info panel
void Panel_GameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "crowns", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "    %t", "Get three on a kind");
	panel.DrawText(" ");
	panel.DrawText(" ");

	// Draw info Line 1 - Panel line #7
	Format(sBuffer, sizeof(sBuffer), "    %s %t %i", "  ♛  ♛  ♛  = ", "bet x", gc_iCrown.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	panel.DrawText(" ");
	// Draw info Line 2 - Panel line #8
	Format(sBuffer, sizeof(sBuffer), "    %s %t %i", "  ㍴  ㍴  ㍴  = ", "bet x", gc_iBar.IntValue);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	// Draw info Line 3 - Panel line #9
	Format(sBuffer, sizeof(sBuffer), "    %s %t %i", "  ㋛  ㋛  ㋛  = ", "bet x", gc_iSmily.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	// Draw info Line 3 - Panel line #9
	Format(sBuffer, sizeof(sBuffer), "    %s %t", "  ☠  ☠  ☠  = ", "wasted");
	panel.DrawText(sBuffer);


	// Draw Spacer item - Panel line #11 - Panel item #1

	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_WheelRun, 14);

	delete panel;
}

/******************************************************************************
                   Timer
******************************************************************************/

// The game runs and roll the bowl
public Action Timer_Run(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientConnected(client))
	{
		g_hTimerRun[client] = null;

		return Plugin_Stop;
	}

	// Rebuild panel with new position
	Panel_RunAndWin(client);

	// When bowl stopped end timer
	if (g_iRollStopped[client] > 2)
	{
		g_hTimerRun[client] = null;
		//Store_SetClientRecurringMenu(client, false);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

// Timer to slow and stop bowl
public Action Timer_StopRoll(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	if (gc_fAutoStop.FloatValue == 0)
	{
		g_hTimerRollStop[client] = null;

		return Plugin_Stop;
	}

	// When client disconnected end timer
	if (!client || !IsClientConnected(client))
	{
		g_hTimerRollStop[client] = null;

		return Plugin_Stop;
	}

	switch(g_iRollStopped[client])
	{
		// When Bowl is running, slow down bowl
		case -1:
		{
			g_iRollStopped[client] = 1;

			g_hTimerRollStop[client] = null;
			g_hTimerRollStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopRoll, GetClientUserId(client)); // stop second roll
		}
		// When Bowl is still running and was already slowed, slow down bowl
		case 1: // when first roll stopped
		{
			g_iRollStopped[client] = 2;


			g_hTimerRollStop[client] = null;
			g_hTimerRollStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopRoll, GetClientUserId(client)); // stop third roll
		}
		// When Bowl is running and was already slowed twice, end bowl
		case 2:
		{
			// Stop bowl
			g_iRollStopped[client] = 3;

			delete g_hTimerRun[client];

			g_hTimerRollStop[client] = null;
			//Store_SetClientRecurringMenu(client, false);

			// Show results
			Panel_RunAndWin(client);
		}
		default: g_hTimerRollStop[client] = null;
	}

	return Plugin_Stop;
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