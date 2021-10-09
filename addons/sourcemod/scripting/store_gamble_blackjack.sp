#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#include <colors>
#include <autoexecconfig>
#include <store>

#define SUIT_SPADES "♠"
#define SUIT_DIAMONDS "♦"
#define SUIT_HEARTS "♥"
#define SUIT_CLUBS "♣"

enum GameStatus {
	Status_None = 0,
	Status_BlackJack,
	Status_Win,
	Status_Lose,
	Status_Draw
}

ConVar gc_iMax, gc_iMin, gc_iLose, gc_iWon;

char g_sSuits[4][5];
char g_sCards[13][3];

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

int iBetValue = 10;
int g_iCardValue[13] = {2,3,4,5,6,7,8,9,10,10,10,10,11};

Handle g_hPlayerCards[MAXPLAYERS+1];
Handle g_hDealerCards[MAXPLAYERS+1];
Handle g_hDealerThink[MAXPLAYERS+1];
int g_iPlayerPot[MAXPLAYERS+1];
int g_iBufferPlayerPot[MAXPLAYERS+1];	
int g_iPlayerLastPot[MAXPLAYERS+1];
int g_iPlayerCardValue[MAXPLAYERS+1];
int g_iDealerCardValue[MAXPLAYERS+1];
bool g_bIsIngame[MAXPLAYERS+1] = {false,...};
bool g_bStays[MAXPLAYERS+1] = {false,...};
bool g_bDealerEnds[MAXPLAYERS+1] = {false,...};
GameStatus:g_iGameStatus[MAXPLAYERS+1] = {Status_None,...};
bool g_bPlayerIsInMenu[MAXPLAYERS+1] = {false,...};
bool g_bMoneyDealt[MAXPLAYERS+1] = {false,...};

// For advert
bool g_bPlayedBJ[MAXPLAYERS+1] = {false,...};

public Plugin myinfo = 
{
	name = "Blackjack",
	author = "HerrMagic and Originalz ft. Jannik, AiDN™, nuclear silo",
	description = "Blackjack game Zephyrus's , nuclear silo's edited store",
	version = "1.2"
}

public OnPluginStart()
{
	//Translation
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");
	
	//ConVars
	
	gc_iMax = AutoExecConfig_CreateConVar("store_blackjack_max", "2000", "Maximum amount of credits to spend", _, true, 0.0);
	gc_iMin = AutoExecConfig_CreateConVar("store_blackjack_min", "20", "Minimum amount of credits to spend.", _, true, 0.0);
	gc_iLose = AutoExecConfig_CreateConVar("store_blackjack_lose", "500", "Amount of credits player lost to show in public.");
	gc_iWon = AutoExecConfig_CreateConVar("store_blackjack_won", "500", "Amount of credits player won to show in public.");
	AutoExecConfig(true, "blackjack", "sourcemod/store");
	
	// Some basic setup to fill our deck
	// Define all available cards
	Format(g_sSuits[0], sizeof(g_sSuits[]), SUIT_SPADES);
	Format(g_sSuits[1], sizeof(g_sSuits[]), SUIT_DIAMONDS);
	Format(g_sSuits[2], sizeof(g_sSuits[]), SUIT_HEARTS);
	Format(g_sSuits[3], sizeof(g_sSuits[]), SUIT_CLUBS);
	
	Format(g_sCards[0], sizeof(g_sCards[]), "2");
	Format(g_sCards[1], sizeof(g_sCards[]), "3");
	Format(g_sCards[2], sizeof(g_sCards[]), "4");
	Format(g_sCards[3], sizeof(g_sCards[]), "5");
	Format(g_sCards[4], sizeof(g_sCards[]), "6");
	Format(g_sCards[5], sizeof(g_sCards[]), "7");
	Format(g_sCards[6], sizeof(g_sCards[]), "8");
	Format(g_sCards[7], sizeof(g_sCards[]), "9");
	Format(g_sCards[8], sizeof(g_sCards[]), "10");
	Format(g_sCards[9], sizeof(g_sCards[]), "J");
	Format(g_sCards[10], sizeof(g_sCards[]), "Q");
	Format(g_sCards[11], sizeof(g_sCards[]), "K");
	Format(g_sCards[12], sizeof(g_sCards[]), "A");
	
	RegConsoleCmd("sm_bj", Cmd_BlackJack, "Opens the blackjack game.");
	RegConsoleCmd("sm_blackjack", Cmd_BlackJack, "Opens the blackjack game.");
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public OnClientDisconnect(client)
{
	if(g_hPlayerCards[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hPlayerCards[client]);
		g_hPlayerCards[client] = INVALID_HANDLE;
	}
	
	if(g_hDealerCards[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hDealerCards[client]);
		g_hDealerCards[client] = INVALID_HANDLE;
	}
	
	if(g_hDealerThink[client] != INVALID_HANDLE)
	{
		KillTimer(g_hDealerThink[client]);
		g_hDealerThink[client] = INVALID_HANDLE;
	}
	g_iPlayerPot[client] = 0;
	g_iBufferPlayerPot[client] = 0;
	g_iPlayerLastPot[client] = 0;
	g_iPlayerCardValue[client] = 0;
	g_iDealerCardValue[client] = 0;
	g_bIsIngame[client] = false;
	g_bStays[client] = false;
	g_bDealerEnds[client] = false;
	g_bPlayerIsInMenu[client] = false;
	g_bMoneyDealt[client] = false;
	g_iGameStatus[client] = Status_None;
	g_bPlayedBJ[client] = false;
}

public Event_OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_bPlayerIsInMenu[client])
	CancelClientMenu(client);
}

