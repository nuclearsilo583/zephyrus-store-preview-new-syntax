#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <store>
#include <zephstocks>

#include <multicolors>
#include <autoexecconfig>

//#define PLUGINS_ZOMBIE_ENABLE

/*#if defined PLUGINS_ZOMBIE_ENABLE
//Cause loop ThrowNativeError
#include <zombiereloaded>
#endif*/

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#define REQUIRE_EXTENSIONS

#define MAX_OBJECTIVES 10
#define DAY_IN_SECONDS 86400

char g_szName[MAX_OBJECTIVES][32];

bool g_bBots[MAX_OBJECTIVES];
char	g_szNick[MAX_OBJECTIVES][32],
		g_szTag[MAX_OBJECTIVES][32];
float 	g_fNick[MAX_OBJECTIVES],
		g_fTag[MAX_OBJECTIVES],
		g_fGroup[MAX_OBJECTIVES],
		g_fTimer[MAX_OBJECTIVES];
int g_iFlagBits[MAX_OBJECTIVES]
	g_iMsg[MAX_OBJECTIVES],
	g_iMinPlayer[MAX_OBJECTIVES],
	g_iPlay[MAX_OBJECTIVES],
	g_iInactive[MAX_OBJECTIVES],
	g_iKill[MAX_OBJECTIVES],
	g_iTK[MAX_OBJECTIVES],
	g_iSuicide[MAX_OBJECTIVES],
	g_iAssist[MAX_OBJECTIVES],
	g_iHeadshot[MAX_OBJECTIVES],
	g_iNoScope[MAX_OBJECTIVES],
	g_iBackstab[MAX_OBJECTIVES],
	g_iKnife[MAX_OBJECTIVES],
	g_iTaser[MAX_OBJECTIVES],
	g_iHE[MAX_OBJECTIVES],
	g_iFlash[MAX_OBJECTIVES],
	g_iSmoke[MAX_OBJECTIVES],
	g_iMolotov[MAX_OBJECTIVES],
	g_iDecoy[MAX_OBJECTIVES],
	g_iWin[MAX_OBJECTIVES],
	g_iMVP[MAX_OBJECTIVES],
	g_iPlant[MAX_OBJECTIVES],
	g_iDefuse[MAX_OBJECTIVES],
	g_iExplode[MAX_OBJECTIVES],
	g_iRescued[MAX_OBJECTIVES],
	g_iVIPkill[MAX_OBJECTIVES],
	g_iVIPescape[MAX_OBJECTIVES],
	g_iGroup[MAX_OBJECTIVES],
	g_iDaily[MAX_OBJECTIVES][7];

int g_iSum[MAXPLAYERS + 1];
float g_fClientMulti[MAXPLAYERS + 1];

int ConnectTime[MAXPLAYERS + 1];

char g_sChatPrefix[128];
char g_sCreditsName[64] = "credits";
char g_sSteam[256];

bool g_bGroupMember[MAXPLAYERS + 1];
bool gp_bSteamWorks;

ConVar  gc_bFFA,
		gc_sDB;

Cookie  g_cDate,
		g_cDay;

Database g_hDB;
char g_sDBBuffer[400];
int g_iDailyDate[MAXPLAYERS + 1];
int g_iDailyDay[MAXPLAYERS + 1];
//int g_iDailyStart[MAXPLAYERS + 1];
bool g_bDailyCached[MAXPLAYERS + 1];

int g_iActive[MAXPLAYERS + 1];
int g_iCount;

StringMap g_hSum[MAXPLAYERS + 1];

#define ACTIVE 0
#define INACTIVE 1
int g_iTime[MAXPLAYERS + 1][2];

char g_szGameDir[64];
char CurrentDate[20];

