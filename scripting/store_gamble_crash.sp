#include <colors>
#include <sourcemod>
#include <sdktools>
#include <store>
#include <autoexecconfig>

#pragma tabsize 0
#pragma newdecls required

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

public Plugin myinfo = 
{
	name = "Store - Crash gamble module",
	author = "Emur, AiDN™, nuclear silo",
	description = "Crash game Zephyrus's , nuclear silo's edited store",
	version = "1.0"
};

//CVars
ConVar gc_iStart, gc_iMax, gc_iMin, gc_bNotify, gc_iIncrease;

//Countdown
int seconds;

int onmenu[MAXPLAYERS + 1]; //To see is player on the panel or not.
int situation[MAXPLAYERS + 1]; //To see player's situation in the game.
int isstarted; //To see is game on or not.
int bet[MAXPLAYERS + 1], totalgained[MAXPLAYERS + 1];
float number; //The number that gets higher.
float x; // The number that is the limit.

public void OnPluginStart()
{
	//Translations
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");

	//ConVars
	gc_iStart = CreateConVar("store_crash_time", "30", "Seconds to start crash. Dont touch this or you may cause trouble.");
	gc_iMax = CreateConVar("store_crash_max", "10000", "Maximum amount of credits to spend.");
	gc_iMin = CreateConVar("store_crash_min", "20", "Minium amount of credits to spend.");
	gc_bNotify = CreateConVar("store_crash_notify_player", "1", "Wheither or not notify client on crash timer on chat.");
	gc_iIncrease = CreateConVar("store_crash_increase_value", "200", "How fast the multiplier in crash increase. Dont touch if you dont know what you are doing.");

	AutoExecConfig(true, "crash", "sourcemod/store");
	//Commands
	RegConsoleCmd("sm_crash", Command_Crash, "Command to see the panel");
	
	seconds = GetConVarInt(gc_iStart);
	CreateTimer(1.0, maintimer, _, TIMER_REPEAT); //The timer that counts down.
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public Action Command_Crash(int client, int args)
{
	if(args < 1)
	{
		onmenu[client] = 1;
		CreateTimer(0.1, crashpanel, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(situation[client] == 0 && args >= 1 && isstarted == 0)
	{
		//Classical bet shits.
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		bet[client] = StringToInt(arg1);
		if(Store_GetClientCredits(client) < bet[client])
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
			return Plugin_Handled;
		}
		else if(bet[client] > gc_iMax.IntValue)
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "You can't spend that much credits", gc_iMax.IntValue, g_sCreditsName);
			return Plugin_Handled;
		}
		else if(bet[client] < gc_iMin.IntValue)
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "You have to spend at least x credits.", gc_iMin.IntValue, g_sCreditsName);
			return Plugin_Handled;
		}
		else
		{
			Store_SetClientCredits(client, Store_GetClientCredits(client) - bet[client]);
			situation[client] = 1;
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Betting Placed", bet[client], g_sCreditsName);
		}   	 
    }
   	else if(situation[client] != 1 )
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Crash Already Start");
	}
	else if(isstarted == 1)
	{
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Game in progress");
	}
	
   	return Plugin_Stop;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public Action maintimer(Handle timer)
{
	seconds--;
	if(seconds == 600 || seconds == 300 || seconds == 60 || seconds == 30 || seconds == 10 || seconds <= 3  && seconds > 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(onmenu[i] == 0 && IsClientInGame(i) && !IsFakeClient(i))
			{
				if(gc_bNotify.BoolValue)
				{
					if(seconds > 60)
					{
						int minutes = seconds / 60;
						CPrintToChat(i, "%s%t", g_sChatPrefix, "Last x mins", minutes);	    
					}
					else if(seconds == 60)
					{
						int minutes = 1;
						CPrintToChat(i, "%s%t", g_sChatPrefix, "Last x mins", minutes);
					}
					else
					{
						if(seconds == 3)
						{
							if(IsClientInGame(i) && !IsFakeClient(i) && situation[i] != 0 && onmenu[i] == 0)
							{
								onmenu[i] = 1;
								CreateTimer(0.1, crashpanel, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
							}
						}			
						CPrintToChat(i, "%s%t", g_sChatPrefix, "Last x secs" ,seconds);	    
					}
				}
			}
		}
	}
	else if(seconds == 0)
	{
		StartTheGame();
	}
	
	return Plugin_Continue;
}