public Action Cmd_BlackJack(int client, int args)
{
	g_bPlayedBJ[client] = true;
	
	if(args == 0)
	{
		// He's already playing. Show the playing panel
		if(g_bIsIngame[client] == true)
		{
			ShowGamePanel(client);
		}
		else
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Type in chat !blackjack");
			ShowBetPanel(client);
		}
	} 
	else if(args == 1)
	{	
		char buffer[256];
		GetCmdArg(1, buffer, sizeof(buffer));
		
		int argument = StringToInt(buffer);
		
		int iAccount = Store_GetClientCredits(client);
		
		if(iAccount >= argument && (gc_iMax.IntValue == 0 || argument <= gc_iMax.IntValue)){}
		
		else
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "You can't spend that much credits", gc_iMax.IntValue, g_sCreditsName);
			return Plugin_Handled;
		}
		
		
		if(iAccount >= argument && (gc_iMax.IntValue == 0 || argument >= gc_iMin.IntValue))
		{
			
		}
		
		else
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "You have to spend at least x credits.", gc_iMin.IntValue, g_sCreditsName);
			return Plugin_Handled;
		}		
		
		if(iAccount >= argument)
		{
			// He's already playing. Show the playing panel
			if(g_bIsIngame[client] == true)
			{
				ShowGamePanel(client);
			}
			else
			{
				g_iBufferPlayerPot[client] = argument;
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Betting Placed", g_iBufferPlayerPot[client]);
				ShowBetPanel(client);
			}
			
		} 
		else if(iAccount <= argument)
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Credits");
			
			return Plugin_Handled;
		}
	} 
	else if (args > 1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Type in chat !blackjack");
	}
	
	return Plugin_Handled;
}