public Plugin myinfo = 
{
	name = "Store - Earnings module [TF2]",
	author = "nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "This modules was rework to be working with tf2 by user request.",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	
	// Identify the game
	GetGameFolderName(STRING(g_szGameDir));
	
	if(strcmp(g_szGameDir, "tf")==0)
	{
		PrintToServer("Loaded tf2 as a game engine");
		//GAME_CSS = true;
	}
	else
	{
		SetFailState("This game is not be supported. Please contact the author for support.");
	}

	RegConsoleCmd("sm_daily", Command_Daily, "Receive your daily credits");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	//HookEvent("player_mvp", Event_MVP);
	HookEvent("player_death", Event_PlayerDeath);

	g_cDate = new Cookie("store_date", "Store Daily Date", CookieAccess_Protected);
	g_cDay = new Cookie("store_day", "Store Daily Day", CookieAccess_Protected);
	
	AutoExecConfig_SetFile("earnings", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_sDB = AutoExecConfig_CreateConVar("sm_store_earning_database", "", "The database config name that will be used for daily credits\nKeep empty to use local storage (clientprefs)\nSpecify a MySQL database to sync daily rewards across all your servers");
	
	//AutoExecConfig(true, "earnings", "sourcemod/store")
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	LoadConfig();
}

public void OnLibraryAdded(const char[] name)
{
	if (!StrEqual(name, "SteamWorks"))
		return;

	gp_bSteamWorks = true;
}

// Prepare Plugin & modules
public void OnMapStart()
{
	CreateTimer(1.0, Timer_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int client)
{
	ConnectTime[client] = GetTime();
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;

	g_bGroupMember[client] = false;
	
	ConnectTime[client] = 0;
	
	g_iDailyDate[client] = 0;
	g_iDailyDay[client] = 0;
	//g_iDailyStart[client] = 0;
	g_bDailyCached[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;

	g_iActive[client] = 0;
	g_iSum[client] = 0;
	g_fClientMulti[client] = 1.0;

	g_iTime[client][INACTIVE] = 0;
	g_iTime[client][ACTIVE] = 0;

	for (int i = 0; i < g_iCount; i++)
	{
		if (!CheckFlagBits(client, g_iFlagBits[i]))
			continue;

		g_iActive[client] = i;
	}

	g_bGroupMember[client] = false;
	if (gp_bSteamWorks)
	{
		SteamWorks_GetUserGroupStatus(client, g_iGroup[g_iActive[client]]);
	}

	delete g_hSum[client];
	g_hSum[client] = new StringMap();
	
	if (g_hDB && !g_bDailyCached[client])
		GetDailyVarsFromDB(client);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	

	static bConfigExecuted;
	
	if (bConfigExecuted)
		return;
		
	char buffer[60];
	gc_sDB.GetString(buffer, sizeof(buffer));
	if (buffer[0] == '\0') // if the string is empty
	{
		// Mid-game load support for Daily Rewards
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !AreClientCookiesCached(i))
				continue;
			OnClientCookiesCached(i);
		}
		
		bConfigExecuted = true;
		return;
	}
	
	if (!SQL_CheckConfig(buffer))
	{
		LogError("The database config name '%s' doesn't exist, check the cvar sm_store_earning_database");
		return;
	}
	
	Database.Connect(OnSQLConnect, buffer);
	bConfigExecuted = true;
}

void OnSQLConnect(Database db, const char[] error, any data)
{
	if (!db)
	{
		LogError("Couldn't connect to the database: %s", error);
		return;
	}
	g_hDB = db;
	
	g_hDB.Query(SQL_NullCallback, "CREATE TABLE IF NOT EXISTS store_daily_rewards("
				... "steamid varchar(32) PRIMARY KEY NOT NULL, "
				... "store_date INTEGER, "
				... "store_day INTEGER);")
				
	//g_hDB.Query(SQL_NullCallback, "ALTER TABLE store_daily_rewards ADD COLUMN start_date int(11) default '0'");
	
	// Mid-game load support for Daily Rewards
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !AreClientCookiesCached(i))
			continue;
		GetDailyVarsFromDB(i);
	}
}

public void OnClientCookiesCached(int client)
{
	if (g_hDB)
		return;
	
	char sBuffer[16];
	
	g_cDate.Get(client, sBuffer, sizeof(sBuffer));
	g_iDailyDate[client] = StringToInt(sBuffer);
	
	g_cDay.Get(client, sBuffer, sizeof(sBuffer));
	g_iDailyDay[client] = StringToInt(sBuffer);
	
	g_bDailyCached[client] = true;
}

public void OnAllPluginsLoaded()
{
	gp_bSteamWorks = LibraryExists("SteamWorks");
}

public void OnLibraryRemoved(const char[] name)
{
	if (!StrEqual(name, "SteamWorks"))
		return;

	gp_bSteamWorks = false;
}

void GetDailyVarsFromDB(int client)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(steamid);
	
	FormatEx(g_sDBBuffer, sizeof(g_sDBBuffer), "SELECT store_date, store_day FROM store_daily_rewards WHERE steamid = '%s'", steamid);
	g_hDB.Query(OnDailyRewardsLoaded, g_sDBBuffer, pack);
}

