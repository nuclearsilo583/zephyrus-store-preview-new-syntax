#include <sourcemod>
#include <sdktools>
#include <colorvariables>

#include <store>
#include <zephstocks>

//#include <multicolors> 
#include <chat-processor> 


//Uncomment this line if your game is csgo or css.
//#define csgo_css
#if defined csgo_css
#include <cstrike>
#endif

#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

char g_sChatPrefix[128];

KeyValues kvtShop;

//bool check[MAXPLAYERS + 1] = { true, ...};
//bool GAME_CSGO = false;
//bool GAME_CSS = false;

char g_sNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_sNameColors[STORE_MAX_ITEMS][32];
char g_sMessageColors[STORE_MAX_ITEMS][32];
char g_sScoreboardTags[STORE_MAX_ITEMS][64];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;
int g_iScoreboardTags = 0;

ConVar g_cvDatabaseEntry;
Handle g_hDatabase = INVALID_HANDLE;

char g_sEliShop[PLATFORM_MAX_PATH];
bool FileEnable = false;

char g_szColors[MAXPLAYERS + 1][16];
char g_szAuth[MAXPLAYERS + 1][32];
#if defined csgo_css
char g_sTempClanTag[MAXPLAYERS + 1][32];
#endif

public Plugin myinfo = 
{
	name = "Store - Chat Processor item module with Scoreboard Tag",
	author = "nuclear silo, Mesharsky, AiDN™", 
	description = "Chat Processor item module by nuclear silo, the Scoreboard Tag for Zephyrus's by Mesharksy, for nuclear silo's edited store by AiDN™",
	version = "3.1", 
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	
	Store_RegisterHandler("nametag", "tag", _, CPSupport_Reset, NameTags_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("namecolor", "color", _, CPSupport_Reset, NameColors_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("msgcolor", "color", _, CPSupport_Reset, MsgColors_Config, CPSupport_Equip, CPSupport_Remove, true);
	
	#if defined csgo_css
	Store_RegisterHandler("scoreboardtag", "scoreboardtag", _, CPSupport_Reset, ScoreboardTags_Config, ScoreboardTags_Equip, ScoreboardTags_Remove, true);
	PrintToServer("CS:GO, CSS detected as a game engine. The scoreboard tag module will be enabled.");
	
	#else 
	PrintToServer("Can not detected CS:GO, CSS as a game engine. The scoreboard tag module will be disabled.");
	#endif
	
	HookEvent("player_team", PlayerTeam_Callback);
	HookEvent("player_spawn", PlayerSpawn_Callback);
	
	RegConsoleCmd("sm_tgs", Command_TGS);
	
	BuildPath(Path_SM, STRING(g_sEliShop), "configs/store/cpcolors.txt");
	kvtShop = CreateKeyValues("cp_colors");
	FileToKeyValues(kvtShop, g_sEliShop);
	if (!KvGotoFirstSubKey(kvtShop))
	{
		FileEnable = false;
		LogError("Failed to read configs/store/cpcolors.txt - The custom tag color for user will be disabled.");
	}
	else FileEnable = true;
}
#if defined csgo_css
public void OnClientPutInServer(int client)
{
	if(!IsValidClient(client))
        return;

	CS_GetClientClanTag(client, g_sTempClanTag[client], 32);
	
}

public void OnClientCommandKeyValues_Post(int client, KeyValues kv)
{
	char szCommmand[32];
	
	if(kv.GetSectionName(szCommmand, 32) && strcmp(szCommmand, "ClanTagChanged", false) == 0)
		kv.GetString("tag", g_sTempClanTag[client], 32);
}
#endif

public void OnClientPostAdminCheck(int client)
{
	if (!GetClientAuthId(client, AuthId_Steam2, g_szAuth[client], sizeof(g_szAuth)))
	{
		KickClient(client, "Verification problem, Please reconnect");
		return;
	}
	
	SQL_FetchUser(client);
	
	#if defined csgo_css
	Store_SetClientClanTag(client);
	#endif
	
	//CS_GetClientClanTag(client, g_sTempClanTag[client], sizeof(g_sTempClanTag));
}

public void OnClientDisconnect(int client)
{
	//Resetting the variables to prevent users to recieve another players' settings(Ex: as tag. clantag, tag color)
	g_szColors[client][0] = 0;
}

void SQL_FetchUser(int client)
{
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "SELECT `color` FROM `store_cp_perk` WHERE `authId` = '%s'", g_szAuth[client]);
	Store_SQLQuery(szQuery, SQL_FetchUser_CB, GetClientSerial(client));
}

public void SQL_FetchUser_CB(Database db, DBResultSet results, const char[] error, any data)
{
	int iClient = GetClientFromSerial(data);
	if (results == null)
	{
		if (iClient == 0)
		{
			LogError("Client is not valid. Reason: %s", error);
		}
		else
		{
			LogError("Cant use client data on insert. Reason: %s", error);
		}
		return;
	}
	
	if (results.FetchRow())
	{
		results.FetchString(0, g_szColors[iClient], sizeof(g_szColors));
	}
	else 
	{
		if(IsValidClient(iClient))
			SQL_RegisterPerks(iClient);
	}
}

void SQL_RegisterPerks(int client)
{
	char szQuery[512], name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	Store_SQLEscape(name);
	FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `store_cp_perk` (`authId`, `name`) VALUES ('%s', '%s')", g_szAuth[client], name);
	Store_SQLQuery(szQuery, SQL_CheckForErrors, GetClientSerial(client));
}

void SQL_UpdatePerk(int client, char[] value)
{
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `store_cp_perk` SET `color` = '%s' WHERE `authId` = '%s'", value, g_szAuth[client]);
	Store_SQLQuery(szQuery, SQL_CheckForErrors, GetClientSerial(client));
}

public void SQL_CheckForErrors(Database db, DBResultSet results, const char[] error, any data)
{
	if (!StrEqual(error, ""))
	{
		LogError("Database error, %s", error);
		return;
	}
}

public Action Command_TGS(int client, int args)
{
	int m_iEquipped = Store_GetEquippedItem(client, "nametag");
	
	if(!FileEnable)
	{
		CPrintToChat(client, "%s %t", g_sChatPrefix, "CP No file found");
		return Plugin_Handled;
	}
	else if(m_iEquipped >= 0)
	{
		DisplayMenuShop(client);
		return Plugin_Handled;
	}
	else 
	{
		CPrintToChat(client, "%s %t", g_sChatPrefix, "CP No Name Tag Equipped");
	}
	
	return Plugin_Handled;
}

public void Store_OnConfigExecuted(char[] prefix)
{	
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	
	if(FileEnable && !g_hDatabase)
	{
		char buffer[128];
		g_cvDatabaseEntry = FindConVar("sm_store_database");
		g_cvDatabaseEntry.GetString(buffer, 128);
		SQL_TConnect(SQLCallback_Connect, buffer);
	}
}

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
		char m_szCreateTableQuery[2048];
		if(m_szDriver[0] == 'm')
		{
			Format(m_szCreateTableQuery, sizeof(m_szCreateTableQuery), "CREATE TABLE if NOT EXISTS `store_cp_perk` (\
										  `authId` varchar(64) NOT NULL default ' ',\
										  `name` varchar(64) NOT NULL default ' ',\
										  `color` varchar(16) NOT NULL default 'disabled',\
										  UNIQUE (`authid`));");							
			SQL_TVoid(g_hDatabase, m_szCreateTableQuery);
		}
		else
		{
			Format(m_szCreateTableQuery, sizeof(m_szCreateTableQuery), "CREATE TABLE if NOT EXISTS `store_cp_perk` (\
										  `authId` varchar(64) NOT NULL,\
										  `name` varchar(64) NOT NULL default ' ',\
										  `color` varchar(16) NOT NULL default 'disabled',\
										  UNIQUE (`authid`));");							
			//Store_SQLQuery(m_szVoucherCreateTableQuery ,SQLCallback_VoidVoucher, 0);
			SQL_TVoid(g_hDatabase, m_szCreateTableQuery);
		}
	}
}