ShowBetPanel(client)
{
	int iAccount = Store_GetClientCredits(client);
	Panel panel = new Panel();
	
	char betValueBuffer[64];
	char betValueAmount[64];
	char sBuffer[64];
	char sBuffer2[64];
	if(g_iBufferPlayerPot[client] > 0 && iAccount >= g_iBufferPlayerPot[client]) {
			
		iAccount -= g_iBufferPlayerPot[client];
		g_iPlayerPot[client] = g_iBufferPlayerPot[client];
		g_iBufferPlayerPot[client] = 0;
		Store_SetClientCredits(client, iAccount);

	} 
	else if(g_iPlayerPot[client] == 0 && iAccount >= g_iPlayerPot[client])
	{
		
		iAccount -= g_iPlayerPot[client];
		Store_SetClientCredits(client, iAccount);
	}
	
	Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
	panel.SetTitle(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Credits and Pot", iAccount, g_iPlayerPot[client]);
	panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	panel.DrawItem("_______________", ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	Format(betValueBuffer, sizeof(betValueBuffer), "%t", "Deal+-", iBetValue, iBetValue);
	panel.DrawItem(betValueBuffer, ITEMDRAW_RAWLINE);

	Format(sBuffer, sizeof(sBuffer), "%t", "Press");
	if(g_iPlayerPot[client] > 0)
	{
		Format(sBuffer, sizeof(sBuffer), "%s:       1        2          3", sBuffer);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	}
	
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%s:                 2         3", sBuffer);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	}
	
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	
	Format(betValueAmount, sizeof(betValueAmount), "%t", "Amount", iBetValue);
	panel.DrawItem(betValueAmount, ITEMDRAW_RAWLINE);
	Format(sBuffer, sizeof(sBuffer), "%t", "Edit Amount");
	if(iBetValue == 10)
	{
		Format(sBuffer2, sizeof(sBuffer2), "%t", "Up");
		Format(sBuffer, sizeof(sBuffer), "%s4 = %s", sBuffer, sBuffer2);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
		//panel.DrawItem(" ------", ITEMDRAW_RAWLINE);
	}
	else if (iBetValue == 100)
	{
		Format(sBuffer2, sizeof(sBuffer2), "%t", "Up");
		Format(sBuffer, sizeof(sBuffer), "%s4 = %s", sBuffer, sBuffer2);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
		Format(sBuffer, sizeof(sBuffer), "%t", "Down2");
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	}
	else if (iBetValue == 1000)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Edit Amount");
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
		Format(sBuffer, sizeof(sBuffer), "%t", "Down2");
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	}
	
	SetPanelCurrentKey(panel, 6);
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	SetPanelCurrentKey(panel, 9);
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_CONTROL);
	
	//				  1      2      3      4	  5	   	6		9
	panel.SetKeys(((1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<8)));
	
	if(panel.Send(client, Menu_Betting, MENU_TIME_FOREVER))
		g_bPlayerIsInMenu[client] = true;
	
	delete panel;
}

