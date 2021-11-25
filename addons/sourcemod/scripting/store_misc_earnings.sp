#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
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

ConVar gc_bFFA;

Handle 	g_cDate,
		g_cDay;

int g_iActive[MAXPLAYERS + 1];
int g_iCount;

StringMap g_hSnipers;
StringMap g_hSum[MAXPLAYERS + 1];

#define ACTIVE 0
#define INACTIVE 1
int g_iTime[MAXPLAYERS + 1][2];

char g_szGameDir[64];

ConVar Warmup_Enable;
bool GAME_CSS = false;

public Plugin myinfo = 
{
	name = "Store - Earnings module",
	author = "shanapu, AiDN™, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "This modules can only be use in CSS, CS:GO. Dont install if you use for tf2, dods, l4d",
	version = "2.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	
	// Identify the game
	GetGameFolderName(STRING(g_szGameDir));
	
	if(strcmp(g_szGameDir, "cstrike")==0)
	{
		PrintToServer("Loaded CSS as a game engine");
		GAME_CSS = true;
	}
	else if(strcmp(g_szGameDir, "csgo")==0)
		PrintToServer("Loaded CSGO as a game engine");
	else
	{
		SetFailState("This game is not be supported. Please contact the author for support.");
	}

	RegConsoleCmd("sm_daily", Command_Daily, "Recieve your daily credits");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	HookEvent("round_mvp", Event_MVP);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("bomb_planted", Event_BombPlanted);
	HookEvent("bomb_defused", Event_BombDefused);
	HookEvent("bomb_exploded", Event_BombExploded);
	HookEvent("hostage_rescued", Event_HostageRescued);
	HookEvent("vip_killed", Event_VipKilled);
	HookEvent("vip_escaped", Event_VipEscaped);

	g_hSnipers = new StringMap();
	g_hSnipers.SetValue("awp", 1);
	g_hSnipers.SetValue("ssg08", 1);
	g_hSnipers.SetValue("g3sg1", 1);
	g_hSnipers.SetValue("scar20", 1);

	g_cDate = RegClientCookie("store_date", "Store Daily Date", CookieAccess_Public);
	g_cDay = RegClientCookie("store_day", "Store Daily Day", CookieAccess_Public);

	Warmup_Enable = CreateConVar("sm_store_earning_enable_warmup", "1", "Wheither to enable earning credits while in warmup");
	
	AutoExecConfig(true, "earnings", "sourcemod/store")

	LoadConfig();
}

public Action Command_Daily(int client, int args)
{
	if (g_iDaily[g_iActive[client]][0] == -1 || !CheckSteamAuth(client, g_sSteam[client]))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	char sBuffer[64];
	GetClientCookie(client, g_cDate, sBuffer, sizeof(sBuffer));
	int iDate = StringToInt(sBuffer);
	GetClientCookie(client, g_cDay, sBuffer, sizeof(sBuffer));
	int iDay = StringToInt(sBuffer);
	int iNow = GetTime();

	if (DAY_IN_SECONDS + iDate > iNow)
	{
		SecToTime(iDate + DAY_IN_SECONDS - iNow, sBuffer, sizeof(sBuffer));
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Wait until next daily", sBuffer);
	}
	else
	{
		if (DAY_IN_SECONDS * 2 + iDate < iNow || iDay < 1)
		{
			iDay = 1;
		}

		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iDaily[g_iActive[client]][iDay - 1]);

		switch(iDay)
		{
			case 2, 3, 4, 5, 6: CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", g_iDaily[g_iActive[client]][iDay - 1], g_sCreditsName, "playing x on our server in row", iDay);
			case 7:
			{
				CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", g_iDaily[g_iActive[client]][iDay - 1], g_sCreditsName, "playing x on our server in row", iDay);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "You mastered the daily challange");
				Store_SQLLogMessage(client, LOG_EVENT, "Mastered the daily challange (7days) for %i credits'", g_iDaily[g_iActive[client]][iDay - 1]);
				iDay = 0;
			}
			default: CPrintToChat(client, "%s%t%t", g_sChatPrefix, "You earned x Credits for", g_iDaily[g_iActive[client]][0], g_sCreditsName, "start daily challange");
		}

		CPrintToChat(client, "%s%t", g_sChatPrefix, "You'll earn x Credits tomorrow", g_iDaily[g_iActive[client]][iDay], g_sCreditsName);

		IntToString(iDay + 1, sBuffer, sizeof(sBuffer));
		SetClientCookie(client, g_cDay, sBuffer);
		IntToString(iNow, sBuffer, sizeof(sBuffer));
		SetClientCookie(client, g_cDate, sBuffer);
	}

	return Plugin_Handled;
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

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	
	gc_bFFA = FindConVar("mp_teammates_are_enemies");
}