public int DisplayMenuShop(int client)
{
	//if(GetClientTeam(client) != CS_TEAM_CT) 
	//	return 0;
	Menu shopmenu = new Menu(MenuHandler_Shop);
	
	char sBuffer[255];
	
	Format(sBuffer, sizeof(sBuffer), "%t", "CP Chat Tag Color Option");
	SetMenuTitle(shopmenu, sBuffer);
	SetMenuPagination(shopmenu, 8);
		
	kvtShop.Rewind();

	if (!kvtShop.GotoFirstSubKey())
		return 0;
		
	char ItemID[150], name[50], color[20], flag[8];
	Format(sBuffer, sizeof(sBuffer), "%t", "CP Disable Color - Menu");
	shopmenu.AddItem("disabled", sBuffer);
	do
	{
		kvtShop.GetSectionName(ItemID, sizeof(ItemID));
		kvtShop.GetString("name", name, sizeof(name));
		kvtShop.GetString("color", color, sizeof(color));
		kvtShop.GetString("flag", flag, sizeof(flag), "");
		Format(sBuffer, sizeof(sBuffer), "%s", name);
		shopmenu.AddItem(ItemID, name, HasPermission(client, flag) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	} while (kvtShop.GotoNextKey());
	shopmenu.ExitButton = true;
	shopmenu.Display(client, 20);
	
	return 0;
}

public int MenuHandler_Shop(Menu menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			GetMenuItem(menu, item, info, sizeof(info));
			
			if(StrEqual(info, "disabled"))
			{
				SQL_UpdatePerk(client, "disabled");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "CP Disabled Color", client);
				strcopy(g_szColors[client], sizeof(g_szColors), "disabled");

				//return;
			}
			
			//char configfile[PLATFORM_MAX_PATH];
			//configfile = g_sEliShop;
			
			kvtShop.Rewind();
			if (!kvtShop.JumpToKey(info))
			{
				return 0;
			}
			
			//Main functions
			char sItem[50], name[50];
			kvtShop.GetString("name", name, sizeof(name));
			kvtShop.GetString("color", sItem, sizeof(sItem));

			strcopy(g_szColors[client], sizeof(g_szColors), sItem);

			if(StrEqual(sItem, "rainbow"))
			{
				char rainbow[50];
				Rainbow_String(name, rainbow, sizeof(rainbow));
				CPrintToChat(client, "%s%t%s.", g_sChatPrefix, "CP Changed color", rainbow);
			}
			else
				CPrintToChat(client, "%s%t%s%s.", g_sChatPrefix, "CP Changed color", sItem, name);

			SQL_UpdatePerk(client, sItem);
		}
	}
	
	return 0;
}