void OnDailyRewardsLoaded(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (!results)
	{
		LogError("OnDailyRewardsLoaded query failure: %s", error);
		return;
	}
	
	char steamid[32];

	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	pack.ReadString(steamid, sizeof(steamid));
	
	if (!client) // Verify if the client disconnected during the query
		return;
	
	if (results.FetchRow()) // Verify if a row was found
	{
		g_iDailyDate[client] = results.FetchInt(0);
		g_iDailyDay[client] = results.FetchInt(1);
		//g_iDailyStart[client] = results.FetchInt(2);
	}
	else //Create blank value for client
	{
		char query[255];
		FormatTime(CurrentDate, sizeof(CurrentDate), "%Y%m%d");
		FormatEx(query, sizeof(query), "INSERT INTO store_daily_rewards(steamid, store_date, store_day) VALUES('%s', %i, %i);",
														steamid, StringToInt(CurrentDate), 0);
		g_hDB.Query(SQL_NullCallback, query);
	}
	// If a row wasn't found, don't change anything since the value is reset on client disconnect anyway
	
	g_bDailyCached[client] = true;
}

Action Command_Daily(int client, int args)
{
	FormatTime(CurrentDate, sizeof(CurrentDate), "%Y%m%d");
	
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (g_iDaily[g_iActive[client]][0] == -1 || !CheckSteamAuth(client, g_sSteam[client]))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}
	
	if (!g_bDailyCached[client])
		return Plugin_Handled;
	
	char sBuffer[64];
	if (!g_hDB)
	{
		if (!AreClientCookiesCached(client))
			return Plugin_Handled;
		
		g_cDate.Get(client, sBuffer, sizeof(sBuffer));
		g_iDailyDate[client] = StringToInt(sBuffer);
		g_cDay.Get(client, sBuffer, sizeof(sBuffer));
		g_iDailyDay[client] = StringToInt(sBuffer);
	}
	else
	{
		
	}
	int iNow = StringToInt(CurrentDate);
	
	
	if (iNow - g_iDailyDate[client] == 0)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Wait until next daily 2");
	}
	else
	{
		if (iNow - g_iDailyDate[client] >=2 || g_iDailyDay[client] < 1)
		{
			if(g_iDailyDate[client])
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Lose Streak Of", (iNow - g_iDailyDate[client]))
				
			g_iDailyDay[client] = 1;
			//g_iDailyStart[client] = iNow;
			
			//Reset start date from database to current date
			//FormatEx(g_sDBBuffer, sizeof(g_sDBBuffer), "UPDATE store_daily_rewards(steamid, start_date) VALUES('%s', %i);",
			//											steamid, iNow);
			//g_hDB.Query(SQL_NullCallback, g_sDBBuffer);
		}

		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iDaily[g_iActive[client]][g_iDailyDay[client] - 1]);

		switch(g_iDailyDay[client])
		{
			case 2, 3, 4, 5, 6: 
			{
				CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", g_iDaily[g_iActive[client]][g_iDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row", g_iDailyDay[client]);
			}
			case 7:
			{
				CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", g_iDaily[g_iActive[client]][g_iDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row", g_iDailyDay[client]);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "You mastered the daily challange");
				Store_SQLLogMessage(client, LOG_EVENT, "Mastered the daily challange (7days) for %i credits'", g_iDaily[g_iActive[client]][g_iDailyDay[client] - 1]);
				g_iDailyDay[client] = 0;
			}
			default:
			{

				CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", g_iDaily[g_iActive[client]][0], g_sCreditsName, "start daily challange");
				//FormatEx(g_sDBBuffer, sizeof(g_sDBBuffer), "REPLACE INTO store_daily_rewards(steamid, start_date) VALUES('%s', %i);",
				//										steamid, iNow);
				//g_hDB.Query(SQL_NullCallback, g_sDBBuffer);
			}
		}

		CPrintToChat(client, "%s%t", g_sChatPrefix, "You'll earn x Credits tomorrow", g_iDaily[g_iActive[client]][g_iDailyDay[client]], g_sCreditsName);
		
		// Update cookies/database data
		if (!g_hDB)
		{
			IntToString(g_iDailyDay[client] + 1, sBuffer, sizeof(sBuffer));
			g_cDay.Set(client, sBuffer);
			
			IntToString(iNow, sBuffer, sizeof(sBuffer));
			g_cDate.Set(client, sBuffer);
		}
		else
		{
			FormatEx(g_sDBBuffer, sizeof(g_sDBBuffer), "REPLACE INTO store_daily_rewards(steamid, store_date, store_day) VALUES('%s', %i, %i);",
														steamid, iNow, g_iDailyDay[client] + 1);
			g_hDB.Query(SQL_NullCallback, g_sDBBuffer);
		}
		
		// Now, update cached variables
		g_iDailyDay[client] += 1
		g_iDailyDate[client] = iNow;
	}

	return Plugin_Handled;
}