ShowGamePanel(client)
{
	int iCountHigh = GetCardCount(client, true);
	int iCountLow = GetCardCount(client, false);
	
	char NameBuffer[16];
	GetClientName(client, NameBuffer, sizeof(NameBuffer));
	
	// He busted?
	if(iCountHigh > 21 && iCountLow > 21)
	{
		g_iGameStatus[client] = Status_Lose;
	}
	g_iPlayerCardValue[client] = iCountHigh <= 21?iCountHigh:iCountLow;
	
	
	// Build the game panel
	Handle hPanel = CreatePanel();
	char sBuffer[64], sBuffer2[64];
	Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
	SetPanelTitle(hPanel, sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Credits and Pot", Store_GetClientCredits(client), g_iPlayerPot[client]);
	DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
	DrawPanelItem(hPanel, "_______________", ITEMDRAW_RAWLINE);
	
	// Build dealer card graphics
	Format(sBuffer, sizeof(sBuffer), "");
	int iSize = GetArraySize(g_hDealerCards[client]);
	int cards[2];
	for(int i=0;i<iSize;i++)
	{
		GetArrayArray(g_hDealerCards[client], i, cards, 2);
		if(strlen(sBuffer) == 0)
			Format(sBuffer, sizeof(sBuffer), "[%s%s]", g_sCards[cards[1]], g_sSuits[cards[0]]);
		else
			Format(sBuffer, sizeof(sBuffer), "%s [%s%s]", sBuffer, g_sCards[cards[1]], g_sSuits[cards[0]]);
	}
	
	// The player is still able to hit, so we're not showing all dealers cards. He just has one anyways.
	Format(sBuffer2, sizeof(sBuffer2), "%t", "Dealer");
	if(!g_bStays[client])
	{
		Format(sBuffer, sizeof(sBuffer), "%s  %s", sBuffer2, sBuffer);
	}
	// The game ended. Show dealer cards.
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%s  %s = ", sBuffer2, sBuffer);
		
		// Game ended? Show the final value
		if(g_bDealerEnds[client])
		{
			// He got a black jack?
			if(g_iGameStatus[client] == Status_Lose && GetArraySize(g_hDealerCards[client]) == 2 && g_iDealerCardValue[client] == 21)
				Format(sBuffer, sizeof(sBuffer), "%t", "21Blackjack", sBuffer);
			else
				Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iDealerCardValue[client]);
		}
		// Game is still running? (Dealer is thinking)
		else
		{
			int iDealerCards1 = GetCardCount(client, false, true);
			int iDealerCards2 = GetCardCount(client, true, true);
			if(iDealerCards1 == iDealerCards2 || iDealerCards1 > 21 || iDealerCards2 > 21)
				Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iDealerCardValue[client]);
			else
				Format(sBuffer, sizeof(sBuffer), "%s%d/%d", sBuffer, iDealerCards1, iDealerCards2);
		}
	}
	DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
	DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	
	// Build players card graphics
	Format(sBuffer, sizeof(sBuffer), "");
	iSize = GetArraySize(g_hPlayerCards[client]);
	for(new i=0;i<iSize;i++)
	{
		GetArrayArray(g_hPlayerCards[client], i, cards, 2);
		if(strlen(sBuffer) == 0)
			Format(sBuffer, sizeof(sBuffer), "[%s%s]", g_sCards[cards[1]], g_sSuits[cards[0]]);
		else
			Format(sBuffer, sizeof(sBuffer), "%s [%s%s]", sBuffer, g_sCards[cards[1]], g_sSuits[cards[0]]);
	}
	
	Format(sBuffer2, sizeof(sBuffer2), "%t", "You");
	Format(sBuffer, sizeof(sBuffer), "%s  %s = ", sBuffer2, sBuffer);
	// The player stays and the dealer thinks...
	if(g_bStays[client])
	{
		// Blackjack!
		if(g_iGameStatus[client] == Status_BlackJack)
			Format(sBuffer, sizeof(sBuffer), "%t", "21Blackjack", sBuffer);
		// Just show the card value
		else
			Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iPlayerCardValue[client]);
	}
	// Player is still able to play
	else
	{
		// Player has no ace or busted. Just show the value
		if(g_iGameStatus[client] != Status_None || iCountHigh == iCountLow || iCountHigh > 21 || iCountLow > 21)
			Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iPlayerCardValue[client]);
		else
			Format(sBuffer, sizeof(sBuffer), "%s%d/%d", sBuffer, iCountHigh, iCountLow);
	}
	DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
	DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	// He's still open to act. (Didn't press stay or double)
	if(g_iGameStatus[client] == Status_None && !g_bStays[client])
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Hit");
		DrawPanelItem(hPanel, sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "Stay");
		DrawPanelItem(hPanel, sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "Double");
		DrawPanelItem(hPanel, sBuffer);
		DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	}
	else if(g_iGameStatus[client] != Status_None)
	{
		switch(g_iGameStatus[client])
		{
			case Status_Lose:
			{
				// The dealer is closer to 21.
				if(g_bDealerEnds[client])
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "You lose");
					DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
					g_bIsIngame[client] = false;
					if (g_iPlayerPot[client] >= gc_iLose.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player lost x Credits", client, g_iPlayerPot[client], g_sCreditsName, sBuffer);	
					}
					// You _overbuyed_ yourself!
				} 
				else
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "You lose");
					DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
					g_bIsIngame[client] = false;
					if (g_iPlayerPot[client] > gc_iLose.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player lost x Credits", client, g_iPlayerPot[client], g_sCreditsName, sBuffer);	
					}
				}
			}
			case Status_BlackJack:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "You won");
				DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
				g_bIsIngame[client] = false;
				if(ServerCommand("sm_givecredits")){}
				if(!g_bMoneyDealt[client])
				{
					Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iPlayerPot[client]*3);
					if (g_iPlayerPot[client] > gc_iWon.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
						CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits", client, g_iPlayerPot[client]*2, g_sCreditsName, sBuffer);
					}
				}
			}
			case Status_Win:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "You won");
				DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
				g_bIsIngame[client] = false;
				if (g_iPlayerPot[client] > gc_iWon.IntValue)
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
					CPrintToChatAll("%s%t", g_sChatPrefix, "Player won x Credits", client, g_iPlayerPot[client]*2, g_sCreditsName, sBuffer);
				}
				if(!g_bMoneyDealt[client])
					Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iPlayerPot[client]*2);
			}
			case Status_Draw:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "Dead heat");
				DrawPanelItem(hPanel, sBuffer, ITEMDRAW_RAWLINE);
				g_bIsIngame[client] = false;
				if(!g_bMoneyDealt[client])
					Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iPlayerPot[client]);
			}
		}
		DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
		SetPanelCurrentKey(hPanel, 4);
		Format(sBuffer, sizeof(sBuffer), "%t", "Try again");
		DrawPanelItem(hPanel, sBuffer);
		
		// We dealt with the money. Don't give it again, when he pauses and resumes.
		g_bMoneyDealt[client] = true;
	}
	else
	{
		DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
		DrawPanelItem(hPanel, "", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	}
	
	SetPanelCurrentKey(hPanel, 9);
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	DrawPanelItem(hPanel, sBuffer);
	
	if(SendPanelToClient(hPanel, client, Menu_GameHandler, MENU_TIME_FOREVER))
		g_bPlayerIsInMenu[client] = true;
	CloseHandle(hPanel);
}