//
//	The main plugin system
//
public void CPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
	g_iScoreboardTags = 0;
}

public bool NameTags_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameTags);
	kv.GetString("tag", g_sNameTags[g_iNameTags], sizeof(g_sNameTags[]));
	g_iNameTags++;

	return true;
}

public bool NameColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameColors);
	kv.GetString("color", g_sNameColors[g_iNameColors], sizeof(g_sNameColors[]));
	g_iNameColors++;

	return true;
}

public bool MsgColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iMessageColors);
	kv.GetString("color", g_sMessageColors[g_iMessageColors], sizeof(g_sMessageColors[]));
	g_iMessageColors++;

	return true;
}

public bool ScoreboardTags_Config(KeyValues &kv, int itemid) 
{
	Store_SetDataIndex(itemid, g_iScoreboardTags);

	kv.GetString("scoreboardtag", g_sScoreboardTags[g_iScoreboardTags], sizeof(g_sScoreboardTags[]));
	g_iScoreboardTags++;

	return true;
}

public int CPSupport_Equip(int client, int itemid)
{
	return -1;
}

public int CPSupport_Remove(int client, int itemid)
{
	return 0;
}


public int ScoreboardTags_Equip(int client, int itemid)
{
	#if defined csgo_css
	int m_iData = Store_GetDataIndex(itemid);
	
	CS_SetClientClanTag(client, g_sScoreboardTags[m_iData]);
	#endif
	return -1;
}