public void StartTheGame()
{
	isstarted = 1, number = 1.00; //Boring things.
	
	//Gets the X
	int luckynumber = GetRandomInt(1, 100);
	if(luckynumber <= 15)
	{
		x = GetRandomFloat(1.00, 1.25);
	}
	else if(luckynumber <= 70 && luckynumber > 15)
	{
		x = GetRandomFloat(1.25, 2.00);
	}
	else if(luckynumber <= 98 && luckynumber > 70)
	{
		x = GetRandomFloat(2.00, 10.00);
	}
	else if (luckynumber <= 100 && luckynumber > 98)
	{
		x = GetRandomFloat(6.00, 100.00);
	}

	CreateTimer(0.1, makeithigher, _, TIMER_REPEAT); // That boi will increase the number.
}

public Action makeithigher(Handle timer)
{
	if(number < x)
	{
		//number = number + number/200; //Didn't want to increase it for the same number everytime. With this way its gets faster every second.
		number = number + number/(gc_iIncrease.IntValue); 
	}
	else
	{
		number = 0.0; //We need that for the loop.
		ResetIt();
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public void ResetIt()
{
	CreateTimer(5.0, resettimer);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(onmenu[i] == 1 && IsClientInGame(i) && !IsFakeClient(i))
		{
			EmitSoundToClient(i, "store/lost.mp3"); //The sound that will make players break their keyboards. Yea that happened.
		}
	}
}

public Action resettimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		bet[i] = 0;
		situation[i] = 0;
	}
	seconds = GetConVarInt(gc_iStart);
	isstarted = 0;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////		PANELS		//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public Action crashpanel(Handle timer, any client)
{
	char crashtext[64];
	int iCredits = Store_GetClientCredits(client);
	//I dont have any idea about this part.
	if(onmenu[client] == 1 && IsClientInGame(client) && !IsFakeClient(client))
	{
		char gainedcredits[64];
		Format(gainedcredits, sizeof(gainedcredits), "%t", "Gained");
		// The game is pending
		if(isstarted == 0)
		{
			char startingtext[32];
			Format(startingtext, sizeof(startingtext), "|      %t: %d", "Starting", seconds);
			Panel crashmenu_baslamadan = new Panel();
			Format(crashtext, sizeof(crashtext), "%t" ,"crash");
			crashmenu_baslamadan.SetTitle(crashtext);
			crashmenu_baslamadan.DrawText("---------------------------------");
			crashmenu_baslamadan.DrawText("^");
			crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("|"); 
			crashmenu_baslamadan.DrawText(startingtext);
			crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("| __ __ __ __ __ __ __ __ ");
			crashmenu_baslamadan.DrawText("---------------------------------");
			if(situation[client] == 0)
			{
				char command[32];
				Format(command, sizeof(command), "    %t", "Type in chat !crash");
				crashmenu_baslamadan.DrawText(command);
				crashmenu_baslamadan.DrawText("---------------------------------");
			}
			else if(situation[client] == 1)
			{
				char buffer[64];
				char buffer2[64];
				Format(buffer, sizeof(buffer), "%t", "Your bet", bet[client], g_sCreditsName);
				Format(buffer2, sizeof(buffer2), "%s: -",gainedcredits);
				crashmenu_baslamadan.DrawText(buffer2);
				crashmenu_baslamadan.DrawText(buffer);
				crashmenu_baslamadan.DrawText("---------------------------------");
			}
			//SetPanelCurrentKey(crashmenu_baslamadan, 9);
			crashmenu_baslamadan.CurrentKey = 1;
			Format(crashtext, sizeof(crashtext), "%t", "Close");
			crashmenu_baslamadan.DrawItem(crashtext);
			crashmenu_baslamadan.CurrentKey = 2;
			Format(crashtext, sizeof(crashtext), "%t", "Game Info");
			crashmenu_baslamadan.DrawItem(crashtext);
			crashmenu_baslamadan.CurrentKey = 3;
			Format(crashtext, sizeof(crashtext), "%t", "Bet Minium", gc_iMin.IntValue);
			crashmenu_baslamadan.DrawItem(crashtext, iCredits < gc_iMin.IntValue || situation[client]!=0 ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT);
			crashmenu_baslamadan.CurrentKey = 4;
			Format(crashtext, sizeof(crashtext), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			crashmenu_baslamadan.DrawItem(crashtext, iCredits < gc_iMin.IntValue || situation[client]!=0 ? ITEMDRAW_IGNORE  : ITEMDRAW_DEFAULT);
			crashmenu_baslamadan.CurrentKey = 5;
			Format(crashtext, sizeof(crashtext), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			crashmenu_baslamadan.DrawItem(crashtext, iCredits < gc_iMin.IntValue || situation[client]!=0 ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT);			
			crashmenu_baslamadan.DrawText("---------------------------------");
			crashmenu_baslamadan.Send(client, crashmenu_handler, 1);
			delete crashmenu_baslamadan;
		}
		// The game has started
		else if(isstarted == 1)
		{
			char numberZ[32], betZ[32], gainedZ[32];
			if(number != 0.0)
			{
				Format(numberZ, sizeof(numberZ), "|                x%3.2f", number);
			}
			else
			{
				Format(numberZ, sizeof(numberZ), "|                x%3.2f", x);
			}
			Format(betZ, sizeof(betZ), "%t", "Your bet", bet[client], g_sCreditsName);
			Format(gainedZ, sizeof(gainedZ), "%t", "Gained x Credits", RoundToFloor(bet[client] * number), g_sCreditsName);
			Panel crashmenu_aktif = new Panel();
			crashmenu_aktif.SetTitle("Crash");
			crashmenu_aktif.DrawText("---------------------------------");
			crashmenu_aktif.DrawText("^");
			crashmenu_aktif.DrawText("|  ");
			crashmenu_aktif.DrawText("|  ");
			crashmenu_aktif.DrawText("|"); 
			crashmenu_aktif.DrawText(numberZ);
			if(number != 0)
			{
				crashmenu_aktif.DrawText("|  ");
			}
			else
			{
				Format(crashtext, sizeof(crashtext), "|              %t", "Crash!");
				crashmenu_aktif.DrawText(crashtext);
			}
			crashmenu_aktif.DrawText("|  ");
			crashmenu_aktif.DrawText("| __ __ __ __ __ __ __ __ ");
			crashmenu_aktif.DrawText("---------------------------------");
			if(situation[client] == 0)
			{
				//SetPanelCurrentKey(crashmenu_aktif, 9);
				crashmenu_aktif.CurrentKey = 1;
				Format(crashtext, sizeof(crashtext), "%t", "Close");
				crashmenu_aktif.DrawItem(crashtext);
				crashmenu_aktif.CurrentKey = 2;
				Format(crashtext, sizeof(crashtext), "%t", "Game Info");	
				crashmenu_aktif.DrawItem(crashtext);
				crashmenu_aktif.DrawText("---------------------------------");
				if(number != 0.0)
				{
					crashmenu_aktif.Send(client, crashmenu_handler, 1);
				}
				else
				{
					crashmenu_aktif.Send(client, crashmenu_handler, 5);                     	
				}
				delete crashmenu_aktif;
			}
			else if(situation[client] == 1 || situation[client] == 2)
			{
				if(situation[client] == 1)
				{
					crashmenu_aktif.DrawText(gainedZ);
				}
				else if(situation[client] == 2)
				{
					char lastgain[32];
					Format(lastgain, sizeof(lastgain), "%t", "Gained x Credits", totalgained[client], g_sCreditsName);
					crashmenu_aktif.DrawText(lastgain);
				}
				crashmenu_aktif.DrawText(betZ);
				crashmenu_aktif.DrawText("---------------------------------");
				if(situation[client] == 1)
				{
					if(number != 0.0)
					{
						crashmenu_aktif.CurrentKey = 1;
						Format(crashtext, sizeof(crashtext), "%t", "Cash out");
						crashmenu_aktif.DrawItem(crashtext);
						//SetPanelCurrentKey(crashmenu_aktif, 9);
						//crashmenu_aktif.CurrentKey = 1;
						//crashmenu_aktif.DrawItem("Withdraw");
						crashmenu_aktif.DrawText("---------------------------------");
						crashmenu_aktif.Send(client, crashmenu_go_handler, 1);
						delete crashmenu_aktif;
					}
					else
					{
						//SetPanelCurrentKey(crashmenu_aktif, 9);
						crashmenu_aktif.CurrentKey = 1;
						Format(crashtext, sizeof(crashtext), "%t", "Close");
						crashmenu_aktif.DrawItem(crashtext);
						crashmenu_aktif.CurrentKey = 2;
						Format(crashtext, sizeof(crashtext), "%t", "Game Info");	
						crashmenu_aktif.DrawItem(crashtext);
						crashmenu_aktif.DrawText("---------------------------------");
						crashmenu_aktif.Send(client, crashmenu_go_handler, 5);  
						delete crashmenu_aktif;
					}
				}
				else if(situation[client] == 2)
				{
					//SetPanelCurrentKey(crashmenu_aktif, 9);
					crashmenu_aktif.CurrentKey = 1;
					Format(crashtext, sizeof(crashtext), "%t", "Close");
					crashmenu_aktif.DrawItem(crashtext);
					crashmenu_aktif.CurrentKey = 2;
					Format(crashtext, sizeof(crashtext), "%t", "Game Info");	
					crashmenu_aktif.DrawItem(crashtext);
					crashmenu_aktif.DrawText("---------------------------------");
					if(number != 0.0)
					{
						crashmenu_aktif.Send(client, crashmenu_go_handler, 1);
						delete crashmenu_aktif;
					}
					else
					{
						crashmenu_aktif.Send(client, crashmenu_go_handler, 5);
						delete crashmenu_aktif;
					}
				}	
			}	
		}
	}
	else
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public int crashmenu_go_handler(Menu menu, MenuAction action, int param1, int itemNum)
{
	if(action == MenuAction_Select)
	{
		
		switch(itemNum)
		{
			case 1:
			{
				if(situation[param1] == 1 && number == 0)
				{
					onmenu[param1] = 0;
				}
				else if(situation[param1] == 1 && number != 0)
				{
					totalgained[param1] = RoundToFloor(bet[param1] * number);
					situation[param1] = 2;
					int newcredits = Store_GetClientCredits(param1) + totalgained[param1];
					Store_SetClientCredits(param1, newcredits);
					if(number > 4)
					{
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits with X", param1, totalgained[param1], g_sCreditsName, number, "crash");
					}
					else
					{
						EmitSoundToClient(param1, "store/win.mp3");
						CPrintToChat(param1, "%s%t", g_sChatPrefix, "You won x Credits with X", totalgained[param1], number);
					}
				}
				else if(situation[param1] == 2)
				{
					onmenu[param1] = 0;
				}
				EmitSoundToClient(param1, g_sMenuExit);
			}
			case 2:
			{
				onmenu[param1] = 0;
				Panel_GameInfo(param1);
				EmitSoundToClient(param1, g_sMenuItem);
			}
		}
	}
	else if(action == MenuAction_End)
	{
	}
	else if(action == MenuAction_Cancel)
	{
	}
}

public int crashmenu_handler(Menu menu, MenuAction action, int param1, int itemNum)
{
	if(action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1:
			{
				onmenu[param1] = 0;
				EmitSoundToClient(param1, g_sMenuExit);
			}
			case 2:
			{
				onmenu[param1] = 0;
				Panel_GameInfo(param1);
				EmitSoundToClient(param1, g_sMenuItem);
			}
			case 3, 4, 5:
			{
				// Decline when player come back to life
				int credits = Store_GetClientCredits(param1);
				switch(itemNum)
				{
					case 3:
					{
						bet[param1] = gc_iMin.IntValue;
						situation[param1] = 1;
						Store_SetClientCredits(param1, credits - bet[param1]);
					}
					case 4: 
					{
						bet[param1] = credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits;
						situation[param1] = 1;
						Store_SetClientCredits(param1, credits - bet[param1]);
					}
					case 5: 
					{
						bet[param1] = GetRandomInt(gc_iMin.IntValue, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits);
						situation[param1] = 1;
						Store_SetClientCredits(param1, credits - bet[param1]);
					}
				}

				//Panel_PlaceColor(client);
				//ClientCommand(param1, "sm_crash");

				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(param1, g_sMenuItem);
				
			}
		}
	}
	else if(action == MenuAction_End)
	{
	}
	else if(action == MenuAction_Cancel)
	{    
	}
}


//Show the games info panel
void Panel_GameInfo(int client)
{
	char sBuffer[1024];
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t" ,"crash");
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "    %t", "Crash Info 1");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Crash Info 2");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Crash Info 3");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Crash Info 4", gc_iMin.IntValue, g_sCreditsName, gc_iMax.IntValue, g_sCreditsName);
	panel.DrawText(sBuffer);

	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_WheelRun, 20);

	delete panel;
}

public int Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1:
			{
				ClientCommand(client, "sm_crash");
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

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/store/lost.mp3");
	AddFileToDownloadsTable("sound/store/win.mp3");
	PrecacheSound("store/lost.mp3");
	PrecacheSound("store/win.mp3");
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