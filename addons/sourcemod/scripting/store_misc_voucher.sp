#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#include <colors>

#pragma semicolon 1
#pragma newdecls required

#define REDEEM 1
#define CHECK 2
#define NUM 3
#define MIN 4
#define MAX 5
#define PURCHASE 6

int gc_iMySQLCooldown;
int gc_iExpireTime;
int gc_bItemVoucherEnabled;
int gc_bCreditVoucherEnabled;
int gc_bCheckAdmin;
int g_fInputTime;
int g_iChatType[MAXPLAYERS + 1] = {-1, ...};

char g_sChatPrefix[128];
char g_sCreditsName[32] = "credits";

char g_sMenuItem[64];
char g_sMenuExit[64];

Handle gf_hPreviewItem;
Handle g_hTimerInput[MAXPLAYERS+1] = null;

int g_iTempAmount[MAXPLAYERS + 1] = {0, ...};
int g_iCreateNum[MAXPLAYERS + 1] = {0, ...};
int g_iCreateMin[MAXPLAYERS + 1] = {0, ...};
int g_iCreateMax[MAXPLAYERS + 1] = {0, ...};
int g_iLastQuery[MAXPLAYERS + 1] = {0, ...};
int g_iSelectedItem[MAXPLAYERS + 1];

ConVar g_cvDatabaseEntry;
Handle g_hDatabase = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "Store - Voucher module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.5", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gf_hPreviewItem = CreateGlobalForward("Store_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_voucher", Command_Voucher, "Open the Voucher main menu");
	RegAdminCmd("sm_createvoucher", Command_CreateVoucherCode, ADMFLAG_ROOT);

	AutoExecConfig(true, "vouchers", "sourcemod/store");

	gc_bCreditVoucherEnabled = RegisterConVar("sm_store_voucher_credits", "1", "0 - disabled, 1 - enable credits to voucher", TYPE_INT);
	gc_bItemVoucherEnabled = RegisterConVar("sm_store_voucher_item", "1", "0 - disabled, 1 - enable item to voucher", TYPE_INT);
	gc_bCheckAdmin = RegisterConVar("sm_store_voucher_check", "1", "0 - admins only, 1 - all player can check vouchers", TYPE_INT);
	gc_iMySQLCooldown = RegisterConVar("sm_store_mysql_cooldown", "20", "Seconds cooldown between client start database querys (redeem, check & purchase vouchers)", TYPE_INT);
	gc_iExpireTime = RegisterConVar("sm_store_voucher_expire", "336", "0 - disabled, hours until a voucher expire after creation. 168 = one week", TYPE_INT);
	g_fInputTime = RegisterConVar("sm_store_voucher_input_time", "15.0", "Time in second player have to put value in the purchase, create panel", TYPE_FLOAT);

	AddCommandListener(Command_Say, "say"); 
	AddCommandListener(Command_Say, "say_team");

}

