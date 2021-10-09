#include <sourcemod>
#include <sdktools>
#include <store>
#include <multicolors>
#pragma tabsize 0

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

#define cooldown g_cvCooldownTime.FloatValue

int g_iRand1, g_iRand2;
int timeleft;
int g_iManualAmount[MAXPLAYERS + 1] = 100;
ConVar	g_cvMinAmount,
		g_cvMaxAmount,
		g_cvMinNumber,
		g_cvMaxNumber,
		g_cvLose,
		g_cvWon,
		g_cvCooldownTime;
Handle CommandHandle;
float currentTime;
float gametime;
float timepassed;

public Plugin myinfo = 
{
	name = "High or Low",
	author = "SheriF & AiDN™",
	description = "Higher & Lower Gamble for Zephyrus's store by SheriF, for nuclear silo's edited store by AiDN™",
	version = "1.1"
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	
	RegConsoleCmd("sm_hol", highorlow);
	g_cvMinAmount = CreateConVar("store_hol_min_amount", "50", "The minimum amount of Credits to play High or Low");
	g_cvMaxAmount = CreateConVar("store_hol_max_amount", "500", "The maximum amount of Credits to play High or Low");
	g_cvMinNumber = CreateConVar("store_hol_min_number", "1", "The minimum generated number");
	g_cvMaxNumber = CreateConVar("store_hol_max_number", "100", "The maximum generated number");
	g_cvLose = CreateConVar("store_hol_lose", "250", "Amount of credits player lost to show in public.");
	g_cvWon = CreateConVar("store_hol_won", "400", "Amount of credits player won to show in public.");
	g_cvCooldownTime = CreateConVar("store_cooldown_time", "30.0", "Cooldown for the high or low command. Usage: The amount of second between each try of the command . 0.0-Disable.");
	AutoExecConfig(true, "highorlow", "sourcemod/store");
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public void OnClientPostAdminCheck(int client)
{
	g_iManualAmount[client] = 100;
}

public Action highorlow(int client, int args)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		ShowMainMenu(client);
	}
	return Plugin_Handled;
}
public Action TimerFunction(Handle timer)
{
	currentTime = 0.0;
	CommandHandle = null;
    return Plugin_Handled;
}

public int menuHandler_HolMenu(Menu menu, MenuAction action, int client, int itemNUM)
{
	int credits = Store_GetClientCredits(client);
	if (action == MenuAction_Select)
	{
		switch (itemNUM)
		{
			case 0:
			{
				g_iManualAmount[client] = g_cvMinAmount.IntValue;
				StartGame(client);
			}
			case 1:
			{
				g_iManualAmount[client] = credits > g_cvMaxAmount.IntValue ? g_cvMaxAmount.IntValue : credits;
				StartGame(client);
			}
			case 2:
			{
				g_iManualAmount[client] = GetRandomInt(g_cvMinAmount.IntValue, credits > g_cvMaxAmount.IntValue ? g_cvMaxAmount.IntValue : credits);
				StartGame(client);
			}
			case 3:	Panel_GameInfo(client);
		}
	}
}

