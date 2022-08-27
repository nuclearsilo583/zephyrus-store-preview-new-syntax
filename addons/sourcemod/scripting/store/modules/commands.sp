#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new String:g_szCommands[STORE_MAX_ITEMS][128];
new String:g_szCommandsOff[STORE_MAX_ITEMS][128];
new g_unCommandsTime[STORE_MAX_ITEMS];

new g_iCommands = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Commands_OnPluginStart()
#endif
{
	Store_RegisterHandler("command", "", Commands_OnMapStart, Commands_Reset, Commands_Config, Commands_Equip, Commands_Remove, false);
}

public Commands_OnMapStart()
{
}

public Commands_Reset()
{
	g_iCommands = 0;
}

public Commands_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iCommands);
	
	KvGetString(kv, "command", g_szCommands[g_iCommands], sizeof(g_szCommands[]));
	KvGetString(kv, "command_off", g_szCommandsOff[g_iCommands], sizeof(g_szCommands[]));
	g_unCommandsTime[g_iCommands] = KvGetNum(kv, "time", -1);
	
	++g_iCommands;
	return true;
}

public Commands_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	decl String:m_szCommand[256];
	strcopy(STRING(m_szCommand), g_szCommands[m_iData]);

	decl String:m_szClientID[11];
	decl String:m_szUserID[11];
	new String:m_szSteamID[32] = "\"";
	new String:m_szName[66] = "\"";

	IntToString(client, STRING(m_szClientID));
	IntToString(GetClientUserId(client), STRING(m_szUserID));
	GetClientAuthId(client, AuthId_Steam2, m_szSteamID[1], sizeof(m_szSteamID)-1);
	GetClientName(client, m_szName[1], sizeof(m_szName)-1);

	m_szSteamID[strlen(m_szSteamID)] = '"';
	m_szName[strlen(m_szName)] = '"';

	ReplaceString(STRING(m_szCommand), "{clientid}", m_szClientID);
	ReplaceString(STRING(m_szCommand), "{userid}", m_szUserID);
	ReplaceString(STRING(m_szCommand), "{steamid}", m_szSteamID);
	ReplaceString(STRING(m_szCommand), "{name}", m_szName);

	ServerCommand("%s", m_szCommand);

	if(g_unCommandsTime[m_iData]!=-1)
	{
		new Handle:m_hPack = CreateDataPack();
		WritePackCell(m_hPack, GetClientUserId(client));
		WritePackCell(m_hPack, m_iData);
		ResetPack(m_hPack);

		CreateTimer(g_unCommandsTime[m_iData]*1.0, Timer_CommandOff, m_hPack);
	}

	return 0;
}

public Commands_Remove(client)
{
	return 0;
}

public Action:Timer_CommandOff(Handle:timer, any:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	new m_iData = ReadPackCell(data);
	CloseHandle(data);

	decl String:m_szCommand[256];
	strcopy(STRING(m_szCommand), g_szCommandsOff[m_iData]);

	decl String:m_szClientID[11];
	decl String:m_szUserID[11];
	new String:m_szSteamID[32] = "\"";
	new String:m_szName[66] = "\"";

	if(client)
	{
		IntToString(client, STRING(m_szClientID));
		IntToString(GetClientUserId(client), STRING(m_szUserID));
		GetClientAuthId(client, AuthId_Steam2, m_szSteamID[1], sizeof(m_szSteamID)-1);
		GetClientName(client, m_szName[1], sizeof(m_szName)-1);
	}

	m_szSteamID[strlen(m_szSteamID)] = '"';
	m_szName[strlen(m_szName)] = '"';

	ReplaceString(STRING(m_szCommand), "{clientid}", m_szClientID);
	ReplaceString(STRING(m_szCommand), "{userid}", m_szUserID);
	ReplaceString(STRING(m_szCommand), "{steamid}", m_szSteamID);
	ReplaceString(STRING(m_szCommand), "{name}", m_szName);

	ServerCommand("%s", m_szCommand);

	return Plugin_Stop;
}