public void OnAllPluginsLoaded()
{
	if (g_eCvars[gc_bItemVoucherEnabled].aCache)
	{
		Store_RegisterMenuHandler("Voucher", Voucher_OnMenu, Voucher_OnHandler);
	}
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);

	ReadCoreCFG();
	
	g_cvDatabaseEntry = FindConVar("sm_store_database");
	char buffer[128];
	g_cvDatabaseEntry.GetString(buffer, 128);
	SQL_TConnect(SQLCallback_Connect, buffer);

}
/*
char m_szVoucherCreateTableQuery[2048];
	Store_SQLQuery("CREATE TABLE if NOT EXISTS `store_voucher` (\
										  voucher varchar(64) NOT NULL PRIMARY KEY default '',\
										  name_of_create varchar(64) NOT NULL default '',\
										  steam_of_create varchar(64) NOT NULL default '',\
										  credits INT NOT NULL default 0,\
										  item varchar(64) NOT NULL default '',\
										  date_of_create INT NOT NULL default 0,\
										  date_of_redeem INT NOT NULL default 0,\
										  name_of_redeem varchar(64) NOT NULL default '',\
										  steam_of_redeem TEXT NOT NULL,\
										  unlimited TINYINT NOT NULL default 0,\
										  date_of_expiration INT NOT NULL default 0,\
										  item_expiration INT default NULL);",
										SQLCallback_VoidVoucher, 0);
										
	Format(m_szVoucherCreateTableQuery, sizeof(m_szVoucherCreateTableQuery), "CREATE TABLE if NOT EXISTS `store_voucher` (\
										  `voucher` varchar(64) NOT NULL,\
										  `name_of_create` varchar(64) NOT NULL,\
										  `steam_of_create` varchar(64) NOT NULL,\
										  `credits` INT NOT NULL default '0',\
										  `item` varchar(64),\
										  `date_of_create` INT NOT NULL default '0',\
										  `date_of_redeem` INT NOT NULL default '0',\
										  `name_of_redeem` varchar(64),\
										  `steam_of_redeem` TEXT,\
										  `unlimited` TINYINT NOT NULL default '0',\
										  `date_of_expiration` INT NOT NULL default '0',\
										  `item_expiration` INT default NULL);");							
	Store_SQLQuery(m_szVoucherCreateTableQuery ,SQLCallback_VoidVoucher, 0);
	
	//Do some housekeeping
	char m_szVoucherQuery[2048];
	Format(m_szVoucherQuery, sizeof(m_szVoucherQuery), "UPDATE store_voucher SET"
									... " name_of_redeem = \"voucher's item expired\","
									... " date_of_redeem = %d,"
									... " steam_of_redeem = \"voucher's item expired\","
									... " item_expiration = 0 "
									... "WHERE item_expiration <> 0 AND item_expiration < %d", GetTime(), GetTime());
	Store_SQLQuery(m_szVoucherQuery, SQLCallback_VoidVoucher, 0);
*/
public void SQLCallback_Connect(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl==INVALID_HANDLE)
	{
		SetFailState("Failed to connect to SQL database. Error: %s", error);
	}
	else
	{
		// If it's already connected we are good to go
		if(g_hDatabase != INVALID_HANDLE)
			return;
			
		g_hDatabase = hndl;
		char m_szDriver[2];
		SQL_ReadDriver(g_hDatabase, STRING(m_szDriver));
		char m_szVoucherCreateTableQuery[2048];
		if(m_szDriver[0] == 'm')
		{
			Format(m_szVoucherCreateTableQuery, sizeof(m_szVoucherCreateTableQuery), "CREATE TABLE if NOT EXISTS `store_voucher` (\
										  `voucher` varchar(64) NOT NULL PRIMARY KEY,\
										  `name_of_create` varchar(64) NOT NULL,\
										  `steam_of_create` varchar(64) NOT NULL,\
										  `credits` INT NOT NULL default '0',\
										  `item` varchar(64) NOT NULL,\
										  `date_of_create` INT NOT NULL default '0',\
										  `date_of_redeem` INT NOT NULL default '0',\
										  `name_of_redeem` varchar(64) NOT NULL,\
										  `steam_of_redeem` varchar(64) NOT NULL,\
										  `unlimited` TINYINT NOT NULL default '0',\
										  `date_of_expiration` INT NOT NULL default '0',\
										  `item_expiration` INT default NULL);");							
			//Store_SQLQuery(m_szVoucherCreateTableQuery ,SQLCallback_VoidVoucher, 0);
			SQL_TVoid(g_hDatabase, m_szVoucherCreateTableQuery);
			
			//Fix for no default value errors
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_voucher MODIFY COLUMN voucher varchar(64) NOT NULL DEFAULT ' '");
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_voucher MODIFY COLUMN name_of_create varchar(64) NOT NULL DEFAULT ' '");
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_voucher MODIFY COLUMN steam_of_create varchar(64) NOT NULL DEFAULT ' '");
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_voucher MODIFY COLUMN name_of_redeem varchar(64) NOT NULL DEFAULT ' '");
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_voucher MODIFY COLUMN steam_of_redeem varchar(64) NOT NULL DEFAULT ' '");
		}
		else
		{
			Format(m_szVoucherCreateTableQuery, sizeof(m_szVoucherCreateTableQuery), "CREATE TABLE if NOT EXISTS `store_voucher` (\
										  `voucher` varchar(64) NOT NULL,\
										  `name_of_create` varchar(64) NOT NULL,\
										  `steam_of_create` varchar(64) NOT NULL,\
										  `credits` INT NOT NULL default '0',\
										  `item` varchar(64),\
										  `date_of_create` INT NOT NULL default '0',\
										  `date_of_redeem` INT NOT NULL default '0',\
										  `name_of_redeem` varchar(64),\
										  `steam_of_redeem` TEXT,\
										  `unlimited` TINYINT NOT NULL default '0',\
										  `date_of_expiration` INT NOT NULL default '0',\
										  `item_expiration` INT default NULL);");							
			//Store_SQLQuery(m_szVoucherCreateTableQuery ,SQLCallback_VoidVoucher, 0);
			SQL_TVoid(g_hDatabase, m_szVoucherCreateTableQuery);
		}
		
		//Do some housekeeping
		char m_szVoucherQuery[2048];
		Format(m_szVoucherQuery, sizeof(m_szVoucherQuery), "UPDATE store_voucher SET"
										... " name_of_redeem = \"voucher's item expired\","
										... " date_of_redeem = %d,"
										... " steam_of_redeem = \"voucher's item expired\","
										... " item_expiration = 0 "
										... "WHERE item_expiration <> 0 AND item_expiration < %d", GetTime(), GetTime());
		//Store_SQLQuery(m_szVoucherQuery, SQLCallback_VoidVoucher, 0);
		SQL_TVoid(g_hDatabase, m_szVoucherQuery);
		
		Format(m_szVoucherQuery, sizeof(m_szVoucherQuery), "UPDATE store_voucher SET"
										... " name_of_redeem = \"voucher expired\","
										... " date_of_redeem = %d,"
										... " steam_of_redeem = \"voucher expired\","
										... " item_expiration = 0 "
										... "WHERE date_of_expiration < %d", GetTime(), GetTime());
		//Store_SQLQuery(m_szVoucherQuery, SQLCallback_VoidVoucher, 0);
		SQL_TVoid(g_hDatabase, m_szVoucherQuery);
	}
}

public Action Command_Say(int client, const char[] command,int argc)
{
	//Vouncher
	if (g_iChatType[client] == -1)
		return Plugin_Continue;

	char sMessage[64];
	GetCmdArgString(sMessage, sizeof(sMessage));
	StripQuotes(sMessage);

	delete g_hTimerInput[client];

	switch(g_iChatType[client])
	{
		case PURCHASE:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			if (amount > Store_GetClientCredits(client))
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Voucher Not Enough");
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			g_iTempAmount[client] = amount;
			g_iChatType[client] = -1;

			char sBuffer[32];
			GenerateVoucherCode(sBuffer, sizeof(sBuffer));
			//SQL_WriteVoucher(client, sBuffer, g_iTempAmount[client], false);
			SQL_WriteVoucherCredits(client, sBuffer, g_iTempAmount[client], false);
			g_iLastQuery[client] = GetTime();
		}
		case NUM:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			g_iCreateNum[client] = amount;
			g_iChatType[client] = MIN;

			Panel_Multi(client, 5);
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
		case MIN:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			g_iCreateMin[client] = amount;
			g_iChatType[client] = MAX;

			Panel_Multi(client, 6);
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
		case MAX:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			if (amount < g_iCreateMin[client])
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Smaller than min value", g_iCreateMin[client]);
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			g_iCreateMax[client] = amount;
			g_iChatType[client] = -1;

			Menu_CreateVoucherLimit(client);
		}
		case REDEEM:
		{
			if (strlen(sMessage) != 17)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong voucher code format");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iChatType[client] = -1;

			SQL_FetchVoucher(client, sMessage);
		}
		case CHECK:
		{
			if (strlen(sMessage) != 17)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong voucher code format");
				Menu_Voucher(client);
				return Plugin_Handled;
			}

			g_iChatType[client] = -1;

			SQL_CheckVoucher(client, sMessage);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Voucher(int client, int args)
{
	if (client == 0)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	Menu_Voucher(client);

	return Plugin_Handled;
}

