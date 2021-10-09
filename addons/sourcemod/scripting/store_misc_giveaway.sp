#include <sourcemod>
//#include <colorvariables>
#include <sdktools>
#include <store>
#include <multicolors>

#pragma newdecls required

ConVar gc_iCredits;
ConVar gc_iMinPlayer;
ConVar gc_iTimeInfo;
ConVar gc_bAdmin;

ConVar gc_sTag;
char g_sChatPrefix[128];

//char g_sTag[32];
char admins[MAX_NAME_LENGTH];
int number, credits;
int creatorID;
Handle timers;

public Plugin myinfo = {
	name = "Store Giveaway",
	author = "nuclear silo",
	description = "Giveaway plugin compatible with zephyrus store.",
	version = "1.4",
	url = ""
}

public void OnPluginStart()
{
	gc_iCredits = CreateConVar("sm_giveaway_credits", "1000", "Number of credits given.");
	gc_iMinPlayer = CreateConVar("sm_giveaway_minplayers", "5", "Minimum players required in the server for the giveaway.");
	gc_iTimeInfo = CreateConVar("sm_giveaway_time_info", "10", "Time in second of giveaway announcement. Minimum is 10 seconds. Type INT");
	gc_bAdmin = CreateConVar("sm_giveaway_count_admin", "1", "Can admin join the giveaway [0 - no, 1 - yes]");

	RegAdminCmd("sm_giveaway", CommandGiveaway, ADMFLAG_ROOT, "Start giveaway");
	//RegConsoleCmd("sm_giveaway", CommandGiveaway, "Start giveaway");

	AutoExecConfig(true, "giveaway", "sourcemod/store");

	LoadTranslations("store.phrases");
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void OnConfigsExecuted()
{
	gc_sTag = FindConVar("sm_store_chat_tag");
	gc_sTag.GetString(g_sChatPrefix, sizeof(g_sChatPrefix));
}

public int PlayerCount()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	
	return count;
}

public int PlayerCountNoAdmin()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && !CheckCommandAccess(i, "sm_giveaway_flag_overwrite", ADMFLAG_GENERIC))
			count++;
	
	return count;
}

public Action CommandGiveaway(int client, int args)
{
	//if (!CheckCommandAccess(client, "sm_giveaway_flag_overwrite", ADMFLAG_ROOT))
		//return Plugin_Handled;
	int count;
	if(gc_bAdmin.BoolValue)
		count = PlayerCount();
	else count = PlayerCountNoAdmin();
	
	if (!args)
	{
		number = gc_iTimeInfo.IntValue;
		credits = gc_iCredits.IntValue;
		if(count > gc_iMinPlayer.IntValue)
		{
			//CreateTimer(0.1, TimerGiveaway, _, TIMER_REPEAT);
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, MAX_NAME_LENGTH);
			CountDown(name);
			admins = name;
			creatorID = client;
			return Plugin_Continue;
		}
		else
		{
			CPrintToChat(client, "%t", "Giveaway Minimum Players", g_sChatPrefix, gc_iMinPlayer.IntValue);
		}
	}
	else if (args == 1)
	{
		char temp[64];
		GetCmdArg(1, temp, sizeof(temp));
		credits = StringToInt(temp);
		number = gc_iTimeInfo.IntValue;
		if(count > gc_iMinPlayer.IntValue)
		{
			//CreateTimer(0.1, TimerGiveaway, _, TIMER_REPEAT);
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, MAX_NAME_LENGTH);
			CountDown(name);
			admins = name;
			creatorID = client;
			return Plugin_Continue;
		}
		else
		{
			CPrintToChat(client, "%t", "Giveaway Minimum Players", g_sChatPrefix, gc_iMinPlayer.IntValue);
		}
	}
	else ReplyToCommand(client, "{yellow}%s {default}Usage: sm_giveaway <credits>", g_sChatPrefix);
	
	
	return Plugin_Handled;
}

public Action TimerGiveaway(Handle timer, any client)
{
	static int Number = 0;
	char sBuffer[254];
	if (Number >= 100)
	{
		Number = 0;
		char name[MAX_NAME_LENGTH];
		int randomNumber;
		
		if (gc_bAdmin.BoolValue)
			randomNumber = GetRandomPlayer();
		else randomNumber = GetRandomPlayerNoAdmin();
		GetClientName(randomNumber, name, MAX_NAME_LENGTH);
		
		Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway winner hint text", g_sChatPrefix, name)
		PrintCenterTextAll(sBuffer);
		CPrintToChatAll("%t", "Giveaway winner chat", g_sChatPrefix, name, credits);
		
		Store_SetClientCredits(randomNumber, Store_GetClientCredits(randomNumber) + credits);
		
		//LogToFile("addons/sourcemod/logs/zgiveaway/zgiveawayfile.log", "The admin %s did a giveaway and %s won", admins, name);
		Store_SQLLogMessage(creatorID, LOG_EVENT, "The admin %s did a giveaway and %s won", admins, name);
		
		return Plugin_Stop;
	}
	char name[MAX_NAME_LENGTH];
 	int randomNumber;
	
	if (gc_bAdmin.BoolValue)
		randomNumber = GetRandomPlayer();
	else randomNumber = GetRandomPlayerNoAdmin();
	GetClientName(randomNumber, name, MAX_NAME_LENGTH);
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway winner in progress", name)
	PrintCenterTextAll(sBuffer);
	Number++;
	
	return Plugin_Continue;
}

void CountDown(char[] admin)
{
	char sBuffer[254];
	if(timers != INVALID_HANDLE)
	{
		KillTimer(timers);
		timers = INVALID_HANDLE;
	}
	timers = CreateTimer(1.0, Repeater, _, TIMER_REPEAT);
	Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway announcement", admin, credits);
	PrintCenterTextAll(sBuffer);
}

public Action Repeater(Handle timer)
{
	char sBuffer[254];
	number--;
	if(number <= 0)
	{
		CreateTimer(0.1, TimerGiveaway, _, TIMER_REPEAT);
		if(timers != INVALID_HANDLE)
		{
			KillTimer(timers);
			timers = INVALID_HANDLE;
		}
		return;
	}
	/*if (number >=7)
	{
		PrintCenterTextAll("<font color='#00CCFF'>Admin <font color='#ff0000'>%s<font color='#00CCFF'> opened a giveaway with "
						... "<font color='#15fb00'>%i <font color='#00CCFF'>credits"
						, admins, credits);
	}*/
	if (0 < number < 6)
	{
		Format(sBuffer, sizeof(sBuffer), "%t" , "Giveaway remaining time", number);
		PrintCenterTextAll(sBuffer);
	}
}

stock int GetRandomPlayer()
{
	int[] clients = new int[MaxClients];
	int clientCount;

	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		if (!IsFakeClient(i))
		{
			clients[clientCount++] = i;
		}
	}

	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock int GetRandomPlayerNoAdmin()
{
	int[] clients = new int[MaxClients];
	int clientCount;

	for (int i = 1; i <= MaxClients; i++) 
		if (IsClientInGame(i))
		{
			if (!IsFakeClient(i) && !CheckCommandAccess(i, "sm_giveaway_flag_overwrite", ADMFLAG_GENERIC))
			{
				clients[clientCount++] = i;
			}
		}

	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