public int ScoreboardTags_Remove(int client, int itemid)
{
	#if defined csgo_css
	CS_SetClientClanTag(client, g_sTempClanTag[client]);
	#endif
	return 0;
}


public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	int iEquippedNameTag = Store_GetEquippedItem(author, "nametag");
	int iEquippedNameColor = Store_GetEquippedItem(author, "namecolor");
	int iEquippedMsgColor = Store_GetEquippedItem(author, "msgcolor");

	if (iEquippedNameTag < 0 && iEquippedNameColor < 0 && iEquippedMsgColor < 0)
		return Plugin_Continue;

	//int slited = 0;

	char sName[MAXLENGTH_NAME*2];
	char sNameTag[MAXLENGTH_NAME];
	char sNameTag2[2][MAXLENGTH_NAME];
	//char sNameTag2_0[2][MAXLENGTH_NAME];
	char sNameColor[32];

	if (iEquippedNameTag >= 0)
	{
		int iNameTag = Store_GetDataIndex(iEquippedNameTag);
		strcopy(sNameTag, sizeof(sNameTag), g_sNameTags[iNameTag]);
		ExplodeString(sNameTag, "}", sNameTag2, 2, MAXLENGTH_NAME);
		//PrintToConsoleAll("[0]: %s", sNameTag2[0]); //DEBUG
		//PrintToConsoleAll("[1]: %s", sNameTag2[1]); //DEBUG
	}

	if (iEquippedNameColor >= 0)
	{
		int iNameColor = Store_GetDataIndex(iEquippedNameColor);
		if(StrEqual(g_sNameColors[iNameColor], "rainbow"))
		{
            Rainbow_String(name, sNameColor, sizeof(sNameColor));
			//strcopy(sNameColor, sizeof(sNameColor), g_sNameColors[iNameColor]);
		}
		else strcopy(sNameColor, sizeof(sNameColor), g_sNameColors[iNameColor]);
	}
	
	if(!StrEqual(g_szColors[author], "disabled", true))
	{
		int iNameColor;
		char temp[MAXLENGTH_NAME*2], temp2[MAXLENGTH_NAME*2];
		
		if (iEquippedNameColor >= 0)
		{
			iNameColor = Store_GetDataIndex(iEquippedNameColor);
		}
		
		//if(StrContains(sNameTag, "}", true))
		// Checking if the name tag have } symbol. Ex: {green}[TAG]; [TAG]{default};
		// sNameTag2[1][0] refer to the first string it found. In this case is {green}[TAG]
		if(sNameTag2[1][0] != '\0')
		{
			//PrintToChat(author, "have }"); //Debug
			// the author have name color equipped and their name color is set to rainbow
			if(iEquippedNameColor>=0 && StrEqual(g_sNameColors[iNameColor], "rainbow"))
			{
				// Check if the custom !tgs of the author is rainbow
				if(StrEqual(g_szColors[author], "rainbow"))
				{
					strcopy(temp, sizeof(temp), sNameTag2[1]);
					Rainbow_String(temp, temp2, sizeof(temp2));
					Format(sName, sizeof(sName), "%s{teamcolor}%s", temp2, sNameColor);
				}
				else Format(sName, sizeof(sName), "%s%s{teamcolor}%s", g_szColors[author], sNameTag2[1], sNameColor);
			}
			// the author have name color equipped and custom !tgs is rainbow
			else if(iEquippedNameColor>=0 && StrEqual(g_szColors[author], "rainbow"))
			{
				strcopy(temp, sizeof(temp), sNameTag2[1]);
				Rainbow_String(temp, temp2, sizeof(temp2));
				Format(sName, sizeof(sName), "%s{teamcolor}%s%s", temp2, sNameColor, name);
			}
			// The author  dont have name color equipped but custom !tgs is rainbow
			else if(StrEqual(g_szColors[author], "rainbow"))
			{
				strcopy(temp, sizeof(temp), sNameTag2[1]);
				Rainbow_String(temp, temp2, sizeof(temp2));
				Format(sName, sizeof(sName), "%s{teamcolor}%s%s", temp2, sNameColor, name);
			}
			// Other cases
			else Format(sName, sizeof(sName), "%s%s{teamcolor}%s%s", g_szColors[author], sNameTag2[1], sNameColor, name);
		}
		else // The other case is [TAG]{green}. The slited string will be [TAG]{green and NULL_STRING;
		{
			//PrintToChat(author, "no have }"); // DEBUG
			// the author have name color equipped and name color is set to rainbow.
			if(iEquippedNameColor>=0 && StrEqual(g_sNameColors[iNameColor], "rainbow"))
			{
				// the custom !tgs is rainbow
				if(StrEqual(g_szColors[author], "rainbow"))
				{
					strcopy(temp, sizeof(temp), sNameTag2[0]);
					Rainbow_String(temp, temp2, sizeof(temp2));
					Format(sName, sizeof(sName), "%s{teamcolor}%s", temp2, sNameColor);
				}
				else Format(sName, sizeof(sName), "%s%s{teamcolor}%s", g_szColors[author], sNameTag2[0], sNameColor);
			}
			// the author have name color equipped and custom !tgs is rainbow
			else if(iEquippedNameColor>=0 && StrEqual(g_szColors[author], "rainbow"))
			{
				strcopy(temp, sizeof(temp), sNameTag2[0]);
				Rainbow_String(temp, temp2, sizeof(temp2));
				Format(sName, sizeof(sName), "%s{teamcolor}%s%s", temp2, sNameColor, name);
			}
			// custom !tgs is rainbow.
			else if(StrEqual(g_szColors[author], "rainbow"))
			{
				strcopy(temp, sizeof(temp), sNameTag2[0]);
				Rainbow_String(temp, temp2, sizeof(temp2));
				Format(sName, sizeof(sName), "%s{teamcolor}%s%s", temp2, sNameColor, name);
			}
			else Format(sName, sizeof(sName), "%s%s{teamcolor}%s%s", g_szColors[author], sNameTag, sNameColor, name);
		}
	}
	else 
	{
		int iNameColor;
		if (iEquippedNameColor >= 0)
		{
			iNameColor = Store_GetDataIndex(iEquippedNameColor);
		}
		
		if(iEquippedNameColor>=0 && StrEqual(g_sNameColors[iNameColor], "rainbow"))
		{
			Format(sName, sizeof(sName), "%s{teamcolor}%s", sNameTag, sNameColor);
		}
		else Format(sName, sizeof(sName), "%s{teamcolor}%s%s", sNameTag, sNameColor, name);
	}
	
	//ReplaceColors(sName, sizeof(sName), author);

	strcopy(name, MAXLENGTH_NAME*2, sName);

	if (iEquippedMsgColor >= 0)
	{
		char sMessage[MAXLENGTH_BUFFER];
		int m_iData = Store_GetDataIndex(iEquippedMsgColor);
		strcopy(sMessage, sizeof(sMessage), message);
		if(StrEqual(g_sMessageColors[m_iData], "rainbow"))
        {
            char sBuffer[256];
            Rainbow_String(message, sBuffer, sizeof(sBuffer));
            strcopy(message, MAXLENGTH_MESSAGE, sBuffer);
        }
		else Format(message, MAXLENGTH_BUFFER, "%s%s", g_sMessageColors[Store_GetDataIndex(iEquippedMsgColor)], sMessage);
		//ReplaceColors(message, MAXLENGTH_BUFFER, author);
	}

	return Plugin_Changed;
}