public Action Command_CreateVoucherCode(int client, int args)
{
	if (client == 0)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (args < 2)
	{
		CPrintToChat(client, "%s%s", g_sChatPrefix, "Usage: sm_createvoucher <quantity> \"<min_amount>/<max_amount>\" [0/1] [VoucherCode17char]");

		return Plugin_Handled;
	}

	char sBuffer[64], sParts[2][64];

	GetCmdArg(1, sBuffer, sizeof(sBuffer));
	int iNum = StringToInt(sBuffer);

	GetCmdArg(2, sBuffer, sizeof(sBuffer));
	int iCount = ExplodeString(sBuffer, "/", sParts, 2, 64);
	int iNum1 = StringToInt(sParts[0]);
	int iNum2 =StringToInt(sParts[1]);
	bool bUnlimited = false;

	if (args == 3)
	{
		GetCmdArg(3, sBuffer, sizeof(sBuffer));
		bUnlimited = view_as<bool>(StringToInt(sBuffer));
	}

	if (args == 4)
	{
		GetCmdArg(4, sBuffer, sizeof(sBuffer));
		
		if (strlen(sBuffer) != 17)
		{
			CPrintToChat(client, "%s %t", g_sChatPrefix, "Voucher Code 17 chars");

			return Plugin_Handled;
		}
	}

	if (iCount == 1)
	{
		CPrintToChat(client, "%s %t", g_sChatPrefix, "Voucher admin generated",
							iNum, bUnlimited == true ? "un" : "", iNum == 1 ? "" : "s", iNum1, g_sCreditsName);
	}
	else 
	{
		if(iNum1 > iNum2)
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher min out of max");
		}
		else
		{
			CPrintToChat(client, "%s %t", g_sChatPrefix, "Voucher admin min max generated",
							iNum, bUnlimited == true ? "un" : "", iNum == 1 ? "" : "s", iNum1, iNum2, g_sCreditsName);
		}
	}

	for (int i = 0; i < iNum; i++)
	{
		if (args < 4)
		{
			GenerateVoucherCode(sBuffer, sizeof(sBuffer));
		}

		//SQL_WriteVoucher(client, sBuffer, GetRandomInt(iNum1, iNum2), bUnlimited);
		SQL_WriteVoucherCreditsAdmin(client, sBuffer, GetRandomInt(iNum1, iNum2), bUnlimited);
		PrintToConsole(client, "%t", "Voucher in console", sBuffer);
	}

	return Plugin_Handled;
}

bool GenerateVoucherCode(char[] sBuffer, int maxlen)
{
	char sListOfChar[36][1] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"};

	if (sBuffer[0])
	{
		sBuffer[0] = '\0';
	}

	for (int i = 0; i < 17; i++)
	{
		if (i == 5 || i == 11)
		{
			StrCat(sBuffer, maxlen, "-");
		}
		else
		{
			StrCat(sBuffer, maxlen, sListOfChar[GetRandomInt(0, sizeof(sListOfChar) - 1)]);
		}
	}

	return true;
}

void Menu_Voucher(int client)
{
	char sBuffer[96];
	int i_Credits = Store_GetClientCredits(client); // Get credits
	Menu menu = CreateMenu(Handler_Voucher);
	g_iChatType[client] = -1;

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", "Title Credits", i_Credits);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Redeem Voucher");
	menu.AddItem("1", sBuffer);

	if (GetUserFlagBits(client) & (ADMFLAG_ROOT) == (ADMFLAG_ROOT) || g_eCvars[gc_bCheckAdmin].aCache)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Check Voucher");
		menu.AddItem("2", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t (%t)", "Check Voucher", "admin");
		menu.AddItem("2", sBuffer, ITEMDRAW_DISABLED);
	}

	if (g_eCvars[gc_bCreditVoucherEnabled].aCache)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Purchase Voucher");
		menu.AddItem("6", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Purchase Voucher");
		menu.AddItem("6", sBuffer, ITEMDRAW_DISABLED);
	}

	if (GetUserFlagBits(client) & (ADMFLAG_ROOT) == (ADMFLAG_ROOT))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Create Voucher");
		menu.AddItem("4", sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Create Voucher");
		menu.AddItem("4", sBuffer, ITEMDRAW_DISABLED);
	}
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Check Your valid Voucher");
	menu.AddItem("5", sBuffer);
	
	if (GetUserFlagBits(client) & (ADMFLAG_ROOT) == (ADMFLAG_ROOT))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Check All Voucher");
		menu.AddItem("3", sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Check All Voucher");
		menu.AddItem("3", sBuffer, ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_Voucher(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sBuffer[64];
		menu.GetItem(itemNum, sBuffer, sizeof(sBuffer));
		int num = StringToInt(sBuffer);

		switch(num)
		{
			case REDEEM: // Redeem
			{
				if (g_iLastQuery[client] + g_eCvars[gc_iMySQLCooldown].aCache < GetTime())
				{
					g_iChatType[client] = REDEEM;

					Panel_Multi(client, 4);
				}
				else
				{
					Menu_Voucher(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "SQL Cooldown");
				}
				
				delete g_hTimerInput[client];
				g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
			}
			case CHECK: //Check
			{
				if (g_iLastQuery[client] + g_eCvars[gc_iMySQLCooldown].aCache < GetTime())
				{
					g_iChatType[client] = CHECK;

					Panel_Multi(client, 4);
				}
				else
				{
					Menu_Voucher(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "SQL Cooldown");
				}
				
				delete g_hTimerInput[client];
				g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
			}
			case PURCHASE: // Purchase
			{
				if (g_iLastQuery[client] + g_eCvars[gc_iMySQLCooldown].aCache < GetTime())
				{
					g_iChatType[client] = PURCHASE;

					Panel_Multi(client, 3);
				}
				else
				{
					Menu_Voucher(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "SQL Cooldown");
				}
				
				delete g_hTimerInput[client];
				g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
			}
			case 4: //Generate
			{
				g_iChatType[client] = NUM;

				Panel_Multi(client, 2);
				
				delete g_hTimerInput[client];
				g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
			}
			
			case 5: //Check client valid voucher
			{
				cmdCheckValidVoucher(client);
			}
			
			case 3: //Check client valid voucher
			{
				cmdCheckAllValidVoucher(client);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void Menu_CreateVoucherLimit(int client)
{
	char sBuffer[128];
	int i_Credits = Store_GetClientCredits(client); // Get credits
	Menu menu = CreateMenu(Handler_Createunlimited);

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", "Title Credits", i_Credits);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s", "Limited");
	menu.AddItem("limited", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s", "Unlimited");
	menu.AddItem("unlimited", sBuffer);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_Createunlimited(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sBuffer[32];
		bool bUnlimited = false;
		menu.GetItem(itemNum, sBuffer, sizeof(sBuffer));

		if (strcmp(sBuffer, "unlimited") == 0)
		{
			bUnlimited = true;
		}

		for (int i = 0; i < g_iCreateNum[client]; i++)
		{
			GenerateVoucherCode(sBuffer, sizeof(sBuffer));

			SQL_WriteVoucherCreditsAdmin(client, sBuffer, GetRandomInt(g_iCreateMin[client], g_iCreateMax[client]), bUnlimited);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
		{
			Menu_Voucher(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/******************************************************************************
                   Panel
******************************************************************************/

void Panel_Multi(int client, int num)
{
	char sBuffer[255];
	int i_Credits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", "Title Credits", i_Credits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");

	switch(num)
	{
		case 1:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "To late chat input");
			panel.DrawText(sBuffer);
			Format(sBuffer, sizeof(sBuffer), "%t", "Start again from begin");
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Close");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancel, 14);
		}
		case 2:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter number of vouchers");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_eCvars[g_fInputTime].aCache));

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
		case 3:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter value of vouchers");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_eCvars[g_fInputTime].aCache));

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
		case 4:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter voucher code");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Close");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancel, 14);

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
		case 5:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter minimum value");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);

			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_eCvars[g_fInputTime].aCache)); // open info Panel

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
		case 6:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter maximum value");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);

			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_eCvars[g_fInputTime].aCache)); // open info Panel

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_eCvars[g_fInputTime].aCache, Timer_Input2Late, GetClientUserId(client));
		}
	}

	delete panel;
}