void StartGame(int client)
{
	char 	sBuffer[256],
			sBuffer2[256];
	if (Store_GetClientCredits(client) < g_iManualAmount[client])
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
		
	else
	{
		if (CommandHandle != null)
		{
  	 		gametime = GetGameTime();
     		timepassed = gametime-currentTime;
     		timeleft = RoundFloat(cooldown - timepassed);
	 		CPrintToChat(client, "%s%t", g_sChatPrefix, "Seconds to use command", timeleft);
  		 }
		else
  		{
  			currentTime = GetGameTime();
			int iMinNumber = g_cvMinNumber.IntValue;
			int iMaxNumber = g_cvMaxNumber.IntValue;
			CommandHandle = CreateTimer(cooldown , TimerFunction);
			g_iRand1 = GetRandomInt(iMinNumber+1, iMaxNumber-1);
			g_iRand2 = GetRandomInt(iMinNumber, iMaxNumber);
			while(g_iRand1==g_iRand2)
		 		g_iRand2 = GetRandomInt(iMinNumber, iMaxNumber);
			Menu HolMenu1 = new Menu(menuHandler_HolMenu1);
			Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
			Format(sBuffer2, sizeof(sBuffer2), "%t", "Credits and Pot", Store_GetClientCredits(client), g_iManualAmount[client]);
			Format(sBuffer, sizeof(sBuffer), "%s\n%s", sBuffer, sBuffer2);
			HolMenu1.SetTitle(sBuffer);
			Format(sBuffer, sizeof(sBuffer), "%t", "Higher");
			HolMenu1.AddItem("", sBuffer);
			Format(sBuffer, sizeof(sBuffer), "%t", "Lower");
			HolMenu1.AddItem("", sBuffer);
			HolMenu1.ExitButton = false;
			HolMenu1.Display(client, MENU_TIME_FOREVER);
			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iManualAmount[client]);
			Format(sBuffer, sizeof(sBuffer), "%t", "Hint chosen number", g_iRand1);
			PrintCenterText(client, sBuffer);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "The chosen number", g_iRand1);
		}
	}
}

public int menuHandler_HolMenu1 (Menu menu, MenuAction action, int client, int ItemNum)
{
	char sBuffer[256];
	if (action == MenuAction_Select)
	{
		switch (ItemNum)
		{
			case 0:
			{
				if(g_iRand2>g_iRand1)
				{
					int credits = g_iManualAmount[client] * 2;
					CPrintToChat(client, "%s%t", g_sChatPrefix, "You win x Credits", credits, g_sCreditsName);
					Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);
					if(credits > g_cvWon.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits", client, credits, g_sCreditsName, sBuffer);
					}
				}
				else
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Lost next number", g_iRand2);
				
					int credits = g_iManualAmount[client];
					if(credits < g_cvLose.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player lost x Credits", client, credits, g_sCreditsName, sBuffer);
					}
					
				Format(sBuffer, sizeof(sBuffer), "%t", "Hint next number", g_iRand2);
				PrintCenterText(client, sBuffer);
			}
			case 1:
			{
				if(g_iRand2<g_iRand1)
				{
					int credits = g_iManualAmount[client] * 2;
					CPrintToChat(client, "%s%t", g_sChatPrefix, "You win x Credits", credits, g_sCreditsName);
					Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);
					if(credits > g_cvWon.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits", client, credits, g_sCreditsName, sBuffer);
					}
				}
				else	
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Lost next number", g_iRand2);
				
					int credits = g_iManualAmount[client];
					if(credits < g_cvLose.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player lost x Credits", client, credits, g_sCreditsName, sBuffer);
					}

				Format(sBuffer, sizeof(sBuffer), "%t", "Hint next number", g_iRand2);
				PrintCenterText(client, sBuffer);
			}
		}
	}
}


void ShowMainMenu(int client)
{
	int iCredits = Store_GetClientCredits(client);

	char sBuffer[64];
	Menu HolMenu = new Menu(menuHandler_HolMenu);
	Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
	HolMenu.SetTitle(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", g_cvMinAmount.IntValue);
	HolMenu.AddItem("", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > g_cvMaxAmount.IntValue ? g_cvMaxAmount.IntValue : iCredits);
	HolMenu.AddItem("", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", g_cvMinAmount.IntValue, iCredits > g_cvMaxAmount.IntValue ? g_cvMaxAmount.IntValue : iCredits);
	HolMenu.AddItem("", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	HolMenu.AddItem("", sBuffer);
	HolMenu.ExitButton = true;
	HolMenu.Display(client, MENU_TIME_FOREVER);
}

void Panel_GameInfo(int client)
{
	char sBuffer[1024];
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t" , "high or low");
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "%t", "Hol Info 1", g_cvMinNumber.IntValue, g_cvMaxNumber.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Hol Info 2");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	if(g_cvCooldownTime.IntValue > 0.0)
	{
	Format(sBuffer, sizeof(sBuffer), "%t", "Hol Info 3", g_cvCooldownTime.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	}
	
	else{}
	
	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_WheelRun, 30);

	delete panel;
}

public int Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 3:
			{
				ClientCommand(client, "sm_hol");
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