public void OnClientConnected(int client)
{
	ConnectTime[client] = GetTime();
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
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
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], const float damagePosition[3])
{
	char Buffer[255];
	
	int count = PlayerCount();

	if (!(damagetype & DMG_SLASH))
		return Plugin_Continue;

	if (!IsValidClient(victim, true, true) || attacker == victim || !IsValidClient(attacker, true, false))
		return Plugin_Continue;

	if (count < g_iMinPlayer[g_iActive[attacker]])
		return Plugin_Continue;

	if (g_iBackstab[g_iActive[attacker]] < 1 && g_iKnife[g_iActive[attacker]] < 1)
		return Plugin_Continue;

	if (!CheckSteamAuth(attacker, g_sSteam[attacker]))
		return Plugin_Continue;

	if (IsFakeClient(victim) && !g_bBots[g_iActive[attacker]])
		return Plugin_Continue;

	char sWeapon[32];
	GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
	if (StrContains(sWeapon, "knife") != -1 || StrContains(sWeapon, "bayonet") != -1)
	{
		if (damage > 99.0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "backstab kill");
			#if defined PLUGINS_ZOMBIE_ENABLE
				if(damage > GetClientHealth(victim))
					if(GetClientTeam(attacker) != GetClientTeam(victim))
					{
						GiveCredits(attacker, g_iBackstab[g_iActive[attacker]], Buffer);
					}
			#else
				if(gc_bFFA.BoolValue && GetClientTeam(attacker) == GetClientTeam(victim))
				{
					GiveCredits(attacker, g_iBackstab[g_iActive[attacker]], Buffer);
				}
				else if(GetClientTeam(attacker) != GetClientTeam(victim))
				{
					GiveCredits(attacker, g_iBackstab[g_iActive[attacker]], Buffer);
				}
			#endif
		}
		else if (damage > GetClientHealth(victim))
		{
			Format(Buffer, sizeof(Buffer), "%s", "knife kill")
			GiveCredits(attacker, g_iKnife[g_iActive[attacker]], Buffer);
		}
	}

	return Plugin_Continue;
}

public int SteamWorks_OnClientGroupStatus(int authid, int groupAccountID, bool isMember, bool isOfficer)
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

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;

	g_bGroupMember[client] = false;
	
	ConnectTime[client] = 0;
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

	CS_GetClientClanTag(client, sBuffer, sizeof(sBuffer));
	if (StrEqual(sBuffer, g_szTag[g_iActive[client]]) && g_szTag[g_iActive[client]][0])
	{
		multi[1] = g_fTag[g_iActive[client]];
	}

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

