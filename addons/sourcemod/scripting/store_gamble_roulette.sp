/*
 * MyStore - Roulette gamble module
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
Handle g_hTimerBowlStop[MAXPLAYERS+1] = {null, ...};

int g_iBet[MAXPLAYERS+1] = {-1, ...};
int g_iBowlPosition[MAXPLAYERS+1] = {-1, ...};
int g_iBowlSlowStop[MAXPLAYERS+1] = {-1, ...};
int g_iSide[MAXPLAYERS+1] = {-1, ...};

public Plugin myinfo = 
{
	name = "Store - Roulette gamble module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "Origin code is from Shanapu - I just edit to be compaitble with Zephyrus Store",
	version = "1.4", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_roulette", Command_Roulette, "Open the Simple Roulette casino game");

	AutoExecConfig_SetFile("gamble", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_fSpeed = AutoExecConfig_CreateConVar("store_roulette_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_fAutoStop = AutoExecConfig_CreateConVar("store_roulette_stop", "10.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_bAlive = AutoExecConfig_CreateConVar("store_roulette_alive", "1", "0 - Only dead player can start a game. 1 - Allow alive player to start a game.", _, true, 0.0);
	gc_iMin = AutoExecConfig_CreateConVar("store_roulette_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_iMax = AutoExecConfig_CreateConVar("store_roulette_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);

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

	g_iBowlPosition[client] = -1;
	g_iBowlSlowStop[client] = -1;
	g_iBet[client] = 0;
}

public void OnClientDisconnect(int client)
{
	// Stop and close open timer
	delete g_hTimerRun[client];
	delete g_hTimerBowlStop[client];
}

public Action Command_Roulette(int client, int args)
{
	// Command comes from console
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}


	if (args < 1 || args > 2)
	{
		if(g_hTimerRun[client] != INVALID_HANDLE || g_hTimerBowlStop[client] != INVALID_HANDLE)
		{
			//delete g_hTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_PreRoulette(client);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !roulette");
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
	else if (strcmp(sBuffer,"third"))
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

	g_iBowlPosition[client] = -1;
	g_iBowlSlowStop[client] = -1;

	if (g_iBowlPosition[client] < 0)
	{
		g_iBowlPosition[client] = GetRandomInt(0, 184);
	}

	g_iBet[client] = iBet;

	if (args == 1)
	{
		if(g_hTimerRun[client] != INVALID_HANDLE || g_hTimerBowlStop[client] != INVALID_HANDLE)
		{
			//delete g_hTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_PlaceColor(client);
		}
	}
	else if (args == 2)
	{
		if(g_hTimerRun[client] != INVALID_HANDLE || g_hTimerBowlStop[client] != INVALID_HANDLE)
		{
			//delete g_hTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			CReplyToCommand(client, "%s%t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			GetCmdArg(2, sBuffer, 32);
			if (StrEqual(sBuffer, "r") || StrEqual(sBuffer, "red"))
			{
				g_iSide[client] = 1;
			}
			else if (StrEqual(sBuffer, "g") || StrEqual(sBuffer, "green"))
			{
				g_iSide[client] = 3;
			}
			else if (StrEqual(sBuffer, "b") || StrEqual(sBuffer, "black"))
			{
				g_iSide[client] = 2;
			}
			else
			{
				CReplyToCommand(client, "%s%t", g_sChatPrefix, "No matching color");

				return Plugin_Handled;
			}

			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
			Start_Roulette(client);
		}
	}

	return Plugin_Handled;
}

void Panel_PreRoulette(int client)
{
	// reset bowl
	g_iBowlPosition[client] = -1;
	g_iBowlSlowStop[client] = -1;

	if (g_iBet[client] == -1)
	{
		g_iBet[client] = gc_iMin.IntValue;
	}

	Panel_Roulette(client);
}

// Open the start roulette panel
void Panel_Roulette(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When player is first time on this game set a random bowl position
	if (g_iBowlPosition[client] < 0)
	{
		g_iBowlPosition[client] = GetRandomInt(0, 184);
	}

	// Show the bowl - Panel line #5-9
	PanelInject_Bowl(panel, client);


	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !roulette", "or use buttons below");
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

	panel.Send(client, Handler_Roulette, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Roulette(Menu panel, MenuAction action, int client, int itemNum)
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
					Panel_Roulette(client);

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

					Panel_PlaceColor(client);

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Roulette(client);
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Panel_PlaceColor(client);
					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 7:
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 8:
			{
				Panel_GameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

// Open the choose color panel
void Panel_PlaceColor(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Show the bowl - Panel line #5-9
	PanelInject_Bowl(panel, client);	

	if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "    \n    %t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "    %t\n    %t", "Type in chat !roulette", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "'████' - %t %t", "Bet on", "Red");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "'▒▒▒▒' - %t %t", "Bet on", "Black");
	panel.DrawItem(sBuffer, !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "'▁▁▁▁' - %t %t", "Bet on", "Green");
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
		// Item 1 - Roll roulette on red
		switch(itemNum)
		{
			case 3, 4, 5:
			{
				// Decline when player come back to life
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Roulette(client);

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");
				}
				// Remove Credits & start the game
				else
				{
					if (Store_GetClientCredits(client) >= g_iBet[client])
					{
						switch(itemNum)
						{
							case 3: g_iSide[client] = 1;
							case 4: g_iSide[client] = 2;
							case 5: g_iSide[client] = 3;
						}

						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iBet[client]);
						Start_Roulette(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//ClientCommand(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Panel_Roulette(client);

						CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
					}
				}
			}
			case 7:
			{
				Panel_Roulette(client);
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			case 8:
			{
				Panel_GameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

void Start_Roulette(int client)
{
	g_iBowlSlowStop[client] = -1;

	// end possible still running timers
	delete g_hTimerBowlStop[client];
	delete g_hTimerRun[client];
	//Store_SetClientRecurringMenu(client, true);

	//play a start sound
	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hTimerRun[client] = CreateTimer(gc_fSpeed.FloatValue, Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hTimerRun[client]);

	g_hTimerBowlStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopBowl, GetClientUserId(client)); // stop first roll
}

void Panel_RunAndWin(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When bowl is running step postion by one
	if (g_iBowlSlowStop[client] < 3)
	{
		switch(g_iBowlSlowStop[client])
		{
			case -1: g_iBowlPosition[client] += 4;
			case 1: g_iBowlPosition[client] += 2;
			case 2: g_iBowlPosition[client] += 1;
		}

		if (g_iBowlPosition[client] > 184)
		{
			g_iBowlPosition[client] = 0;
		}
	}

	// Show the bowl - Panel line #5-9
	PanelInject_Bowl(panel, client);

	// When bowl is still running
	if (g_iBowlSlowStop[client] < 3)
	{
		// Draw the placed bet
		Format(sBuffer, sizeof(sBuffer), "    %t", "Your bet", g_iBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);

		// Draw Spacer item - Panel line #12 - Panel item #3
		panel.DrawText(" ");

		// Draw the placed color
		switch(g_iSide[client])
		{
			case 1: Format(sBuffer, sizeof(sBuffer), "    %t '████' %t", "Bet on", "Red");
			case 2: Format(sBuffer, sizeof(sBuffer), "    %t '▒▒▒▒' %t", "Bet on", "Black");
			case 3: Format(sBuffer, sizeof(sBuffer), "    %t '▁▁▁▁' %t", "Bet on", "Green");
		}
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
	}
	// When bowl has stopped
	else
	{
		// Set color order - like above
		char sColor[256] = "==== #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** ==== #### **** #### ****";

		// Get postion of mid indicator
		char short[2];
		Format(short, sizeof(short), sColor[g_iBowlPosition[client]+12]);

		// When indicator is between two fields turn the bowl one 'tick'(character) forward and show panel again.
		if (StrEqual(short, " "))
		{
			g_iBowlPosition[client]++;
			if (g_iBowlPosition[client] > 184)
			{
				g_iBowlPosition[client] = 0;
			}

			Panel_RunAndWin(client);

			delete panel;
			return;
		}

		// If indicator is on choosen color -> WIN
		if ((StrEqual(short, "*") && g_iSide[client] == 1) || (StrEqual(short, "#") && g_iSide[client] == 2) || (StrEqual(short, "=") && g_iSide[client] == 3) )
		{
			//Replace indicator position with prettier prompt
			char shorti[24];
			Format(shorti, sizeof(shorti), short);
			ReplaceString(shorti, sizeof(shorti), "=", "'▁▁▁▁' green", false);
			ReplaceString(shorti, sizeof(shorti), "*", "'████' red", false);
			ReplaceString(shorti, sizeof(shorti), "#", "'▒▒▒▒' black", false);

			// Build & draw won text - Panel line #12
			Format(sBuffer, sizeof(sBuffer), "    %t %s", "You won with", shorti);
			panel.DrawText(sBuffer);

			// Draw Spacer Line - Panel line #13
			panel.DrawText(" ");

			// Build & draw text - Panel line #14
			Format(sBuffer, sizeof(sBuffer), "    %t", "You win x Credits", g_iSide[client] < 3 ? (g_iBet[client] * 2) : (g_iBet[client] * 14), g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			// Process the won Credits & remaining notfiction
			ProcessWin(client, g_iBet[client], g_iSide[client] < 3 ? 2 : 14);


		}
		// Player has not won -> Show start panel
		else
		{
			//Panel_Roulette(client);

			//delete panel;
			//return;
			
			switch(g_iSide[client])
			{
				case 1: Format(sBuffer, sizeof(sBuffer), "    %t '████' %t", "You lost with", "Red");
				case 2: Format(sBuffer, sizeof(sBuffer), "    %t '▒▒▒▒' %t", "You lost with", "Black");
				case 3: Format(sBuffer, sizeof(sBuffer), "    %t '▁▁▁▁' %t", "You lost with", "Green");
			}

			// Build & draw won text - Panel line #12
			//Format(sBuffer, sizeof(sBuffer), "    %t %s", "You lost with", shorti);
			panel.DrawText(sBuffer);

			// Draw Spacer Line - Panel line #13
			panel.DrawText(" ");

			// Build & draw text - Panel line #14
			Format(sBuffer, sizeof(sBuffer), "    %t", "You lost x Credits", g_iBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			
			Format(sBuffer, sizeof(sBuffer), "%t", "roulette");
			CPrintToChatAll("%s%t", g_sChatPrefix, "Player lost x Credits", client, g_iBet[client], g_sCreditsName, sBuffer);
		}
	}
	panel.DrawText(" ");
	panel.CurrentKey = 6;
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iBet[client] > iCredits || g_iBowlSlowStop[client] < 3 || !gc_bAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	//Draw item info - Panel line #15 - Panel item #5
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_iBowlSlowStop[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_iBowlSlowStop[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", g_iBowlSlowStop[client] < 3 ? "Cancel" : "Exit");
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
				if (!gc_bAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_Roulette(client);
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be dead");

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Panel_PlaceColor(client);
					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			// Item 6 - go back to casino
			case 7:
			{
				Panel_Roulette(client);

				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			case 8:
			{
				Panel_GameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 9 - exit cancel
			case 9:
			{
				delete g_hTimerRun[client];
				delete g_hTimerBowlStop[client];
				//Store_SetClientRecurringMenu(client, false);

				if (g_iBowlSlowStop[client] < 3)
				{
					Panel_Roulette(client);
				}

				g_iBowlSlowStop[client] = -1;
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

// Inject the bowl into panels
void PanelInject_Bowl(Panel panel, int client)
{
	char sBuffer[256];
	
	// This are your roulette fields. We need '=' '*' & '#' as placeholder cause the '▁' '█' & '▒' ascii symbols would screw up the bowl postion due to their bigger size in arrays
	char sNumber[PLATFORM_MAX_PATH];
	Format(sNumber, sizeof(sNumber), "==0= #26# **3* #35# *12* #28# **7* #29# *18* #22# **9* #31# *14* #20# **1* #33# *16* #24# **5* #10# *23* ##8# *30* #11# *36* #13# *27* ##6# *34* #17# *25* ##2# *21* ##4# *19* #15# *32* ==0= #26# **3* #35# *12*");
	
	char sColor[PLATFORM_MAX_PATH];
	Format(sColor, sizeof(sColor), "==== #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** ==== #### **** #### ****");
	
	panel.DrawText(" ");
	// Draw the position indicator in top mid
	Format(sBuffer, sizeof(sBuffer), "                         ⮟");
	panel.DrawText(sBuffer);

	// Set the buffer at players bowlposition and cut the remaining fields
	char sShortener[26];
	Format(sShortener, sizeof(sShortener), sColor[g_iBowlPosition[client]]);
	Format(sBuffer, sizeof(sBuffer), sShortener);

	// Replace the = * # placeholder in buffer
	ReplaceString(sBuffer, sizeof(sBuffer), "=", "▁", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "*", "█", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "#", "▒", false);

	//Draw the first line with color
	Format(sBuffer, sizeof(sBuffer), "   |%s|", sBuffer);
	panel.DrawText(sBuffer);

	// Set the buffer at players bowlposition and cut the remaining fields
	Format(sShortener, sizeof(sShortener), sNumber[g_iBowlPosition[client]]);
	Format(sBuffer, sizeof(sBuffer), sShortener);

	// Replace the '=' '*' & '#' placeholder in buffer
	ReplaceString(sBuffer, sizeof(sBuffer), "=", "▁", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "*", "█", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "#", "▒", false);

	//Draw the second line with numbers
	Format(sBuffer, sizeof(sBuffer), "   |%s|", sBuffer);
	panel.DrawText(sBuffer);

	// Set the buffer at players bowlposition and cut the remaining fields
	Format(sShortener, sizeof(sShortener), sColor[g_iBowlPosition[client]]);
	Format(sBuffer, sizeof(sBuffer), sShortener);

	// Replace the '=' '*' & '#' placeholder in buffer
	ReplaceString(sBuffer, sizeof(sBuffer), "=", "▁", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "*", "█", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "#", "▒", false);

	//Draw the third line with color
	Format(sBuffer, sizeof(sBuffer), "   |%s|", sBuffer);
	panel.DrawText(sBuffer);

	// Draw the position indicator in bottom mid
	Format(sBuffer, sizeof(sBuffer), "                         ⮝");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
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
	Format(sBuffer, sizeof(sBuffer), "%t", "roulette");
	CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits", client, iProfit, g_sCreditsName, sBuffer);

	//ClientCommand(client, "play %s", g_sMenuItem);
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
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "    %t", "Bet on a color");
	panel.DrawText(" ");
	panel.DrawText(" ");

	// Draw info Line 1 - Panel line #7
	Format(sBuffer, sizeof(sBuffer), "    %s %t %i", "  '▒▒▒▒' black = ", "bet x", 2);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	panel.DrawText(" ");
	// Draw info Line 2 - Panel line #8
	Format(sBuffer, sizeof(sBuffer), "    %s %t %i", "  '████' red = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	// Draw info Line 3 - Panel line #9
	Format(sBuffer, sizeof(sBuffer), "    %s %t %i", "  '▁▁▁▁' green = ", "bet x", 14);
	panel.DrawText(sBuffer);


	// Draw Spacer item - Panel line #11 - Panel item #1
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
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hTimerRun[client] = null;

		return Plugin_Handled;
	}

	// Rebuild panel with new position
	Panel_RunAndWin(client);

	// When bowl stopped end timer
	if (g_iBowlSlowStop[client] > 2)
	{
		g_hTimerRun[client] = null;
		////Store_SetClientRecurringMenu(client, false);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Timer to slow and stop bowl
public Action Timer_StopBowl(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hTimerBowlStop[client] = null;

		return Plugin_Handled;
	}

	switch(g_iBowlSlowStop[client])
	{
		// When Bowl is running, slow down bowl
		case -1:
		{
			g_iBowlSlowStop[client] = 1;

			delete g_hTimerRun[client];

			g_hTimerRun[client] = CreateTimer(gc_fSpeed.FloatValue, Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
			g_hTimerBowlStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopBowl, GetClientUserId(client)); // stop second roll
		}
		// When Bowl is still running and was already slowed, slow down bowl
		case 1: // when first roll stopped
		{
			g_iBowlSlowStop[client] = 2;

			delete g_hTimerRun[client];

			g_hTimerRun[client] = CreateTimer(gc_fSpeed.FloatValue, Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
			g_hTimerBowlStop[client] = CreateTimer(GetAutoStopTime(), Timer_StopBowl, GetClientUserId(client)); // stop third roll
		}
		// When Bowl is running and was already slowed twice, end bowl
		case 2:
		{
			// Stop bowl
			g_iBowlSlowStop[client] = 3;

			delete g_hTimerRun[client];
			////Store_SetClientRecurringMenu(client, false);

			g_hTimerBowlStop[client] = null;

			// Show results
			Panel_RunAndWin(client);
		}
		default: g_hTimerBowlStop[client] = null;
	}

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