public Action PlayerSpawn_Callback(Event event, const char[] chName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int iEquippedScoreboardTag = Store_GetEquippedItem(client, "scoreboardtag");

	if(iEquippedScoreboardTag < 0)
		return Plugin_Continue;

	char sBuffer[64];
	char ScoreboardTag[64];

	if(iEquippedScoreboardTag >= 0)
	{
		int m_iScoreboardTag = Store_GetDataIndex(iEquippedScoreboardTag);
		strcopy(ScoreboardTag, sizeof(ScoreboardTag), g_sScoreboardTags[m_iScoreboardTag]);
	}

	Format(sBuffer, sizeof(sBuffer), "%s", ScoreboardTag);
	#if defined csgo_css
	CS_SetClientClanTag(client, sBuffer);
	#endif
	return Plugin_Handled;
}

public Action PlayerTeam_Callback(Event event, const char[] chName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int iEquippedScoreboardTag = Store_GetEquippedItem(client, "scoreboardtag");

	if(iEquippedScoreboardTag < 0)
		return Plugin_Continue;

	char sBuffer[64];
	char ScoreboardTag[64];

	if(iEquippedScoreboardTag >= 0)
	{
		int m_iScoreboardTag = Store_GetDataIndex(iEquippedScoreboardTag);
		strcopy(ScoreboardTag, sizeof(ScoreboardTag), g_sScoreboardTags[m_iScoreboardTag]);
	}

	Format(sBuffer, sizeof(sBuffer), "%s", ScoreboardTag);
	#if defined csgo_css
	CS_SetClientClanTag(client, sBuffer);
	#endif
	return Plugin_Handled;
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	char Buffer[255], sBuffer[255], PreviewBuffer[255];
	char clientname[MAX_NAME_LENGTH];
	
	GetClientName(client, clientname, sizeof(clientname));
	
	int temp = GetClientTeam(client);
	switch(temp)
	{
		/*case 2:
		{
			FormatEx(Buffer, sizeof(Buffer), "{orange}%s :", clientname);
		}
		case 3:
		{
			FormatEx(Buffer, sizeof(Buffer), "{bluegrey}%s :", clientname);
		}*/
		case  3: Format(STRING(Buffer), "{steelblue}%s :", clientname);
        case  2: Format(STRING(Buffer), "{yellow}%s :", clientname);
        default: Format(STRING(Buffer), "{engine 3}%s :", clientname);
	}
	
	
	if(StrEqual(type, "nametag"))
	{
		Format(PreviewBuffer, sizeof(PreviewBuffer), "{default}%t", "This is the preview text");
		CPrintToChat(client, "%t", "CP Preview", g_sNameTags[index], Buffer, PreviewBuffer);
		//CPrintToChat(client, "test");
	}
	else if(StrEqual(type, "namecolor"))
	{
		if(StrEqual(g_sNameColors[index], "rainbow"))
		{
			Rainbow_String(clientname, sBuffer, sizeof(sBuffer));
			Format(sBuffer, sizeof(sBuffer), "%s :{default}", sBuffer);
		}
		else
			Format(sBuffer, sizeof(sBuffer), "%s%s :{default}", g_sNameColors[index], clientname);
			
		Format(PreviewBuffer, sizeof(PreviewBuffer), "%t", "This is the preview text");
		CPrintToChat(client, "%t", "CP Preview", " ", sBuffer, PreviewBuffer);
	}
	else if(StrEqual(type, "msgcolor"))
	{
		Format(PreviewBuffer, sizeof(PreviewBuffer), "%t", "This is the preview text");
		
		if(StrEqual(g_sMessageColors[index], "rainbow"))
			Rainbow_String(PreviewBuffer, sBuffer, sizeof(sBuffer));
		else
			Format(sBuffer, sizeof(sBuffer), " %s%s", g_sMessageColors[index], PreviewBuffer);
		CPrintToChat(client, "%t", "CP Preview", " ", Buffer, sBuffer);
	}
	#if defined csgo_css
	else if(StrEqual(type, "scoreboardtag"))
	{
		CS_GetClientClanTag(client, g_sTempClanTag[client], 32);

		CS_SetClientClanTag(client, g_sScoreboardTags[index]);

		CreateTimer(15.0, Clantag, client);

		CPrintToChat(client, "%s%t", g_sChatPrefix, "CP Scoreboard Preview");
	}
	#endif
	else return;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	if (IsClientReplay(client))return false;
	if (IsFakeClient(client))return false;
	if (IsClientSourceTV(client))return false;
	return IsClientInGame(client);
}