public Action Timer_Timer(Handle timer)
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

		if (CS_TEAM_T <= GetClientTeam(i) <= CS_TEAM_CT)
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
		
	if(!GAME_CSS)
		if(GameRules_GetProp("m_bWarmupPeriod") && !Warmup_Enable.BoolValue)
			return;

	int assister = GetClientOfUserId(event.GetInt("assister"));
	bool headshot = event.GetBool("headshot");
	char sWeapon[32], Buffer[255];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	
	#if defined PLUGINS_ZOMBIE_ENABLE
	// Zombie mode (ZR, ZP) enabled
	if(GetClientTeam(attacker) == 3) // Better to manually check by team index instead of ZR_IsClientZombie
	{
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

		if (StrContains(sWeapon, "knife") != -1 || StrContains(sWeapon, "bayonet") != -1)
			return;

		int iBuffer;
		if (!gc_bFFA.BoolValue && GetClientTeam(attacker) == GetClientTeam(victim) && g_iTK[g_iActive[attacker]] != 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "teamkill");
			GiveCredits(attacker, g_iTK[g_iActive[attacker]], Buffer);

			return;
		}
		else if (StrContains(sWeapon, "taser") != -1 && g_iTaser[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "taser kill");
			GiveCredits(attacker, g_iTaser[g_iActive[attacker]], Buffer);
		}
		else if (StrContains(sWeapon, "hegrenade") != -1 && g_iHE[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "HE grenade kill");
			GiveCredits(attacker, g_iHE[g_iActive[attacker]], Buffer);
		}
		else if (StrContains(sWeapon, "flashbang") != -1 && g_iFlash[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "flashbang kill");
			GiveCredits(attacker, g_iFlash[g_iActive[attacker]], Buffer);
		}
		else if (StrContains(sWeapon, "smokegrenade") != -1 && g_iSmoke[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "smokegrenade kill");
			GiveCredits(attacker, g_iSmoke[g_iActive[attacker]], Buffer);
		}
		/*else if ((StrContains(sWeapon, "molotov") != -1 || StrContains(sWeapon, "incgrenade") != -1) && g_iMolotov[g_iActive[attacker]] > 0)
		{
			GiveCredits(attacker, g_iMolotov[g_iActive[attacker]], "%s", "molotov kill");
		}*/
		else if ((StrContains(sWeapon, "inferno") != -1 && g_iMolotov[g_iActive[attacker]] > 0))
		{
			Format(Buffer, sizeof(Buffer), "%s", "molotov kill");
			GiveCredits(attacker, g_iMolotov[g_iActive[attacker]],Buffer);
		}
		else if (StrContains(sWeapon, "decoy") != -1 && g_iDecoy[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "decoy grenade  kill");
			GiveCredits(attacker, g_iDecoy[g_iActive[attacker]], Buffer);
		}
		else if ((StrContains(sWeapon, "awp") != -1 || StrContains(sWeapon, "ssg08") != -1 || StrContains(sWeapon, "scout") != -1 || StrContains(sWeapon, "g3sg1") != -1 || StrContains(sWeapon, "scar20") != -1)
			&& g_iNoScope[g_iActive[attacker]] > 0 && !(0 < GetEntProp(attacker, Prop_Data, "m_iFOV") < GetEntProp(attacker, Prop_Data, "m_iDefaultFOV")))
		{
			Format(Buffer, sizeof(Buffer), "%s", "noscope kill");
			GiveCredits(attacker, g_iNoScope[g_iActive[attacker]], Buffer);
		}
		else if (headshot && g_iHeadshot[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "headshot");
			GiveCredits(attacker, g_iHeadshot[g_iActive[attacker]], Buffer);
		}
		else if (g_iKill[g_iActive[attacker]] > 0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "kill");
			GiveCredits(attacker, g_iKill[g_iActive[attacker]], Buffer);
		}
	}
	else 
	{
		char victim_name[MAX_NAME_LENGTH];
		GetClientName(victim, victim_name, sizeof(victim_name));
		if(attacker != victim)
		{
			Store_SetClientCredits(attacker, Store_GetClientCredits(attacker) + g_iKill[g_iActive[attacker]])
			//Chat(attacker, "%s", "Credits Earned For Killing", g_iKill[g_iActive[attacker]], victim_name);
			CPrintToChat(attacker, "%s%t", g_sChatPrefix, "Zombie Earning Kill", g_iKill[g_iActive[attacker]], victim_name);
		}
		else return;
	}
	#else
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

	if (StrContains(sWeapon, "knife") != -1 || StrContains(sWeapon, "bayonet") != -1)
		return;

	//int iBuffer;
	if (!gc_bFFA.BoolValue && GetClientTeam(attacker) == GetClientTeam(victim) && g_iTK[g_iActive[attacker]] != 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "teamkill");
		GiveCredits(attacker, g_iTK[g_iActive[attacker]], Buffer);

		return;
	}
	else if (StrContains(sWeapon, "taser") != -1 && g_iTaser[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "taser kill");
		GiveCredits(attacker, g_iTaser[g_iActive[attacker]], Buffer);
	}
	else if (StrContains(sWeapon, "hegrenade") != -1 && g_iHE[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "HE grenade kill");
		GiveCredits(attacker, g_iHE[g_iActive[attacker]], Buffer);
	}
	else if (StrContains(sWeapon, "flashbang") != -1 && g_iFlash[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "flashbang kill");
		GiveCredits(attacker, g_iFlash[g_iActive[attacker]], Buffer);
	}
	else if (StrContains(sWeapon, "smokegrenade") != -1 && g_iSmoke[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "smokegrenade kill");
		GiveCredits(attacker, g_iSmoke[g_iActive[attacker]], Buffer);
	}
	/*else if ((StrContains(sWeapon, "molotov") != -1 || StrContains(sWeapon, "incgrenade") != -1) && g_iMolotov[g_iActive[attacker]] > 0)
	{
		GiveCredits(attacker, g_iMolotov[g_iActive[attacker]], "%s", "molotov kill");
	}*/
	else if ((StrContains(sWeapon, "inferno") != -1 && g_iMolotov[g_iActive[attacker]] > 0))
	{
		Format(Buffer, sizeof(Buffer), "%s", "molotov kill");
		GiveCredits(attacker, g_iMolotov[g_iActive[attacker]], Buffer);
	}
	else if (StrContains(sWeapon, "decoy") != -1 && g_iDecoy[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "decoy grenade  kill");
		GiveCredits(attacker, g_iDecoy[g_iActive[attacker]], Buffer);
	}
	else if ((StrContains(sWeapon, "awp") != -1 || StrContains(sWeapon, "ssg08") != -1 || StrContains(sWeapon, "scout") != -1 || StrContains(sWeapon, "g3sg1") != -1 || StrContains(sWeapon, "scar20") != -1)
			&& g_iNoScope[g_iActive[attacker]] > 0 && !(0 < GetEntProp(attacker, Prop_Data, "m_iFOV") < GetEntProp(attacker, Prop_Data, "m_iDefaultFOV")))
	{
		Format(Buffer, sizeof(Buffer), "%s", "noscope kill");
		GiveCredits(attacker, g_iNoScope[g_iActive[attacker]], Buffer);
	}
	else if (headshot && g_iHeadshot[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "headshot");
		GiveCredits(attacker, g_iHeadshot[g_iActive[attacker]], Buffer);
	}
	else if (g_iKill[g_iActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "kill");
		GiveCredits(attacker, g_iKill[g_iActive[attacker]], Buffer);
	}
	#endif
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