void Panel_VoucherPurchaseSuccess(int client, int credits = 0, char[] voucher, char[] uniqueID = "")
{
	char sBuffer[255];
	int i_Credits = Store_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", "Title Credits", i_Credits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Succesfully purchased voucher");
	panel.DrawText(sBuffer);

	if (!credits)
	{
		Store_Item item;
		Type_Handler handler;

		int itemid = Store_GetItemIdbyUniqueId(uniqueID);

		Store_GetItem(itemid, item);

		Store_GetHandler(item.iHandler, handler);


		Format(sBuffer, sizeof(sBuffer), "%t", "Voucher item", item.szName, handler.szType);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Voucher Value", credits, g_sCreditsName);

	}

	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher in chat and console");
	panel.DrawText(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_NullCancelVoucher, MENU_TIME_FOREVER); // open info Panel
	delete panel;
}


void Panel_VoucherAccept(int client, int credits, char[] voucher, char[] uniqueID)
{
	char sBuffer[255];
	int i_Credits = Store_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", "Title Credits", i_Credits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher accepted Panel");
	panel.DrawText(sBuffer);

	if (!credits)
	{
		Store_Item item;
		Type_Handler handler;

		int itemid = Store_GetItemIdbyUniqueId(uniqueID);

		Store_GetItem(itemid, item);

		Store_GetHandler(item.iHandler, handler);

		Format(sBuffer, sizeof(sBuffer), "%t", "You get x item Panel", item.szName, handler.szType);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "You get x Credits Panel", credits, g_sCreditsName);
	}

	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_NullCancelVoucher, 14); // open info Panel

	delete panel;
}

// Menu Handler for Panels
public int Handler_NullCancelInput(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		delete g_hTimerInput[client];
		g_iChatType[client] = -1;
		EmitSoundToClient(client, g_sMenuExit);
		return;
	}

	return;
}

// Menu Handler for Panels
public int Handler_NullCancel(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			default: // cancel
			{
				delete g_hTimerInput[param1];
				return;
			}
		}
	}

	return;
}


// Menu Handler for Panels
public int Handler_NullCancelVoucher(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2) 
		{
			default: // cancel
			{
				delete g_hTimerInput[client];
				Menu_Voucher(client);
				
				EmitSoundToClient(client, g_sMenuExit);
				return;
			}
		}
	}

	return;
}

public Action Timer_Input2Late(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	g_iChatType[client] = -1;

	Panel_Multi(client, 1);

	EmitSoundToClient(client, g_sMenuExit);

	g_hTimerInput[client] = null;
	return Plugin_Stop;
}