public void SteamWorks_OnClientGroupStatus(int authid, int groupAccountID, bool isMember, bool isOfficer)
{
	int client = GetClientOfAuthID(authid);
	if (client != -1 && isMember)
	{
		g_bGroupMember[client] = true;
	}
}

int GetClientOfAuthID(int authid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		char charauth[64], authchar[64];
		if (!GetClientAuthId(i, AuthId_Steam3, charauth, sizeof(charauth)))
			continue;

		IntToString(authid, authchar, sizeof(authchar));

		if (StrContains(charauth, authchar) != -1)
			return i;
	}

	return -1;
}

void GiveCredits(int client, int credits, char[] reason, any ...)
{
	float multi[3] = {1.0, ...};
	char sBuffer[64];

	GetClientName(client, sBuffer, sizeof(sBuffer));
	if (StrContains(sBuffer, g_szNick[g_iActive[client]], false) != -1 && g_szNick[g_iActive[client]][0])
	{
		multi[0] = g_fNick[g_iActive[client]];
	}

	//CS_GetClientClanTag(client, sBuffer, sizeof(sBuffer));
	//if (StrEqual(sBuffer, g_szTag[g_iActive[client]]) && g_szTag[g_iActive[client]][0])
	//{
	//	multi[1] = g_fTag[g_iActive[client]];
	//}

	if (g_bGroupMember[client])
	{
		multi[2] = g_fGroup[g_iActive[client]];
	}

	credits = RoundToNearest(credits * multi[0] * multi[1] * multi[2] * g_fClientMulti[client]);

	//VFormat(sBuffer, sizeof(sBuffer), reason, 4);
	Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);

	switch(g_iMsg[g_iActive[client]])
	{
		case 1: CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", credits, g_sCreditsName, reason);
		case 2: g_iSum[client] += credits;
		case 3:
		{
			int iBuffer;
			if (g_hSum[client].GetValue(sBuffer, iBuffer))
			{
				g_hSum[client].SetValue(sBuffer, credits + iBuffer);
			}
			else
			{
				g_hSum[client].SetValue(sBuffer, credits);
			}
		}
	}
}

