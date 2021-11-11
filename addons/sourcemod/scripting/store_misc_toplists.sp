//If the Toplist not work, check your MySQL variables 'sql mode' if there is ONLY_FULL_GROUP_BY, take it out.
//The seconds, minutes and hours 'toplist' translations for some language spelling.

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <store>
#include <zephstocks>

#include <colors> 
#include <autoexecconfig> 

#pragma semicolon 1
#pragma newdecls required
ConVar gc_iMaxShown;
ConVar gc_iUpdateInterval;

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

int g_iPage[MAXPLAYERS + 1];
int g_iList[MAXPLAYERS + 1];
int g_iUpdateTime;

#define TL_CREDITS 0
#define TL_ITEMS 1
#define TL_INV 2
#define TL_INV_CREDITS 3
// TODO? Equipt Worth?
ArrayList g_aTopLists[4];


public Plugin myinfo = 
{
	name = "Store - Toplists module",
	author = "shanapu, nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.2", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");

	RegConsoleCmd("sm_toplists", Command_TopLists);
	RegConsoleCmd("sm_topcredits", Command_Credits);
	RegConsoleCmd("sm_topitems", Command_Items);
	RegConsoleCmd("sm_topworth", Command_InventarWorth);
	RegConsoleCmd("sm_toptotal", Command_InventarAndCreditsWorth);

	AutoExecConfig_SetFile("toplist", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_iMaxShown = AutoExecConfig_CreateConVar("store_toplist_max", "10", "", _, true, 1.0);
	gc_iUpdateInterval = AutoExecConfig_CreateConVar("store_toplist_update_interval", "300.0", "If toplist is older thank x seconds query to database", _, true, 5.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_aTopLists[TL_CREDITS] = new ArrayList();
	g_aTopLists[TL_INV] = new ArrayList();
	g_aTopLists[TL_INV_CREDITS] = new ArrayList();
	g_aTopLists[TL_ITEMS] = new ArrayList();

	ReadCoreCFG();
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

void Menu_TopLists(int client)
{
	Menu menu = new Menu(Handler_TopLists);

	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client); // Get credits
	Format(sBuffer, sizeof(sBuffer), "%t - %t\n%t", "Title Store", "toplists", "Title Credits", iCredits);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits");
	menu.AddItem("0", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Most Items");
	menu.AddItem("1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Inv Worth");
	menu.AddItem("2", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits Inv Worth");
	menu.AddItem("3", sBuffer);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_TopLists(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if(param2 == 0)
			g_iList[client] = TL_CREDITS;
		else if(param2 == 1)
			g_iList[client] = TL_ITEMS;
		else if(param2 == 2)
			g_iList[client] = TL_INV;
		else if(param2 == 3)
			g_iList[client] = TL_INV_CREDITS;
		Panel_Credits(client, param2);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Command_TopLists(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	Menu_TopLists(client);

	return Plugin_Handled;
}

public Action Command_Credits(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_CREDITS;
	Panel_Credits(client, TL_CREDITS);

	return Plugin_Handled;
}

public Action Command_Items(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_ITEMS;
	Panel_Credits(client, TL_ITEMS);

	return Plugin_Handled;
}

public Action Command_InventarWorth(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_INV;
	Panel_Credits(client, TL_INV);

	return Plugin_Handled;
}

public Action Command_InventarAndCreditsWorth(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_INV_CREDITS;
	Panel_Credits(client, TL_INV_CREDITS);

	return Plugin_Handled;
}

public void TopLists_OnMapStart()
{
	//Query the latest toplists as a transaction
	Transaction tnx = new Transaction();

	char sBuffer[296];
	Format(sBuffer, sizeof(sBuffer), "SELECT name, credits FROM store_players ORDER BY credits DESC LIMIT %i;", gc_iMaxShown.IntValue);
	tnx.AddQuery(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "SELECT player.name, COUNT(player_id) AS amount FROM store_players AS player INNER JOIN store_items AS item ON player.id = item.player_id GROUP BY player.name ORDER BY amount DESC LIMIT %i;", gc_iMaxShown.IntValue);
	tnx.AddQuery(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "SELECT player.name, SUM(item.price_of_purchase) AS worth, COUNT(item.price_of_purchase) AS amount FROM store_players AS player INNER JOIN store_items AS item ON player.id = item.player_id GROUP BY player.name ORDER BY worth DESC LIMIT %i;", gc_iMaxShown.IntValue);
	tnx.AddQuery(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "SELECT player.name, (player.credits + SUM(item.price_of_purchase)) AS worth, COUNT(item.price_of_purchase) AS amount  FROM store_players AS player INNER JOIN store_items AS item ON player.id = item.player_id GROUP BY player.name ORDER BY worth DESC LIMIT %i;", gc_iMaxShown.IntValue);
	tnx.AddQuery(sBuffer);

	Store_SQLTransaction(tnx, SQLTXNCallback_Success, 0);

	//Save last update time
	g_iUpdateTime = GetTime();
}

public void SQLTXNCallback_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	//Loop through the results array for all types of toplists
	for (int i = 0; i < numQueries; i++)
	{
		if (results[i] == null)
		{
			Store_SQLLogMessage(0, LOG_ERROR, "SQLTXNCallback_Success: Error: No results for toplist #%i", i);
		}
		else
		{
			char sName[64];

			// Delete the DataPacks & clear the ArrayList
			if (g_aTopLists[i].Length > 0)
			{
				for (int j = 0; j < g_aTopLists[i].Length; j++)
				{
					DataPack pack = g_aTopLists[i].Get(j);
					delete pack;
				}
			}
			g_aTopLists[i].Clear();

			//Loop through the result rows and write them into DataPacks
			while (results[i].FetchRow())
			{
				DataPack pack = new DataPack();

				results[i].FetchString(0, sName, sizeof(sName));
				pack.WriteCell(results[i].FetchInt(1));
				pack.WriteString(sName);
				if (i > 1)
				{
					pack.WriteCell(results[i].FetchInt(2));
				}

				//Push these DataPacks to ArrayList
				g_aTopLists[i].Push(pack);
			}
		}
	}
}

void Panel_Credits(int client, int type)
{
	Panel panel = new Panel();

	char sName[256];
	char sBuffer[256], sBuffer2[256];

	int iCredits = Store_GetClientCredits(client); // Get credits

	//Choose right Title for toplist
	switch(type)
	{
		case TL_CREDITS: Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits");
		case TL_ITEMS: Format(sBuffer, sizeof(sBuffer), "%t", "Top Most Items");
		case TL_INV: Format(sBuffer, sizeof(sBuffer), "%t", "Top Inv Worth"); 
		case TL_INV_CREDITS: Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits Inv Worth");
	}

	//Display title
	Format(sBuffer, sizeof(sBuffer), "%t - %s\n%t", "Title Store", sBuffer, "Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");

	//Loop and display 5 players for actual page
	for (int i = g_iPage[client]; i < g_iPage[client] + 5 && i < g_aTopLists[type].Length; i++)
	{
		//Get DataPack with Player Data for toplist
		DataPack pack = g_aTopLists[type].Get(i);
		pack.Reset();
		int credits = pack.ReadCell();
		pack.ReadString(sName, sizeof(sName));

		//Format by types for display
		switch(type)
		{
			case TL_INV, TL_INV_CREDITS:
			{
				int items = pack.ReadCell();
				Format(sBuffer, sizeof(sBuffer), "%t", "items");
				Format(sBuffer, sizeof(sBuffer), "%t", "inv and inv credits", i + 1, sName, credits, g_sCreditsName, items, sBuffer);
			}
			case TL_CREDITS, TL_ITEMS:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "items");
				Format(sBuffer2, sizeof(sBuffer2), "%t", "creditstoplist", g_sCreditsName);
				Format(sBuffer, sizeof(sBuffer), "    %i. %s:   %i %s", i + 1, sName, credits, type == TL_CREDITS ? sBuffer2 : sBuffer);
			}
		}
		panel.DrawText(sBuffer);
	}

	//Panel footer
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	if (g_iPage[client] + 5 < g_aTopLists[type].Length)
	{
		panel.CurrentKey = 8;
		Format(sBuffer, sizeof(sBuffer), "%t", "Next");
		panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		SecToTime(GetTime() - g_iUpdateTime, sBuffer, sizeof(sBuffer));
		Format(sBuffer, sizeof(sBuffer), "%t", "last update", sBuffer);
		panel.DrawText(sBuffer);

		//When last update older than "mystore_toplist_update_interval"
		if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
		{
			TopLists_OnMapStart();
		}
	}
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.Send(client, Handler_Credits, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Credits(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			//Back
			case 7:
			{
				EmitSoundToClient(client, g_sMenuExit);
				switch(g_iPage[client])
				{
					//On first page? go back to toplists menu
					case 0:
					{
						Menu_TopLists(client);
					}
					//Not on first page? go page back
					default:
					{
						g_iPage[client] -= 5;
						Panel_Credits(client, g_iList[client]);
					}
				}
			}
			//Display Next page
			case 8:
			{
					g_iPage[client] += 5;
					Panel_Credits(client, g_iList[client]);
					EmitSoundToClient(client, g_sMenuItem);
			}
			//Close, reset page
			case 9:
			{
				g_iPage[client] = 0;
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
}

//Call for the menu sounds from sourcemods core.cfg for the panel keys
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

//Get & check callback keyvalues from core.cfg
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

//Format integer of N seconds into string of n hours, n minutes & n seconds
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
		Format(buffer, size, "%t", "x hours, x minutes, x seconds toplist", iHours, iMinutes, iSeconds);
	}
	else if (iMinutes >= 1)
	{
		Format(buffer, size, "%t", "x minutes, x seconds toplist", iMinutes, iSeconds);
	}
	else
	{
		Format(buffer, size, "%t", "x seconds toplist", iSeconds);
	}
}