/******************************************************************************
                  Client command to check their valid voucher
******************************************************************************/
void cmdCheckValidVoucher(int client) 
{
	char showOffVoucherQuery[1024], player_authid[255];
	GetClientAuthId(client, AuthId_Steam2, player_authid, sizeof(player_authid));
	Format(showOffVoucherQuery, sizeof(showOffVoucherQuery), "SELECT `voucher`, `date_of_expiration` FROM `store_voucher` WHERE steam_of_create = '%s' AND date_of_redeem = '0';", player_authid);
	//SQL_TQuery(g_hDatabase, SQLshowOffVoucherQuery, showOffVoucherQuery, client);
	Store_SQLQuery(showOffVoucherQuery, SQLshowOffVoucherQuery, client);
}
public void SQLshowOffVoucherQuery(Database db, DBResultSet results, const char[] error, any data) 
{
	int client = data;
	Menu showOffMenu = CreateMenu(noMenuHandler);
	SetMenuTitle(showOffMenu, "%t", "Client valid voucher");

	while (SQL_FetchRow(results))
	{
		char sVoucher[30], sBuffer[1024];
		SQL_FetchString(results, 0, sVoucher, sizeof(sVoucher));
		//SQL_FetchString(results, 1, date_of_expiration, sizeof(date_of_expiration));
		int date_of_expiration = SQL_FetchInt(results, 1);
		FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
		Format(sBuffer, sizeof(sBuffer), "%s (%s)", sVoucher, sBuffer);
		AddMenuItem(showOffMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}
	SetMenuExitBackButton(showOffMenu, true);
	DisplayMenu(showOffMenu, client, 60);
}

/******************************************************************************
                  Admin command to check all valid voucher
******************************************************************************/
void cmdCheckAllValidVoucher(int client) 
{
	char showOffVoucherQuery[1024];
	Format(showOffVoucherQuery, sizeof(showOffVoucherQuery), "SELECT `voucher`, `name_of_create`, `date_of_expiration` FROM `store_voucher` WHERE date_of_redeem = '0';");
	//SQL_TQuery(g_hDatabase, SQLshowOffVoucherQuery, showOffVoucherQuery, client);
	Store_SQLQuery(showOffVoucherQuery, SQLshowOffAllVoucherQuery, client);
}
public void SQLshowOffAllVoucherQuery(Database db, DBResultSet results, const char[] error, any data) 
{
	int client = data;
	Menu showOffMenu = CreateMenu(noMenuHandler);
	SetMenuTitle(showOffMenu, "%t", "All valid voucher");

	while (SQL_FetchRow(results))
	{
		char sVoucher[30], name[64], sBuffer[1024];
		SQL_FetchString(results, 0, sVoucher, sizeof(sVoucher));
		SQL_FetchString(results, 1, name, sizeof(name));
		int date_of_expiration = SQL_FetchInt(results, 2);
		FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
		Format(sBuffer, sizeof(sBuffer), "%s (%s) (%s)", sVoucher, name, sBuffer);
		AddMenuItem(showOffMenu, "", sBuffer, ITEMDRAW_DISABLED);
	}
	SetMenuExitBackButton(showOffMenu, true);
	DisplayMenu(showOffMenu, client, 60);
}

public int noMenuHandler(Handle menu, MenuAction action, int client, int param2) 
{  
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Menu_Voucher(client);
}
/******************************************************************************
                  End
******************************************************************************/

/******************************************************************************
                  Check for core.cfg config
******************************************************************************/
public void SQLTXNCallback_Success(Database db, float time, int numQueries, Handle[] results, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	PrintToServer("Store Vouchers - Transaction Complete - Querys: %i in %0.2f seconds", numQueries, querytime);
}

public void SQLTXNCallback_Error(Database db, float time, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	LogMessage("SQLTXNCallback_Error: %s - Querys: %i - FailedIndex: %i after %0.2f seconds", error, numQueries, failIndex, querytime);
}


/******************************************************************************
                  SQL query and Generate Voucher
******************************************************************************/
void SQL_WriteVoucher(int client, char[] voucher, int credits = 0, bool unlimited = false, char[] uniqueID = "")
{
	// steam id
	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	// player name
	char name[64];
	GetClientName(client, name, sizeof(name));
	Store_SQLEscape(name);
	Store_SQLEscape(voucher);

	int time = GetTime();

	char sQuery[1024];
	int expire_date;
	if (!StrEqual(uniqueID[0], ""))
	{
		Client_Item item;
		//Type_Handler handler;

		int itemidtemp = Store_GetItemIdbyUniqueId(uniqueID);

		Store_GetClientItem(client, itemidtemp, item);
		//int uids = Store_GetClientItemId(client, itemidtemp);
		//int expire_date = g_eClientItems[client][uids][iDateOfExpiration];
		expire_date = item.iDateOfExpiration;

		// Query
		Format(sQuery, sizeof(sQuery), "INSERT INTO `store_voucher` "
		... "(`voucher`, `name_of_create`, `steam_of_create`, `credits`, `item`, `date_of_create`, `unlimited`, `date_of_expiration`, `item_expiration`)"
		... "VALUES ('%s', '%s', '%s', '%i', '%s', '%i', '%i', '%i', '%i')", 
			voucher, name, steamid, credits, uniqueID, time, 
			view_as<int>(unlimited), 
			g_eCvars[gc_iExpireTime].aCache == 0 ? 0 : GetTime() + g_eCvars[gc_iExpireTime].aCache*60*60, expire_date);
	}
	else
	{
		Format(sQuery, sizeof(sQuery), "INSERT INTO `store_voucher` "
		... "(`voucher`, `name_of_create`, `steam_of_create`, `credits`, `item`, `date_of_create`, `unlimited`, `date_of_expiration`)"
		... "VALUES ('%s', '%s', '%s', '%i', '%s', '%i', '%i', '%i')", 
			voucher, name, steamid, credits, uniqueID, time, 
			view_as<int>(unlimited), 
			g_eCvars[gc_iExpireTime].aCache == 0 ? 0 : GetTime() + g_eCvars[gc_iExpireTime].aCache*60*60);
	}
	
	DataPack pack = new DataPack();
	pack.WriteCell(time);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(credits);
	pack.WriteString(voucher);
	pack.WriteString(uniqueID);

	//SQL_TQuery(g_hDatabase, SQLCallback_Write, sQuery, pack);
	Store_SQLQuery(sQuery, SQLCallback_Write, pack);

}

//public void SQLCallback_Write(Handle owner, Handle query, const char[] error, DataPack pack)
public void SQLCallback_Write(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int time = pack.ReadCell();

	if (!StrEqual("", error))
	{
		int client = GetClientOfUserId(pack.ReadCell());
		Store_SQLLogMessage(client, 0, "SQLCallback_Write: Error: %s", error);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Creating voucher failed", time);

		EmitSoundToClient(client, g_sMenuExit);
		delete pack;
		return;
	}

	char sVoucher[64];
	int client = GetClientOfUserId(pack.ReadCell());
	int credits = pack.ReadCell();
	pack.ReadString(sVoucher, sizeof(sVoucher));
	char sUniqueID[64];
	pack.ReadString(sUniqueID, sizeof(sUniqueID));
	delete pack;

	int itemid = Store_GetItemIdbyUniqueId(sUniqueID);

	if (itemid == -1)
	{
		Menu_Voucher(client);
		EmitSoundToClient(client, g_sMenuExit);
		return;
	}

	Store_Item item;
	Type_Handler handler;

	Store_GetItem(itemid, item);

	Store_GetHandler(item.iHandler, handler);

	Store_RemoveItem(client, itemid);
	Panel_VoucherPurchaseSuccess(client, credits, sVoucher, item.szUniqueId);
	LogMessage("Purchase Voucher: %s", sVoucher);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Item Voucher in chat", item.szName, handler.szType, sVoucher);	
	
	PrintToConsole(client, "%t", "Voucher in console", sVoucher);
}

void SQL_WriteVoucherCredits(int client, char[] voucher, int credits = 0, bool unlimited = false, char[] uniqueID = "")
{
	// steam id
	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	// player name
	char name[64];
	GetClientName(client, name, sizeof(name));
	Store_SQLEscape(name);
	Store_SQLEscape(voucher);

	int time = GetTime();

	char sQuery[1024];

	Format(sQuery, sizeof(sQuery), "INSERT INTO `store_voucher` "
	... "(`voucher`, `name_of_create`, `steam_of_create`, `credits`, `item`, `date_of_create`, `unlimited`, `date_of_expiration`)"
	... "VALUES ('%s', '%s', '%s', '%i', '%s', '%i', '%i', '%i')", 
		voucher, name, steamid, credits, uniqueID, time, 
		view_as<int>(unlimited), 
		g_eCvars[gc_iExpireTime].aCache == 0 ? 0 : GetTime() + g_eCvars[gc_iExpireTime].aCache*60*60);
	
	
	DataPack pack = new DataPack();
	pack.WriteCell(time);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(credits);
	pack.WriteString(voucher);
	pack.WriteString(uniqueID);

	Store_SQLQuery(sQuery, SQLCallback_WriteCredits, pack);

}

public void SQLCallback_WriteCredits(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int time = pack.ReadCell();

	if (!StrEqual("", error))
	{
		int client = GetClientOfUserId(pack.ReadCell());
		Store_SQLLogMessage(client, 0, "SQLCallback_WriteCredits: Error: %s", error);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Creating voucher failed", time);

		EmitSoundToClient(client, g_sMenuExit);
		delete pack;
		return;
	}

	char sVoucher[64];
	int client = GetClientOfUserId(pack.ReadCell());
	int credits = pack.ReadCell();
	pack.ReadString(sVoucher, sizeof(sVoucher));
	char sUniqueID[1024];
	pack.ReadString(sUniqueID, sizeof(sUniqueID));
	delete pack;

	
	Panel_VoucherPurchaseSuccess(client, credits, sVoucher);
	LogMessage("Purchase Voucher: %s", sVoucher);

	//g_eClients[client][iCredits] -= credits;
	Store_SetClientCredits(client, Store_GetClientCredits(client) - credits);
	CPrintToChat(client, "%s %t", g_sChatPrefix, "Voucher in chat", sVoucher, credits, g_sCreditsName);

	PrintToConsole(client, "%t", "Voucher in console", sVoucher);
	
}

void SQL_WriteVoucherCreditsAdmin(int client, char[] voucher, int credits = 0, bool unlimited = false, char[] uniqueID = "")
{
	// steam id
	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	// player name
	char name[64];
	GetClientName(client, name, sizeof(name));
	Store_SQLEscape(name);
	Store_SQLEscape(voucher);

	int time = GetTime();

	char sQuery[1024];

	Format(sQuery, sizeof(sQuery), "INSERT INTO `store_voucher` "
	... "(`voucher`, `name_of_create`, `steam_of_create`, `credits`, `item`, `date_of_create`, `unlimited`, `date_of_expiration`)"
	... "VALUES ('%s', '%s', '%s', '%i', '%s', '%i', '%i', '%i')", 
		voucher, name, steamid, credits, uniqueID, time, 
		view_as<int>(unlimited), 
		g_eCvars[gc_iExpireTime].aCache == 0 ? 0 : GetTime() + g_eCvars[gc_iExpireTime].aCache*60*60);
	
	
	DataPack pack = new DataPack();
	pack.WriteCell(time);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(credits);
	pack.WriteString(voucher);
	pack.WriteString(uniqueID);

	Store_SQLQuery(sQuery, SQLCallback_WriteCreditsAdmin, pack);

}

public void SQLCallback_WriteCreditsAdmin(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int time = pack.ReadCell();

	if (!StrEqual("", error))
	{
		int client = GetClientOfUserId(pack.ReadCell());
		Store_SQLLogMessage(client, 0, "SQLCallback_WriteCreditsAdmin: Error: %s", error);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Creating voucher failed", time);

		EmitSoundToClient(client, g_sMenuExit);
		delete pack;
		return;
	}

	char sVoucher[64];
	int client = GetClientOfUserId(pack.ReadCell());
	int credits = pack.ReadCell();
	pack.ReadString(sVoucher, sizeof(sVoucher));
	char sUniqueID[1024];
	pack.ReadString(sUniqueID, sizeof(sUniqueID));
	delete pack;

	
	Panel_VoucherPurchaseSuccess(client, credits, sVoucher);
	LogMessage("Purchase Voucher: %s", sVoucher);

	CPrintToChat(client, "%s %t", g_sChatPrefix, "Voucher in chat", sVoucher, credits, g_sCreditsName);

	PrintToConsole(client, "%t", "Voucher in console", sVoucher);
	
}


void SQL_FetchVoucher(int client, char[] voucher)
{
	Store_SQLEscape(voucher);
	StringToUpper(voucher);

	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), 
		"SELECT `credits`, `item`, `date_of_expiration`, `date_of_redeem`, `unlimited`, `steam_of_redeem`, `item_expiration` FROM `store_voucher` WHERE `voucher` = '%s'", voucher);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(voucher);

	Store_SQLQuery(sQuery, SQLCallback_Fetch, pack);

}