Action Timer_Timer(Handle timer)
{
	char Buffer[255];
	int count = PlayerCount();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (count < g_iMinPlayer[g_iActive[i]])
			continue;

		if (!CheckSteamAuth(i, g_sSteam[i]))
			continue;

		if (2 <= GetClientTeam(i) <= 3)
		{
			g_iTime[i][ACTIVE]++;
		}
		else
		{
			g_iTime[i][INACTIVE]++;
		}

		if (g_iTime[i][ACTIVE] >= g_fTimer[g_iActive[i]])
		{
			g_iTime[i][ACTIVE] = 0;
			if(g_iPlay[g_iActive[i]] > 0)
			{
				Format(Buffer, sizeof(Buffer), "%s", "playing on the server");
				GiveCredits(i, g_iPlay[g_iActive[i]], Buffer);
			}
		}
		else if (g_iTime[i][INACTIVE] >= g_fTimer[g_iActive[i]])
		{
			g_iTime[i][INACTIVE] = 0;
			if(g_iInactive[g_iActive[i]] > 0)
			{
				Format(Buffer, sizeof(Buffer), "%s", "idle on the server")
				GiveCredits(i, g_iInactive[g_iActive[i]], Buffer);
			}
		}
	}

	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int count = PlayerCount();
	
	if (!IsValidClient(victim, g_bBots[g_iActive[attacker]], true))
		return;

	if (!IsValidClient(attacker, true, true))
		return;

	if (count < g_iMinPlayer[g_iActive[attacker]])
		return;

	int assister = GetClientOfUserId(event.GetInt("assister"));
	char Buffer[255];
	
	// No zombie (ZR, ZP) enable
	if (IsValidClient(assister) && g_iAssist[g_iActive[assister]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "assist a kill");
		GiveCredits(assister, g_iAssist[g_iActive[assister]], Buffer);
	}

	if (attacker == victim && g_iSuicide[g_iActive[attacker]] != 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "kill yourself");
		GiveCredits(attacker, g_iSuicide[g_iActive[attacker]], Buffer);
	}

	if (!IsFakeClient(victim) && g_iMsg[g_iActive[victim]] == 2)
	{
		if (g_iSum[victim] != 0)
		{
			CPrintToChat(victim, "%s%t", g_sChatPrefix, "You earned x Credits this round", g_iSum[victim], g_sCreditsName);
		}
		g_iSum[victim] = 0;
	}
	else if (!IsFakeClient(victim) && g_iMsg[g_iActive[victim]] == 3)
	{
		if (g_hSum[victim].Size > 0)
		{
			StringMapSnapshot hSum = g_hSum[victim].Snapshot();
			char sBuffer[32];
			int sum = 0;
			CPrintToChat(victim, "%s%t", g_sChatPrefix, "You earned this round");
			CPrintToChat(victim, "%s%t", g_sChatPrefix, "Spacer");
			for (int i = 0; i < hSum.Length; i++)
			{
				hSum.GetKey(i, sBuffer, sizeof(sBuffer));
				int value;
				g_hSum[victim].GetValue(sBuffer, value);
				sum += value;
				CPrintToChat(victim, "%s%t", g_sChatPrefix, "x Credits for", value, g_sCreditsName, sBuffer);
			}
			CPrintToChat(victim, "%s%t", g_sChatPrefix, "Spacer");
			CPrintToChat(victim, "%s%t", g_sChatPrefix, "Total Credits", sum, g_sCreditsName);

			delete hSum;
			g_hSum[victim].Clear();
		}
		else
		{
			CPrintToChat(victim, "%s%t", g_sChatPrefix, "You earned no points this round");
		}
	}

	if (attacker == victim)
		return;

	
	//int iBuffer;
	if (GetClientTeam(attacker) == GetClientTeam(victim) && g_iTK[g_iActive[attacker]] != 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "teamkill");
		GiveCredits(attacker, g_iTK[g_iActive[attacker]], Buffer);

		return;
	}
	else if (g_iKill[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "kill");
		GiveCredits(attacker, g_iKill[g_iActive[attacker]], Buffer);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int winner = event.GetInt("winner");
	int count = PlayerCount();
	char Buffer[255];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, false))
			continue;

		if (GetClientTeam(i) == winner)
		{
			if (count >= g_iMinPlayer[g_iActive[i]] && g_iWin[g_iActive[i]] > 0)
			{
				Format(Buffer, sizeof(Buffer), "%s", "win the round");
				GiveCredits(i, g_iWin[g_iActive[i]], Buffer);
			}
		}

		if (g_iMsg[g_iActive[i]] == 2)
		{
			if (g_iSum[i] == 0)
				continue;

			CPrintToChat(i, "%s%t", g_sChatPrefix, "You earned x Credits this round", g_iSum[i], g_sCreditsName);
			g_iSum[i] = 0;
		}
		else if (g_iMsg[g_iActive[i]] == 3)
		{
			if (g_hSum[i].Size > 0)
			{
				StringMapSnapshot hSum = g_hSum[i].Snapshot();
				char sBuffer[32];
				int sum = 0;
				CPrintToChat(i, "%s%t", g_sChatPrefix, "You earned this round");
				CPrintToChat(i, "%s%t", g_sChatPrefix, "Spacer");
				for (int j = 0; j < hSum.Length; j++)
				{
					hSum.GetKey(j, sBuffer, sizeof(sBuffer));
					int value;
					g_hSum[i].GetValue(sBuffer, value);
					sum += value;
					CPrintToChat(i, "%s%t", g_sChatPrefix, "x Credits for", value, g_sCreditsName, sBuffer);
				}
				CPrintToChat(i, "%s%t", g_sChatPrefix, "Spacer");
				CPrintToChat(i, "%s%t", g_sChatPrefix, "Total Credits", sum, g_sCreditsName);

				delete hSum;
				g_hSum[i].Clear();
			}
			else
			{
				CPrintToChat(i, "%s%t", g_sChatPrefix, "You earned no points this round");
			}
		}
	}
}

void LoadConfig()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/store/earnings.txt");
	KeyValues kv = new KeyValues("Earnings");
	kv.ImportFromFile(sFile);
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("Failed to read configs/store/earnings.txt");
	}

	GoThroughConfig(kv);
	delete kv;
}

