/*
 * MyStore - Dice gamble module
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
#pragma newdecls required

#include <sourcemod>
#include <adminmenu>

#include <store>
#include <zephstocks>

#include <colors>

#include <autoexecconfig>

ConVar gc_iMin;
ConVar gc_iMax;
ConVar gc_fAutoStop;
ConVar gc_fSpeed;
ConVar gc_bAlive;

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

Handle g_hTimerRun[MAXPLAYERS+1] = {null, ...};
Handle g_hTimerStopFlip[MAXPLAYERS+1] = {null, ...};

bool g_bFlipping[MAXPLAYERS+1] = {false, ...};
int g_iBet[MAXPLAYERS+1] = {-1, ...};
int g_iPosition[MAXPLAYERS+1] = {-1, ...};
int g_iDiceBet[MAXPLAYERS+1] = {-1, ...};

public Plugin myinfo = 
{
	name = "Store - Dice gamble module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Origin code is from Shanapu - I just edit to be compaitble with Zephyrus Store",
	version = "1.3", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_dice", Command_Dice, "Open the Dice casino game");

	AutoExecConfig_SetFile("gamble", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_fSpeed = AutoExecConfig_CreateConVar("store_dice_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_fAutoStop = AutoExecConfig_CreateConVar("store_dice_stop", "10.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_bAlive = AutoExecConfig_CreateConVar("store_dice_alive", "1", "0 - Only dead player can start a game. 1 - Allow alive player to start a game.", _, true, 0.0);
	gc_iMin = AutoExecConfig_CreateConVar("store_dice_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_iMax = AutoExecConfig_CreateConVar("store_dice_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);

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

	g_iPosition[client] = -1;
	g_bFlipping[client] = false;
	g_iBet[client] = 0;
}

public void OnClientDisconnect(int client)
{
	// Stop and close open timer
	delete g_hTimerRun[client];
	delete g_hTimerStopFlip[client];
}

public Action Command_Dice(int client, int args)
{
	// Command comes from console
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (args < 1 || args > 2)
	{
		if(g_hTimerRun[client] != INVALID_HANDLE || g_hTimerStopFlip[client] != INVALID_HANDLE)
		{
			//delete g_hTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_PreDice(client);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !dice");
		}
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
	else if (strcmp(sBuffer,"half"))
	{
		iBet = RoundFloat(iCredits / 2.0);
	}
	else if (StrEqual(sBuffer,"third"))
	{
		iBet = RoundFloat(iCredits / 3.0);
	}
	else if (strcmp(sBuffer,"quater"))
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

	//g_bFlipping[client] = false;

	g_iBet[client] = iBet;

	if (args == 1)
	{
		if(g_hTimerRun[client] != INVALID_HANDLE || g_hTimerStopFlip[client] != INVALID_HANDLE)
		{
			//delete g_hTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_ChooseNum(client);
		}
	}
	else if (args == 2)
	{
		if(g_hTimerRun[client] != INVALID_HANDLE || g_hTimerStopFlip[client] != INVALID_HANDLE)
		{
			//delete g_hTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			GetCmdArg(2, sBuffer, 32);
			int iNum = StringToInt(sBuffer);
			switch(iNum)
			{
				case 1, 2, 3, 4, 5, 6: g_iDiceBet[client] = iNum;
				default:
				{
					if (sBuffer[0] == 'l')
					{
						g_iDiceBet[client] = 0;
					}
					else if (sBuffer[0] == 'h')
					{
						g_iDiceBet[client] = 7;
					}
					else
					{
						CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !dice");

						return Plugin_Handled;
					}
				}
			}

			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
			Start_Dice(client);
		}
	}

	return Plugin_Handled;
}

void Panel_PreDice(int client)
{
	// reset dice
	g_iPosition[client] = GetRandomInt(1,6);
	g_bFlipping[client] = false;

	if (g_iBet[client] == -1)
	{
		g_iBet[client] = gc_iMin.IntValue;
	}

	Panel_Dice(client);
}

// Open the start dice panel
void Panel_Dice(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%s:%i", "dice", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	PanelInject_Dice(panel, client);
	panel.DrawText(" ");

	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !dice", "or use buttons below");
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
	panel.CurrentKey = 6;

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

	panel.Send(client, Handler_Dice, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Dice(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 3, 4, 5:
			{
				// Decline when player come back to life
				int credits = Store_GetClientCredits(client);
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Dice(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				else
				{
					switch(itemNum)
					{
						case 3: g_iBet[client] = gc_iMin.IntValue;
						case 4: g_iBet[client] = credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits;
						case 5: g_iBet[client] = GetRandomInt(gc_iMin.IntValue, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits);
					}

					Panel_ChooseNum(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Dice(client);
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Panel_ChooseNum(client);
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

// Open the choose color panel
void Panel_ChooseNum(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	PanelInject_Dice(panel, client);	
	panel.DrawText(" ");
	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !dice", "or use buttons below");
		panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "Low - #1-3 (1:2)");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "High - #4-6 (1:2)");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT); //translate

	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t", "Choose Number (1:6)");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

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

	panel.Send(client, Handler_PlaceColor, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_PlaceColor(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 3, 4:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Dice(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
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
							case 3: g_iDiceBet[client] = 0;
							case 4: g_iDiceBet[client] = 7;
						}

						Store_SetClientCredits(client, iCredits - g_iBet[client]);
						Start_Dice(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Panel_Dice(client);

						CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
					}
				}
			}
			case 5:
			{
				Panel_ChooseNumber(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 7:
			{
				Panel_Dice(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
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

// Open the choose color panel
void Panel_ChooseNumber(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	PanelInject_Dice(panel, client);

	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !dice", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t #1", "Bet on");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t #2", "Bet on");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t #3", "Bet on");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "%t #4", "Bet on");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t #5", "Bet on");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t #6", "Bet on");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
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

	panel.Send(client, Handler_Num, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Num(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		// Item 1 - Roll dice on red
		switch(itemNum)
		{
			case 1, 2, 3, 4, 5, 6:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Dice(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");
				}
				// Remove Credits & start the game
				else
				{
					if (Store_GetClientCredits(client) >= g_iBet[client])
					{
						g_iDiceBet[client] = itemNum;

						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
						Start_Dice(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Panel_Dice(client);

						CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
					}
				}
			}
			case 7:
			{
				Panel_Dice(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
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

void Start_Dice(int client)
{
	g_bFlipping[client] = true;

	// end possible still running timers
	delete g_hTimerStopFlip[client];
	delete g_hTimerRun[client];
	Store_SetClientRecurringMenu(client, true);

	//play a start sound
	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hTimerRun[client] = CreateTimer(gc_fSpeed.FloatValue, Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hTimerRun[client]);

	g_hTimerStopFlip[client] = CreateTimer(GetAutoStopTime(), Timer_StopDice, GetClientUserId(client)); // stop first roll
}

void Panel_RunAndWin(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When dice is running step postion by one
	if (g_bFlipping[client])
	{
		int random = GetRandomInt(1,6);
		while (random == g_iPosition[client])
		{
			random = GetRandomInt(1,6);
		}
		g_iPosition[client] = random;
	}

	PanelInject_Dice(panel, client);
	panel.DrawText(" ");
	// When dice is still running
	if (g_bFlipping[client])
	{
		// Draw the placed bet
		Format(sBuffer, sizeof(sBuffer), "    %t", "Your bet", g_iBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);

		panel.DrawText(" ");


		switch(g_iDiceBet[client])
		{
			case 0: Format(sBuffer, sizeof(sBuffer), "    %t %t", "Bet on", "Low #1-3");
			case 1, 2, 3, 4, 5, 6: Format(sBuffer, sizeof(sBuffer), "    %t #%i", "Bet on", g_iDiceBet[client]);
			case 7: Format(sBuffer, sizeof(sBuffer), "    %t %t", "Bet on", "High #4-6");
		}
		panel.DrawText(sBuffer);
		panel.DrawText(" ");

		panel.DrawText(" ");
	}
	else
	{
		// If indicator is on choosen color -> WIN
		if ((g_iDiceBet[client] == 0 && g_iPosition[client] < 4) || (g_iDiceBet[client] == 7 && g_iPosition[client] > 3))
		{
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t %s", "You won with", g_iDiceBet[client] < 4 ? "Low" : "High");
			panel.DrawText(sBuffer);

			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "    %t", "You win x Credits", g_iBet[client] * 2, g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			panel.DrawText(" ");
			// Process the won Credits & remaining notfiction
			ProcessWin(client, g_iBet[client], 2);
		}
		else if (g_iDiceBet[client] == g_iPosition[client])
		{
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t #%i", "You won with", g_iDiceBet[client]);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t", "You win x Credits", g_iBet[client] * 6, g_sCreditsName);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			panel.DrawText(" ");

			// Process the won token & remaining notfiction
			ProcessWin(client, g_iBet[client], 6);

			panel.DrawItem(sBuffer, ITEMDRAW_SPACER);
		}
		// Player has not won -> Show start panel
		else
		{
			//Panel_Dice(client);

			//delete panel;
			//return;
			panel.DrawText(" ");
			switch(g_iDiceBet[client])
			{
				case 0: Format(sBuffer, sizeof(sBuffer), "    %t %t", "You lost with", "Low #1-3");
				case 1, 2, 3, 4, 5, 6: Format(sBuffer, sizeof(sBuffer), "    %t #%i", "You lost with", g_iDiceBet[client]);
				case 7: Format(sBuffer, sizeof(sBuffer), "    %t %t", "You lost with", "High #4-6");
			}
			panel.DrawText(sBuffer);
			
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "    %t", "You lost x Credits", g_iBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			panel.DrawText(" ");

			// Process the won token & remaining notfiction
			//ProcessWin(client, g_iBet[client], 6);

			panel.DrawItem(sBuffer, ITEMDRAW_SPACER);
			
			Format(sBuffer, sizeof(sBuffer), "%t", "dice");
			CPrintToChatAll("%s%t", g_sChatPrefix, "Player lost x Credits", client, g_iBet[client], g_sCreditsName, sBuffer);
		}
	}

	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iBet[client] > iCredits || g_bFlipping[client] || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.DrawText(" ");

	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_bFlipping[client] ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_bFlipping[client] ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", g_bFlipping[client] ? "Cancel" : "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT); // ITEMDRAW_DISABLED ???

	panel.Send(client, Handler_RunWin, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_RunWin(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			// Item 4 - Rerun bet
			case 6:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Dice(client);
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Panel_ChooseNum(client);
					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			// Item 6 - go back to casino
			case 7:
			{
				Panel_Dice(client);

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
				delete g_hTimerStopFlip[client];
				Store_SetClientRecurringMenu(client, false);

				if (g_bFlipping[client])
				{
					Panel_Dice(client);
				}

				g_bFlipping[client] = false;

				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

// Inject the dice into panels
void PanelInject_Dice(Panel panel, int client)
{
	char sBuffer[32];
	panel.DrawText("   ──────");
	Format(sBuffer, sizeof(sBuffer), "  │ %s    %s │", g_iPosition[client] > 3 ? "•" : "  ", g_iPosition[client] > 1 ? "•" : "  ");
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "  │ %s %s %s │    %i", g_iPosition[client] == 6 ? "•" : "  ", g_iPosition[client] & 1 ? "•" : "  ", g_iPosition[client] == 6 ? "•" : "  ", g_iPosition[client]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "  │ %s    %s │", g_iPosition[client] > 1 ? "•" : "  ", g_iPosition[client] > 3 ? "•" : "  ");
	panel.DrawText(sBuffer);
	panel.DrawText("   ──────");
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
	Format(sBuffer, sizeof(sBuffer), "%t", "dice");
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

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "    %t", "Bet on a number");
	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "    %t %t %i", "Low #1-3' = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "    %t %t %i", "High #4-6 = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "    %t %t %i", "Exact #x  = ", "bet x", 6);
	panel.DrawText(sBuffer);


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

	panel.Send(client, Handler_RunWin, 14);

	delete panel;
}

/******************************************************************************
                   Timer
******************************************************************************/

// The game runs and roll the dice
public Action Timer_Run(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hTimerRun[client] = null;

		return Plugin_Handled;
	}

	// Rebuild panel with new position
	Panel_RunAndWin(client);

	// When dice stopped end timer
	if (!g_bFlipping[client])
	{
		g_hTimerRun[client] = null;
		Store_SetClientRecurringMenu(client, false);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Timer to slow and stop dice
public Action Timer_StopDice(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hTimerStopFlip[client] = null;

		return Plugin_Handled;
	}

	// When dice stopped
	if (g_bFlipping[client])
	{
		g_bFlipping[client] = false;

		delete g_hTimerRun[client];
		Store_SetClientRecurringMenu(client, false);

		g_hTimerStopFlip[client] = null;

		// Show results
		Panel_RunAndWin(client);
	}
	else g_hTimerStopFlip[client] = null;

	return Plugin_Handled;
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