public void SQLCallback_Fetch(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (results == null)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		Store_SQLLogMessage(client, 0, "SQLCallback_Fetch: Error: %s", error);
	}
	else
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		if (!client)
			return;

		char voucher[18];
		pack.ReadString(voucher, sizeof(voucher));
		delete pack;

		if (results.FetchRow())
		{
			// steam id
			char steamid[24];
			if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
				return;

			char sBuffer[64];
			char sItem[64];
			char sRedeems[21845];
			int credits = results.FetchInt(0);
			results.FetchString(1, sItem, sizeof(sItem));
			int date_of_expiration = results.FetchInt(2);
			int date_of_redeem = results.FetchInt(3);
			bool unlimited = view_as<bool>(results.FetchInt(4));
			results.FetchString(5, sRedeems, sizeof(sRedeems));
			int item_expiration = results.FetchInt(6);

			if (GetTime() > date_of_expiration && date_of_expiration != 0)
			{
				Menu_Voucher(client);

				EmitSoundToClient(client, g_sMenuExit);

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher expired", sBuffer);
			}
			else if (date_of_redeem > 0 && !unlimited)
			{
				Menu_Voucher(client);

				EmitSoundToClient(client, g_sMenuExit);

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_redeem);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher already redeemed", sBuffer );
			}
			else if (StrContains(sRedeems, steamid[8], true) != -1)
			{
				Menu_Voucher(client);

				EmitSoundToClient(client, g_sMenuExit);

				CPrintToChat(client, "%s%t", g_sChatPrefix, "You already redeemed Voucher");
			}
			else
			{
				// player name
				char name[64];
				GetClientName(client, name, sizeof(name));
				Store_SQLEscape(name);

				char szBuffer[64];

				if (!credits)
				{
					int itemid = Store_GetItemIdbyUniqueId(sItem);

					if (itemid == -1)
					{
						Menu_Voucher(client);
						EmitSoundToClient(client, g_sMenuExit);
						return;
					}

					Store_Item item;
					Store_GetItem(itemid, item);

					if (Store_HasClientItem(client, itemid))
					{
						Menu_Voucher(client);
						CPrintToChat(client, "%s%t", g_sChatPrefix, "You already own Voucher item");
						EmitSoundToClient(client, g_sMenuExit);
						return;
					}
					else
					{
						//Store_GiveItem(client, itemid, _, GetTime() + 86400, item[iPrice]);
						if(item_expiration !=0)
						{
							Store_GiveItem(client, itemid, _, GetTime() + (item_expiration - GetTime()), item.iPrice);
						}
						else Store_GiveItem(client, itemid, _, _, item.iPrice);
						Type_Handler handler;
						Store_GetHandler(item.iHandler, handler);
						
						if (item.bPreview)
						{
							Call_StartForward(gf_hPreviewItem);
							Call_PushCell(client);
							Call_PushString(handler.szType);
							Call_PushCell(item.iData);
							Call_Finish();
						}

						CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher accepted");
						CPrintToChat(client, "%s%t", g_sChatPrefix, "You get x item", item.szName, handler.szType);

					}
				}
				else
				{
					Format(szBuffer, sizeof(szBuffer), "Voucher: %s", voucher);
					//Store_SetClientCredits(client, Store_GetClientCredits(client) + credits, szBuffer);
					Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);
					//g_eClients[client][iCredits] += credits;
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher accepted");
					CPrintToChat(client, "%s%t", g_sChatPrefix, "You get x Credits", credits, g_sCreditsName);
				}

				if (unlimited && (strlen(sRedeems) > 0))
				{
					if (strlen(sRedeems) > 21845 - 22)  // ~1985 player steam ids minus ~2 steam ids
					{
						int iBreak = BreakString(sRedeems, ",", 1);
						strcopy(sRedeems, sizeof(sRedeems), sRedeems[iBreak]);  // remove first redeem :/  not best i know
					}
					Format(sRedeems, sizeof(sRedeems), "%s,%s", sRedeems, steamid[8]);
				}
				else
				{
					Format(sRedeems, sizeof(sRedeems), "%s", steamid[8]);
				}

				char sQuery[1024];
				Format(sQuery, sizeof(sQuery), "UPDATE store_voucher SET name_of_redeem = '%s', steam_of_redeem = '%s', date_of_redeem = '%i' WHERE voucher = '%s'", name, sRedeems, GetTime(), voucher);

				Store_SQLQuery(sQuery, SQLCallback_Void, 0);

				Panel_VoucherAccept(client, credits, voucher, sItem);

				Store_SQLLogMessage(client, LOG_EVENT, "Voucher %s redeemed", voucher);

			}
		}
		else
		{
			Menu_Voucher(client);

			EmitSoundToClient(client, g_sMenuExit);

			CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher invalid", voucher);
		}
	}
}

