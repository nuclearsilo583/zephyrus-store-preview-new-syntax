#include <sourcemod>
#include <colorvariables>
#include <sdktools>
#include <store>

#pragma newdecls required

ConVar gc_iCredits;
ConVar gc_iMinPlayer;
ConVar gc_iTimeInfo;

ConVar gc_sTag;
char g_sChatPrefix[128];

//char g_sTag[32];
char admins[MAX_NAME_LENGTH];
int number, credits;
Handle timers;

public Plugin myinfo = {
	name = "Store Giveaway",
	author = "nuclear silo",
	description = "Giveaway plugin compatible with zephyrus store.",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	gc_iCredits = CreateConVar("sm_giveaway_credits", "5000", "Number of credits given.");
	gc_iMinPlayer = CreateConVar("sm_giveaway_minplayers", "5", "Minimum players required in the server for the giveaway.");
	gc_iTimeInfo = CreateConVar("sm_giveaway_time_info", "10", "Time in second of giveaway announcement. Minimun is 10 seconds. Type INT");

	RegAdminCmd("sm_giveaway", CommandGiveaway, ADMFLAG_ROOT, "Start giveaway");
	//RegConsoleCmd("sm_giveaway", CommandGiveaway, "Start giveaway");

	AutoExecConfig(true, "plugin.zGiveaway");

	LoadTranslations("store.phrases");
	
	
}

public void OnConfigsExecuted()
{
	gc_sTag = FindConVar("sm_store_chat_tag");
	gc_sTag.GetString(g_sChatPrefix, sizeof(g_sChatPrefix));
}

public Action CommandGiveaway(int client, int args)
{
	//if (!CheckCommandAccess(client, "sm_giveaway_flag_overwrite", ADMFLAG_ROOT))
		//return Plugin_Handled;
	int i, count;
	for (i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
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
	if (Number >= 100) 
	{
		Number = 0;
		char name[MAX_NAME_LENGTH];
		int randomNumber = GetRandomPlayer();
		GetClientName(randomNumber, name, MAX_NAME_LENGTH);
		
		PrintCenterTextAll("<big><u><b><font color='#dd2f2f'><center>%s</center>\n</font><font color='#00CCFF'>|| <font color='#15fb00'>Winner: <font color='#ff0000'>%s<font color='#00CCFF'> ||</font></b></u></big>", g_sChatPrefix, name);
		CPrintToChatAll("{yellow}%s {purple}%s {default}won a giveaway with {green}%i {yellow}credits", g_sChatPrefix, name, credits);
		
		Store_SetClientCredits(randomNumber, Store_GetClientCredits(randomNumber) + credits);
		
		LogToFile("addons/sourcemod/logs/zgiveaway/zgiveawayfile.log", "The admin %s did a giveaway and %s won", admins, name);
		
		return Plugin_Stop;
	}
	char name[MAX_NAME_LENGTH];
 	int randomNumber = GetRandomPlayer();
	GetClientName(randomNumber, name, MAX_NAME_LENGTH);
	PrintCenterTextAll("<big><u><b><font color='#00CCFF'>|| <font color='#15fb00'>%s</font> ||</font></b></u></big>", name);
	Number++;			
	return Plugin_Continue;
}

void CountDown(char[] admin)
{
	if(timers != INVALID_HANDLE)
	{
		KillTimer(timers);
		timers = INVALID_HANDLE;
	}
	timers = CreateTimer(1.0, Repeater, _, TIMER_REPEAT);
	PrintCenterTextAll("<font color='#00CCFF'>Admin <font color='#ff0000'>%s<font color='#00CCFF'> opened a giveaway with "
						... "<font color='#15fb00'>%i </font><font color='#00CCFF'>credits"
						, admin, credits);
}

public Action Repeater(Handle timer)
{
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
	if (number >=7)
	{
		PrintCenterTextAll("<font color='#00CCFF'>Admin <font color='#ff0000'>%s<font color='#00CCFF'> opened a giveaway with "
						... "<font color='#15fb00'>%i <font color='#00CCFF'>credits"
						, admins, credits);
	}
	if (0 < number < 7)
		PrintCenterTextAll("<font color='#00CCFF'>|| <font color='#15fb00'>Giveaway starts in <font color='#ffff00'>%i<font color='#15fb00'> seconds</font><font color='#00CCFF'> ||", number);
}

stock int GetRandomPlayer()
{
	int[] clients = new int[MaxClients];
	int clientCount;

	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		if (IsPlayerAlive(i) && !IsFakeClient(i))
		{
			clients[clientCount++] = i;
		}
	}

	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
