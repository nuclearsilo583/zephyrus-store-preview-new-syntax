#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new GAME_CSS = false;
new GAME_CSGO = false;
new GAME_DOD = false;
new GAME_TF2 = false;
new GAME_L4D = false;
new GAME_L4D2 = false;
#endif

new g_iPlayerPot[MAXPLAYERS+1];
new g_iPlayerTeam[MAXPLAYERS+1];
new g_iBettingStart = 0;

new g_cvarEnableBetting = -1;
new g_cvarBettingPeriod = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Betting_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "cstrike")==0)
		GAME_CSS = true;
	else if(strcmp(m_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	else if(strcmp(m_szGameDir, "dod")==0)
		GAME_DOD = true;
	else if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
	else if(strcmp(m_szGameDir, "l4d")==0)
		GAME_L4D = true;
	else if(strcmp(m_szGameDir, "l4d2")==0)
		GAME_L4D2 = true;
#endif

	g_cvarEnableBetting = RegisterConVar("sm_store_betting", "1", "Enable/disable betting of credits", TYPE_INT);
	g_cvarBettingPeriod = RegisterConVar("sm_store_betting_period", "15", "How many seconds betting should be enabled for after round start", TYPE_INT);

	if(GAME_CSS || GAME_CSGO)
	{
		HookEvent("round_start", Betting_RoundStart);
		HookEvent("round_end", Betting_RoundEnd);
	} else if(GAME_TF2)
	{
		HookEvent("teamplay_round_start", Betting_RoundStart);
		HookEvent("teamplay_round_win", Betting_RoundEnd);
	}

	RegConsoleCmd("sm_bet", Command_Bet);

	// Load the translations file
	LoadTranslations("store.phrases");
}

#if defined STANDALONE_BUILD
public OnClientDisconnect(client)
#else
public Betting_OnClientDisconnect(client)
#endif
{
	if(g_iPlayerPot[client] > 0)
	{
		Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iPlayerPot[client]);
		g_iPlayerPot[client]=0;
		g_iPlayerTeam[client]=0;
	}
}

public Action:Command_Bet(client, args)
{
	if(!g_eCvars[g_cvarEnableBetting][aCache])
		return Plugin_Handled;

	if(g_iBettingStart+g_eCvars[g_cvarBettingPeriod][aCache] < GetTime())
	{
		Chat(client, "%t", "Betting Period Over");
		return Plugin_Handled;
	}

		
	if(g_iPlayerPot[client]>0)
	{
		Chat(client, "%t", "Betting Already Placed");
		return Plugin_Handled;
	}

	new String:m_szTeam[4];
	GetCmdArg(1, m_szTeam, sizeof(m_szTeam));

	new String:m_szAmount[11];
	GetCmdArg(2, m_szAmount, sizeof(m_szAmount));

	new m_iCredits = StringToInt(m_szAmount);
	if(strcmp(m_szAmount, "all")==0)
		m_iCredits = Store_GetClientCredits(client);

	if(!(0<m_iCredits<=Store_GetClientCredits(client)))
	{
		Chat(client, "%t", "Credit Invalid Amount");
		return Plugin_Handled;
	}

	if(strcmp(m_szTeam, "t")==0 || strcmp(m_szTeam, "red")==0)
		g_iPlayerTeam[client]=2;
	else if(strcmp(m_szTeam, "ct")==0 || strcmp(m_szTeam, "blu")==0)
		g_iPlayerTeam[client]=3;
	else
	{
		Chat(client, "%t", "Betting Invalid Team");
		return Plugin_Handled;
	}

	g_iPlayerPot[client] = m_iCredits;
	Store_SetClientCredits(client, Store_GetClientCredits(client)-m_iCredits);

	Chat(client, "%t", "Betting Placed", m_iCredits);

	return Plugin_Handled;
}

public Action:Betting_RoundStart(Handle:event,const String:name[],bool:dontBroadcast)
{
	g_iBettingStart = GetTime();

	// Give back any credits that left in the pot for whatever reason
	for(new i=1;i<=MaxClients;++i)
	{
		if(IsClientInGame(i) && g_iPlayerPot[i])
			Store_SetClientCredits(i, Store_GetClientCredits(i)+g_iPlayerPot[i]);
		g_iPlayerPot[i]=0;
		g_iPlayerTeam[i]=0;
	}
	return Plugin_Continue;
}

public Action:Betting_RoundEnd(Handle:event,const String:name[],bool:dontBroadcast)
{
	decl m_iWinner;
	if(GAME_TF2)
		m_iWinner = GetEventInt(event, "team");
	else if(GAME_CSS || GAME_CSGO)
		m_iWinner = GetEventInt(event, "winner");
	new m_iTeam1Pot = 0;
	new m_iTeam2Pot = 0;
	for(new i=1;i<=MaxClients;++i)
		if(g_iPlayerTeam[i]==2)
			m_iTeam1Pot+=g_iPlayerPot[i];
		else if(g_iPlayerTeam[i]==3)
			m_iTeam2Pot+=g_iPlayerPot[i];

	if((m_iTeam1Pot == 0 && m_iTeam2Pot == 0) || (m_iTeam1Pot != 0 && m_iTeam2Pot == 0) || (m_iTeam1Pot == 0 && m_iTeam2Pot != 0) || !(2<=m_iWinner<=3))
	{
		for(new i=1;i<=MaxClients;++i)
		{
			if(IsClientInGame(i) && g_iPlayerPot[i])
				Store_SetClientCredits(i, Store_GetClientCredits(i)+g_iPlayerPot[i]);
			g_iPlayerPot[i]=0;
			g_iPlayerTeam[i]=0;
		}
		return Plugin_Continue;
	}

	decl Float:m_fMultiplier;
	if(m_iWinner == 2)
		m_fMultiplier = (m_iTeam1Pot+m_iTeam2Pot)/float(m_iTeam1Pot);
	else
		m_fMultiplier = (m_iTeam1Pot+m_iTeam2Pot)/float(m_iTeam2Pot);

	for(new i=1;i<=MaxClients;++i)
	{
		if(IsClientInGame(i))
		{
			if(g_iPlayerTeam[i] == m_iWinner)
			{
				Store_SetClientCredits(i, Store_GetClientCredits(i)+RoundFloat(g_iPlayerPot[i]*m_fMultiplier));
				Chat(i, "%t", "Betting Won", RoundFloat(g_iPlayerPot[i]*m_fMultiplier));
			}
			else
				Chat(i, "%t", "Betting Lost", g_iPlayerPot[i]);
		}
		g_iPlayerPot[i]=0;
		g_iPlayerTeam[i]=0;
	}

	return Plugin_Continue;
}