void GoThroughConfig(KeyValues &kv)
{
	char sBuffer[64];

	g_iCount = 0;

	do
	{
		if (g_iCount == MAX_OBJECTIVES)
			break;

		kv.GetSectionName(g_szName[g_iCount], 64);

		kv.GetString("flags", sBuffer, sizeof(sBuffer), "");
		g_iFlagBits[g_iCount] = ReadFlagString(sBuffer);
		g_iMinPlayer[g_iCount] = kv.GetNum("player", 0);
		g_bBots[g_iCount] = kv.GetNum("bots", 0) ? true : false;
		g_fTimer[g_iCount] = kv.GetFloat("timer", 10.0);
		g_iPlay[g_iCount] = kv.GetNum("active", 0);
		g_iInactive[g_iCount] = kv.GetNum("inactive", 0);
		g_iKill[g_iCount] = kv.GetNum("kill", 0);
		g_iTK[g_iCount] = kv.GetNum("tk", 0);
		g_iSuicide[g_iCount] = kv.GetNum("suicide", 0);
		g_iAssist[g_iCount] = kv.GetNum("assist", 0);
		g_iHeadshot[g_iCount] = kv.GetNum("headshot", 0);
		g_iNoScope[g_iCount] = kv.GetNum("noscope", 0);
		g_iBackstab[g_iCount] = kv.GetNum("backstab", 0);
		g_iKnife[g_iCount] = kv.GetNum("knife", 0);
		g_iTaser[g_iCount] = kv.GetNum("taser", 0);
		g_iHE[g_iCount] = kv.GetNum("he", 0);
		g_iFlash[g_iCount] = kv.GetNum("flash", 0);
		g_iSmoke[g_iCount] = kv.GetNum("smoke", 0);
		g_iMolotov[g_iCount] = kv.GetNum("molotov", 0);
		g_iDecoy[g_iCount] = kv.GetNum("decoy", 0);
		g_iWin[g_iCount] = kv.GetNum("win", 0);
		g_iMVP[g_iCount] = kv.GetNum("mvp", 0);
		g_iPlant[g_iCount] = kv.GetNum("plant", 0);
		g_iDefuse[g_iCount] = kv.GetNum("defuse", 0);
		g_iExplode[g_iCount] = kv.GetNum("explode", 0);
		g_iRescued[g_iCount] = kv.GetNum("rescued", 0);
		g_iVIPkill[g_iCount] = kv.GetNum("vip_kill", 0);
		g_iVIPescape[g_iCount] = kv.GetNum("vip_escape", 0);
		g_iMsg[g_iCount] = kv.GetNum("msg", 0);
		kv.GetString("nick", g_szNick[g_iCount], 64, "");
		g_fNick[g_iCount] = kv.GetFloat("nick_multi", 1.0);
		kv.GetString("clantag", g_szTag[g_iCount], 64, "");
		g_fTag[g_iCount] = kv.GetFloat("clantag_multi", 1.0);
		g_iGroup[g_iCount] = kv.GetNum("groupid", 0);
		g_fGroup[g_iCount] = kv.GetFloat("groupid_multi", 1.0);
		// dailys?
		if (kv.JumpToKey("Dailys"))
		{
			kv.GotoFirstSubKey();
			do
			{
				g_iDaily[g_iCount][0] = kv.GetNum("1", -1);
				g_iDaily[g_iCount][1] = kv.GetNum("2", 0);
				g_iDaily[g_iCount][2] = kv.GetNum("3", 0);
				g_iDaily[g_iCount][3] = kv.GetNum("4", 0);
				g_iDaily[g_iCount][4] = kv.GetNum("5", 0);
				g_iDaily[g_iCount][5] = kv.GetNum("6", 0);
				g_iDaily[g_iCount][6] = kv.GetNum("7", 0);
			}
			while (kv.GotoNextKey());

			kv.GoBack();
		}

		g_iCount++;

	}
	while (kv.GotoNextKey());
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}

	return false;
}

bool CheckSteamAuth(int client, char[] steam)
{
	if (!steam[0])
		return true;

	char sSteam[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteam, 32))
		return false;

	if (StrContains(steam, sSteam) == -1)
		return false;

	return true;
}

public int PlayerCount()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	
	return count;
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}
/*
void SecToTime(int time, char[] buffer, int size)
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
		Format(buffer, size, "%t", "x hours, x minutes, x seconds", iHours, iMinutes, iSeconds);
	}
	else if (iMinutes >= 1)
	{
		Format(buffer, size, "%t", "x minutes, x seconds", iMinutes, iSeconds);
	}
	else
	{
		Format(buffer, size, "%t", "x seconds", iSeconds);
	}
}
*/
void SQL_NullCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (!results)
		LogError("Query failure: %s", error);
}