public Menu_Betting(Handle menu, MenuAction action, param1, param2)
{
	// This panel is closed.
	g_bPlayerIsInMenu[param1] = false;
	if(action == MenuAction_Select)
	{
		// DEAL
		if(param2 == 1)
		{
			// Did he bet money?!
			if(g_iPlayerPot[param1] == 0)
			{
				ShowBetPanel(param1);
				return;
			}
			
			if(g_hPlayerCards[param1] == INVALID_HANDLE)
				g_hPlayerCards[param1] = CreateArray(2);
			else
				ClearArray(g_hPlayerCards[param1]);
			if(g_hDealerCards[param1] == INVALID_HANDLE)
				g_hDealerCards[param1] = CreateArray(2);
			else
				ClearArray(g_hDealerCards[param1]);
			
			if(g_hDealerThink[param1] != INVALID_HANDLE)
			{
				KillTimer(g_hDealerThink[param1]);
				g_hDealerThink[param1] = INVALID_HANDLE;
			}
			
			//g_iPlayerLastPot[param1] = g_iPlayerPot[param1];
			
			g_bIsIngame[param1] = true;
			g_bDealerEnds[param1] = false;
			g_iGameStatus[param1] = Status_None;
			g_bStays[param1] = false;
			g_bMoneyDealt[param1] = false;
			g_iPlayerCardValue[param1] = 0;
			g_iDealerCardValue[param1] = 0;
			
			PullPlayerCard(param1);
			PullPlayerCard(param1);
			PullDealerCard(param1);
			
			ShowGamePanel(param1);
		}
		else if(param2 == 2)
		{
			int iAccount = Store_GetClientCredits(param1);
			if(iAccount >= iBetValue && (gc_iMax.IntValue == 0 || (g_iPlayerPot[param1]+iBetValue) <= gc_iMax.IntValue))
			{
				g_iPlayerPot[param1] += iBetValue;
				Store_SetClientCredits(param1, iAccount-iBetValue);
			}
			ShowBetPanel(param1);
		}
		else if(param2 == 3)
		{
			if((g_iPlayerPot[param1]-iBetValue) >= 0)
			{
				int iAccount = Store_GetClientCredits(param1);
				g_iPlayerPot[param1] -= iBetValue;
				Store_SetClientCredits(param1, iAccount+iBetValue);
			}
			ShowBetPanel(param1);
		}
		else if(param2 == 4)
		{
			// calc up
			if (iBetValue == 10)
			{
				iBetValue = 100;
			} 
			else if (iBetValue == 100)
			{
				iBetValue = 1000;
			}
			ShowBetPanel(param1);
		}
		else if(param2 == 5)
		{
			// calc down
			if (iBetValue == 100)
			{
				iBetValue = 10;
			} 
			else if (iBetValue == 1000)
			{
				iBetValue = 100;
			}
			ShowBetPanel(param1);
		}
		else if(param2 == 6)
		{
			Panel_GameInfo(param1);
		}
		else if(param2 == 9)
		{
			int iAccount = Store_GetClientCredits(param1);
			Store_SetClientCredits(param1, iAccount + g_iPlayerPot[param1]);
			g_iPlayerPot[param1] = 0;
			g_iBufferPlayerPot[param1] = 0;
			g_iPlayerLastPot[param1] = 0;
			g_iPlayerCardValue[param1] = 0;
			g_iDealerCardValue[param1] = 0;
			g_bIsIngame[param1] = false;
			g_bStays[param1] = false;
			g_bDealerEnds[param1] = false;
			g_bPlayerIsInMenu[param1] = false;
			g_bMoneyDealt[param1] = false;
			g_iGameStatus[param1] = Status_None;
			g_bPlayedBJ[param1] = false;
			CPrintToChat(param1, "%s%t", g_sChatPrefix, "Type in chat !blackjack");
		}
	}
}