public void Event_MVP(Event event, const char[] name, bool dontBroadcast)
{
	char Buffer[255];
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = PlayerCount();
	if (!IsValidClient(client, false, true))
		return;

	if (!CheckSteamAuth(client, g_sSteam[client]))
		return;

	if (count < g_iMinPlayer[g_iActive[client]])
		return;

	if (g_iMVP[g_iActive[client]] < 1)
		return;
	
	Format(Buffer, sizeof(Buffer), "%s", "be the MVP");
	GiveCredits(client, g_iMVP[g_iActive[client]], Buffer);
}

public void Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = PlayerCount();
	char Buffer[255];

	if (!IsValidClient(client, false, true))
		return;

	if (!CheckSteamAuth(client, g_sSteam[client]))
		return;

	if (count < g_iMinPlayer[g_iActive[client]])
		return;

	if (g_iPlant[g_iActive[client]] < 1)
		return;

	Format(Buffer, sizeof(Buffer), "%s", "bomb planted");
	GiveCredits(client, g_iPlant[g_iActive[client]], Buffer);
}

public void Event_BombDefused(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "bomb defused");

	if (!IsValidClient(client, false, true))
		return;

	if (!CheckSteamAuth(client, g_sSteam[client]))
		return;

	if (count < g_iMinPlayer[g_iActive[client]])
		return;

	if (g_iDefuse[g_iActive[client]] < 1)
		return;

	GiveCredits(client, g_iDefuse[g_iActive[client]], Buffer);
}

public void Event_BombExploded(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "bomb explode");

	if (!IsValidClient(client, false, true))
		return;

	if (!CheckSteamAuth(client, g_sSteam[client]))
		return;

	if (count < g_iMinPlayer[g_iActive[client]])
		return;

	if (g_iExplode[g_iActive[client]] < 1)
		return;

	GiveCredits(client, g_iExplode[g_iActive[client]], Buffer);
}

public void Event_HostageRescued(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "hostage rescued");

	if (!IsValidClient(client, false, true))
		return;

	if (!CheckSteamAuth(client, g_sSteam[client]))
		return;

	if (count < g_iMinPlayer[g_iActive[client]])
		return;

	if (g_iRescued[g_iActive[client]] < 1)
		return;

	GiveCredits(client, g_iRescued[g_iActive[client]], Buffer);
}

public void Event_VipKilled(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int count = PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "kill the VIP");

	if (!IsValidClient(attacker, false, true))
		return;

	if (!CheckSteamAuth(attacker, g_sSteam[attacker]))
		return;

	if (count < g_iMinPlayer[g_iActive[attacker]])
		return;

	if (g_iVIPkill[g_iActive[attacker]] < 1)
		return;

	GiveCredits(attacker, g_iVIPkill[g_iActive[attacker]], Buffer);
}

public void Event_VipEscaped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "escape as VIP");

	if (!IsValidClient(client, false, true))
		return;

	if (!CheckSteamAuth(client, g_sSteam[client]))
		return;

	if (count < g_iMinPlayer[g_iActive[client]])
		return;

	if (g_iVIPescape[g_iActive[client]] < 1)
		return;

	GiveCredits(client, g_iVIPescape[g_iActive[client]], "%s", Buffer);
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
			while kv.GotoNextKey();

			kv.GoBack();
		}

		g_iCount++;

	}
	while kv.GotoNextKey();
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