public void Store_SetClientClanTag(int client)
{
	int iEquippedScoreboardTag = Store_GetEquippedItem(client, "scoreboardtag");

	if(iEquippedScoreboardTag < 0)
		return;

	char sBuffer[64];
	char ScoreboardTag[64];

	if(iEquippedScoreboardTag >= 0)
	{
		int m_iScoreboardTag = Store_GetDataIndex(iEquippedScoreboardTag);
		strcopy(ScoreboardTag, sizeof(ScoreboardTag), g_sScoreboardTags[m_iScoreboardTag]);
	}

	Format(sBuffer, sizeof(sBuffer), "%s", ScoreboardTag);
	
	#if defined csgo_css
	CS_SetClientClanTag(client, sBuffer);
	#endif
}

#if defined csgo_css
public Action Clantag(Handle timer, int client)
{
	CS_SetClientClanTag(client, g_sTempClanTag[client]);
	
	return Plugin_Handled;
}
#endif

void Rainbow_String(const char[] input, char[] output, int maxLen)
{
	char sTemp[MAXLENGTH_NAME];
	int len = strlen(input);
	for (int i = 0; i < len; i++)
	{
		if (IsCharSpace(input[i]))
		{
			Format(sTemp, sizeof(sTemp), "%s%c", sTemp, input[i]);
			continue;
		}
		
		int bytes = GetCharBytes(input[i]) + 1;
		char[] c = new char[bytes];
		strcopy(c, bytes, input[i]);
		//Format(sTemp, sizeof(sTemp), "%s%c%s", sTemp, GetColor(++color), c);
		Format(sTemp, sizeof(sTemp), "%s%c%s", sTemp, RandomColor(), c);
		if (IsCharMB(input[i]))
			i += bytes - 2;
	}
	
	
	strcopy(output, maxLen, sTemp);
}