public Menu_GameHandler(Handle menu, MenuAction action, param1, param2)
{
	// This panel is closed.
	g_bPlayerIsInMenu[param1] = false;
	if(action == MenuAction_Select)
	{
		// This game is done, he clicked "try again"
		if(param2 == 4 && g_iGameStatus[param1] != Status_None)
		{
			g_iPlayerPot[param1] = 0;
			g_iGameStatus[param1] = Status_None;
			g_bIsIngame[param1] = false;
			ShowBetPanel(param1);
		}
		// HITME
		else if(param2 == 1 && g_iGameStatus[param1] != Status_Lose)
		{
			PullPlayerCard(param1);
			ShowGamePanel(param1);
		}
		// STAND
		// Let the dealer get his cards. Player won't be able to do anything anymore.
		else if(param2 == 2 && g_iGameStatus[param1] != Status_Lose)
		{
			g_bStays[param1] = true;
			g_hDealerThink[param1] = CreateTimer(0.7, Timer_DealerThink, GetClientUserId(param1), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hDealerThink[param1]);
		}
		// DOUBLE
		else if(param2 == 3 && g_iGameStatus[param1] != Status_Lose)
		{
			int iAccount = Store_GetClientCredits(param1);
			int iLimit = GetConVarInt(gc_iMax);
			if(iAccount >= g_iPlayerPot[param1] && (iLimit == 0 || (g_iPlayerPot[param1]*2) <= iLimit))
			{
				Store_SetClientCredits(param1, iAccount-g_iPlayerPot[param1]);
				g_iPlayerPot[param1] *= 2;
				g_iGameStatus[param1] = Status_None;
				PullPlayerCard(param1);
				
				g_bStays[param1] = true;
				ShowGamePanel(param1);
				if(g_iGameStatus[param1] == Status_None)
				{
					g_hDealerThink[param1] = CreateTimer(0.7, Timer_DealerThink, GetClientUserId(param1), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					g_bDealerEnds[param1] = false;
					
				}
				return;
			}
			
			ShowGamePanel(param1);
		}
		else if(param2 == 9)
		{
			if(g_iGameStatus[param1] != Status_None)
			{
				g_iPlayerPot[param1] = 0;
				g_iBufferPlayerPot[param1] = 0;
				g_iPlayerLastPot[param1] = 0;
				g_iPlayerCardValue[param1] = 0;
				g_iDealerCardValue[param1] = 0;
				g_bIsIngame[param1] = false;
				g_bStays[param1] = false;
				//g_bDealerEnds[param1] = false;
				g_bPlayerIsInMenu[param1] = false;
				//g_bMoneyDealt[param1] = false;
				g_iGameStatus[param1] = Status_None;
				g_bPlayedBJ[param1] = false;
				CPrintToChat(param1, "%s%t", g_sChatPrefix, "Type in chat !blackjack");
			} 
			else
			{
				CPrintToChat(param1, "%s%t", g_sChatPrefix, "Type in chat !blackjack");
			}
		}
	}
}

//Show the games info panel
void Panel_GameInfo(int client)
{
	char sBuffer[1024];
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t" ,"blackjack");
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 1");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 2");
	panel.DrawText(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 3");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 4");
	panel.DrawText(sBuffer);

	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
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
			case 1:
			{
				ClientCommand(client, "sm_bj");
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

public Action Timer_DealerThink(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client)
		return Plugin_Stop;
	
	// Get the dealer another card
	PullDealerCard(client);
	
	int iCountHigh = GetCardCount(client, true, true);
	int iCountLow  = GetCardCount(client, false, true);
	
	// Dealer got blackjack.
	if(GetArraySize(g_hDealerCards[client]) == 2 && iCountHigh == 21)
	{
		g_iDealerCardValue[client] = 21;
		g_bDealerEnds[client] = true;
		// Player has blackjack either?
		if(GetArraySize(g_hPlayerCards[client]) == 2 && g_iPlayerCardValue[client] == 21)
			g_iGameStatus[client] = Status_Draw;
		else
			g_iGameStatus[client] = Status_Lose;
	}
	// He lost
	else if(iCountHigh > 21 && iCountLow > 21)
	{
		g_iDealerCardValue[client] = iCountHigh;
		g_bDealerEnds[client] = true;
		// Player has blackjack?
		if(GetArraySize(g_hPlayerCards[client]) == 2 && g_iPlayerCardValue[client] == 21)
			g_iGameStatus[client] = Status_BlackJack;
		else
			g_iGameStatus[client] = Status_Win;
	}
	// He got 21, but with more than 2 cards.
	else if(iCountHigh == 21 || iCountLow == 21)
	{
		g_iDealerCardValue[client] = 21;
		g_bDealerEnds[client] = true;
		// Player got a blackjack?
		if(GetArraySize(g_hPlayerCards[client]) == 2 && g_iPlayerCardValue[client] == 21)
			g_iGameStatus[client] = Status_BlackJack;
		// Player has 21 either?
		else if(g_iPlayerCardValue[client] == 21)
			g_iGameStatus[client] = Status_Draw;
		else
			g_iGameStatus[client] = Status_Lose;
	}
	// Dealer is still under 21, continue pulling cards
	// (We check for < 17 below)
	else
	{
		// Dealer has to count an ace as 11 if he doesn't get more than 21 if he does.
		g_iDealerCardValue[client] = iCountHigh <= 21?iCountHigh:iCountLow;
	}
	
	// Dealer has to stop at >= 17
	if(g_iDealerCardValue[client] >= 17 && !g_bDealerEnds[client])
	{
		g_bDealerEnds[client] = true;
		if(g_iDealerCardValue[client] < g_iPlayerCardValue[client])
		{
			// Player has blackjack?
			if(GetArraySize(g_hPlayerCards[client]) == 2 && g_iPlayerCardValue[client] == 21)
				g_iGameStatus[client] = Status_BlackJack;
			else
				g_iGameStatus[client] = Status_Win;
		}
		else if(g_iDealerCardValue[client] == g_iPlayerCardValue[client])
		{
			g_iGameStatus[client] = Status_Draw;
		}
		else
		{
			g_iGameStatus[client] = Status_Lose;
		}
	}
	
	ShowGamePanel(client);
	
	// Stop the timer, if the game ended.
	if(g_bDealerEnds[client])
	{
		g_hDealerThink[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	else
		return Plugin_Continue;
}

PullPlayerCard(client)
{
	int newCard[2];
	newCard[0] = GetURandomIntRange(0, 3);
	newCard[1] = GetURandomIntRange(0, 12);
	PushArrayArray(g_hPlayerCards[client], newCard, 2);
}

PullDealerCard(client)
{
	int newCard[2];
	newCard[0] = GetURandomIntRange(0, 3);
	newCard[1] = GetURandomIntRange(0, 12);
	PushArrayArray(g_hDealerCards[client], newCard, 2);
}

// Messy function to get the points of the cards
GetCardCount(client, bool highace=true, bool dealer = false)
{
	int iSize;
	if(!dealer)
		iSize = GetArraySize(g_hPlayerCards[client]);
	else
		iSize = GetArraySize(g_hDealerCards[client]);
	if(iSize == 0)
		return 0;
	
	int iCount, cards[2];
	bool multipleAces = false;
	for(new i=0;i<iSize;i++)
	{
		if(!dealer)
			GetArrayArray(g_hPlayerCards[client], i, cards, 2);
		else
			GetArrayArray(g_hDealerCards[client], i, cards, 2);
		// The ace can be 11 or 1 point
		// Counting 2 aces as 11 is stupid, so only count one.
		if(cards[1] == 12 && (!highace || multipleAces))
		{
			iCount += 1;
		}
		else
		{
			iCount += g_iCardValue[cards[1]];
			if(cards[1] == 12)
				multipleAces = true;
		}
	}
	return iCount;
}

stock GetURandomIntRange(min, max)
{
    return (GetURandomInt() % (max-min+1)) + min;
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