void SQL_CheckVoucher(int client, char[] voucher)
{
	Store_SQLEscape(voucher);
	StringToUpper(voucher);

	char sQuery[1024];
	Format(sQuery, sizeof(sQuery),
		"SELECT credits, item, date_of_expiration, date_of_redeem, unlimited, steam_of_redeem FROM store_voucher WHERE voucher = '%s'", voucher);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(voucher);

	Store_SQLQuery(sQuery, SQLCallback_Check, pack);
}

public void SQLCallback_Check(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (results == null)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		Store_SQLLogMessage(client, LOG_ERROR, "SQLCallback_Check: Error: %s", error);
	}
	else
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		if (!client)
			return;

		char voucher[18];
		pack.ReadString(voucher, sizeof(voucher));
		delete pack;

		if (results.FetchRow())
		{
			// steam id
			char steamid[24];
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

			char sBuffer[256];
			char sItem[64];
			char sRedeems[21845];
			int credits = results.FetchInt(0);
			results.FetchString(1, sItem, sizeof(sItem));
			int date_of_expiration = results.FetchInt(2);
			int date_of_redeem = results.FetchInt(3);
			bool unlimited = view_as<bool>(results.FetchInt(4));
			results.FetchString(5, sRedeems, sizeof(sRedeems));

			Panel panel = new Panel();

			int i_Credits = Store_GetClientCredits(client); // Get credits

			Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", "Title Credits", i_Credits);
			panel.SetTitle(sBuffer);

			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			bool expire = false;
			bool redeemedme = false;
			bool redeemenotunlimited = false;

			if (GetTime() > date_of_expiration && date_of_expiration != 0)
			{
				EmitSoundToClient(client, g_sMenuExit);

				expire = true;

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher expired", sBuffer);
			}
			else if (StrContains(sRedeems, steamid[8], true) != -1)
			{
				EmitSoundToClient(client, g_sMenuExit);

				redeemedme = true;

				Format(sBuffer, sizeof(sBuffer), "%t", "You already redeemed Voucher");
			}
			else if (date_of_redeem > 0 && !unlimited)
			{
				EmitSoundToClient(client, g_sMenuExit);

				redeemenotunlimited = true;

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_redeem);
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher already redeemed", sBuffer);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher valid");
			}
			panel.DrawText(sBuffer);

			panel.DrawText(" ");

			if (!credits)
			{
				int itemid = Store_GetItemIdbyUniqueId(sItem);

				if (itemid == -1)
				{
					Menu_Voucher(client);
					EmitSoundToClient(client, g_sMenuExit);
					return;
				}

				Store_Item item;
				Store_GetItem(itemid, item);
				
				Type_Handler handler;
				Store_GetHandler(item.iHandler, handler);

				Format(sBuffer, sizeof(sBuffer), "%t %t", "Voucher item", item.szName, handler.szType, unlimited ? "and is unlimited" : "and is limited");
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t %t", "Voucher Value", credits, g_sCreditsName, unlimited ? "and is unlimited" : "and is limited");
			}
			panel.DrawText(sBuffer);

			if (!expire || redeemedme || !redeemenotunlimited && date_of_expiration != 0)
			{
				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher expire", sBuffer);
				panel.DrawText(sBuffer);
			}

			Format(sBuffer, sizeof(sBuffer), "%t", "Back");
			panel.DrawItem(sBuffer);

			panel.Send(client, Handler_NullCancelVoucher, 14); // open info Panel
			delete panel;
		}
		else
		{
			Menu_Voucher(client);

			EmitSoundToClient(client, g_sMenuExit);

			CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher invalid", voucher);
		}
	}
}