void String_Rainbow(const char[] input, char[] output, int maxLen)
{
	int bytes, buffs;
	int size = strlen(input)+1;
	char[] copy = new char [size];

	for(int x = 0; x < size; ++x)
	{
		if(input[x] == '\0')
			break;
		
		if(buffs == 2)
		{
			strcopy(copy, size, input);
			copy[x+1] = '\0';
			output[bytes] = RandomColor();
			bytes++;
			bytes += StrCat(output, maxLen, copy[x-buffs]);
			buffs = 0;
			continue;
		}

		if(!IsChar(input[x]))
		{
			buffs++;
			continue;
		}

		strcopy(copy, size, input);
		copy[x+1] = '\0';
		output[bytes] = RandomColor();
		bytes++;
		bytes += StrCat(output, maxLen, copy[x]);
	}

	output[++bytes] = '\0';
}

bool IsChar(char c)
{
	if(0 <= c <= 126)
		return true;
	
	return false;
}

int RandomColor()
{
	switch(GetRandomInt(1, 13))
	{
		case  1: return '\x0F';
		case  2: return '\x02';
		case  3: return '\x0E';
		case  4: return '\x0C';
		case  5: return '\x04';
		case  6: return '\x05';
		case  7: return '\x06';
		case  8: return '\x07';
		case  9: return '\x08';
		case 10: return '\x09';
		case 11: return '\x10';
		case 12: return '\x0A';
		case 13: return '\x0B';
		default: return '\x07';
	}
}

stock bool HasPermission(int iClient, char[] flagString) 
{
	if (StrEqual(flagString, "")) 
	{
		return true;
	}
	
	AdminId admin = GetUserAdmin(iClient);
	
	if (admin != INVALID_ADMIN_ID)
	{
		int count, found, flags = ReadFlagString(flagString);
		for (int i = 0; i <= 20; i++) 
		{
			if (flags & (1<<i)) 
			{
				count++;
				
				if (GetAdminFlag(admin, view_as<AdminFlag>(i))) 
				{
					found++;
				}
			}
		}

		if (count == found) {
			return true;
		}
	}

	return false;
} 