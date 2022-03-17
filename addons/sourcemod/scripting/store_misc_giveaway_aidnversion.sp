#include <sourcemod>
#include <multicolors>
#include <sdktools>
#include <store>

#pragma newdecls required

ConVar 	gc_iCredits,
		gc_iMinCredits,
		gc_iMinPlayer,
		gc_iTimeInfo,
		gc_bAdmin,
		gc_bOwnCredits,
		gc_vFlagStart;
		
ConVar gc_sTag;
char g_sChatPrefix[128];

//char g_sTag[32];
char admins[MAX_NAME_LENGTH];
int number, credits;
int creatorID;
Handle timers;

int g_iActive = 0;

public Plugin myinfo = {
	name = "Store Giveaway AiDN™ version",
	author = "nuclear silo, AiDN™",
	description = "Giveaway plugin compatible with zephyrus store.",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	gc_iCredits = CreateConVar("sm_giveaway_credits", "1000", "Number of credits given.");
	gc_iMinCredits = CreateConVar("sm_giveaway_min_credits", "250", "Number of min credits given.");
	gc_iMinPlayer = CreateConVar("sm_giveaway_minplayers", "5", "Minimum players required in the server for the giveaway.");
	gc_iTimeInfo = CreateConVar("sm_giveaway_time_info", "10", "Time in second of giveaway announcement. Minimum is 10 seconds. Type INT");
	gc_bAdmin = CreateConVar("sm_giveaway_count_admin", "1", "Can admin join the giveaway [0 - no, 1 - yes]");
	gc_bOwnCredits = CreateConVar("sm_giveaway_own_credits", "0", "Start giveaway with own or with server credits, [0 - server credits, 1 = own credits]");
	gc_vFlagStart = CreateConVar("sm_giveaway_flag", "z", "Admin flag for start giveaway (empty for all players)");

	RegConsoleCmd("sm_giveaway", CommandGiveaway, "Start giveaway");

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
	char sBuffer[32];
	gc_vFlagStart.GetString(sBuffer, sizeof(sBuffer));

	if(g_iActive == 0)
	{
		if (CheckAdminFlags(client, ReadFlagString(sBuffer)))
		{
		
			int count;
			if(gc_bAdmin.BoolValue)
				count = PlayerCount();
			else count = PlayerCountNoAdmin();
			
			if (!args)
			{
				number = gc_iTimeInfo.IntValue;
				credits = gc_iCredits.IntValue;
				if(count >= gc_iMinPlayer.IntValue)
				{
					//CreateTimer(0.1, TimerGiveaway, _, TIMER_REPEAT);
					char name[MAX_NAME_LENGTH];
					GetClientName(client, name, MAX_NAME_LENGTH);
					admins = name;
					creatorID = client;
					
					if(gc_bOwnCredits.BoolValue)
					{
						if(Store_GetClientCredits(client) >= credits)
						{
							Store_SetClientCredits(client, Store_GetClientCredits(client) - credits);
							LogAction(client, credits, "%N started giveaway with %i credits.", client, credits); 
							CountDown(name);
							g_iActive++;
						}
						else
						{
							CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Giveaway Not Enough");
							return Plugin_Handled;
						}
					}
					else return Plugin_Continue;
					
					CountDown(name);
					g_iActive++;
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
				if(count >= gc_iMinPlayer.IntValue)
				{
					//CreateTimer(0.1, TimerGiveaway, _, TIMER_REPEAT);
					char name[MAX_NAME_LENGTH];
					GetClientName(client, name, MAX_NAME_LENGTH);
					admins = name;
					creatorID = client;
					
					if(gc_bOwnCredits.BoolValue)
					{
						if(Store_GetClientCredits(client) >= credits && credits >= gc_iMinCredits.IntValue)
						{
							Store_SetClientCredits(client, Store_GetClientCredits(client) - credits);
							LogAction(client, credits, "%N started giveaway with %i credits.", client, credits); 
							CountDown(name);
							g_iActive++;
						}
						else
						{
							CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Giveaway Not Enough", gc_iMinCredits.IntValue);
							return Plugin_Handled;
						}
					}
					else return Plugin_Continue;
					
					CountDown(name);
					g_iActive++;
				}
				else
				{
					CPrintToChat(client, "%t", "Giveaway Minimum Players", g_sChatPrefix, gc_iMinPlayer.IntValue);
				}
			}
			else ReplyToCommand(client, "{yellow}%s {default}Usage: sm_giveaway <credits>", g_sChatPrefix);
			
			
			return Plugin_Handled;
		}
		else CPrintToChat(client, "%s%t", g_sChatPrefix, "No have flag");
	}
	else CPrintToChat(client, "%s%t", g_sChatPrefix, "Now run a giveaway");
	
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
		Store_SQLLogMessage(creatorID, LOG_EVENT, "%s did a giveaway and %s won", admins, name);
		
		g_iActive = 0;
		
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

bool CheckAdminFlags(int client, int iFlag)
{
	int iUserFlags = GetUserFlagBits(client);
	return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}