public void SQLCallback_VoidVoucher(Database db, DBResultSet results, const char[] error, any data)
{
	if (!StrEqual("", error))
	{
		Store_SQLLogMessage(0, LOG_ERROR, "SQLCallback_VoidVoucher: Error: %s", error);
	}
}

void StringToUpper(char [] sz)
{
	int len = strlen(sz);

	for (int i = 0; i < len; i++)
	{
		if (IsCharLower(sz[i]))
		{
			sz[i] = CharToUpper(sz[i]);
		}
	}
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

	if (result != SMCError_Okay)
	{
		SMC_GetErrorString(result, error, sizeof(error));
		Store_SQLLogMessage(0, LOG_ERROR, "ReadCoreCFG: Error: %s on line %i, col %i of %s", error, line, col, sFile);
	}
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

public void Voucher_OnMenu(Menu &menu, int client, int itemid)
{
	if (!Store_HasClientItem(client, itemid) || Store_IsItemInBoughtPackage(client, itemid))
		return;

	if (Store_IsClientVIP(client))
		return;
		
	Client_Item itemclient;
	Store_GetClientItem(client, itemid, itemclient);
	if (itemclient.iPriceOfPurchase<=0)
		return;

	Store_Item item;
	Store_GetItem(itemid, item);

	Type_Handler handler;
	Store_GetHandler(item.iHandler, handler);

	char sBuffer[128];
	if(g_eCvars[gc_bItemVoucherEnabled].aCache)
	{
		if (StrEqual(handler.szType, "package"))
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Package Voucher");
			menu.AddItem("voucher_package", sBuffer, ITEMDRAW_DEFAULT);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Voucher");
			menu.AddItem("voucher_item", sBuffer, ITEMDRAW_DEFAULT);
		}
	}
}

public bool Voucher_OnHandler(int client, char[] selection, int itemid)
{
		
	if (strcmp(selection, "voucher_package") == 0 || strcmp(selection, "voucher_item") == 0)
	{
		if(!g_eCvars[gc_bItemVoucherEnabled].aCache)
		{
			//DisplayItemMenu(client, itemid);
			CPrintToChat(client, "%s%t" , g_sChatPrefix, "Item Voucher disabled");
			return false;
		}
			else
			{
			Store_Item item;
			Store_GetItem(itemid, item);

			g_iSelectedItem[client] = itemid;

			Type_Handler handler;
			Store_GetHandler(item.iHandler, handler);

			if (Store_ShouldConfirm())
			{
				char sTitle[1024];
				Format(sTitle, sizeof(sTitle), "%t", "Confirm_Voucher", item.szName, handler.szType);
				Store_DisplayConfirmMenu(client, sTitle, Store_OnConfirmHandler, 1);
			}
			else
			{
				VoucherItem(client, itemid);
				Store_DisplayPreviousMenu(client);
			}

			return true;
		}
	}

	return false;
}

public void Store_OnConfirmHandler(Menu menu, MenuAction action, int client, int param2)
{
	VoucherItem(client, g_iSelectedItem[client]);
}

void VoucherItem(int client, int itemid)
{

	Store_Item item;
	Store_GetItem(itemid, item);

	char sBuffer[1024];
	GenerateVoucherCode(sBuffer, sizeof(sBuffer));
	SQL_WriteVoucher(client, sBuffer, 0, false, item.szUniqueId);
	g_iLastQuery[client] = GetTime();
}