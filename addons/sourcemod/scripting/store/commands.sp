void Store_Commands_OnPluginStart()
{
	// Register Commands
	// --- Other commands are now registered in OnConfigsExecuted with the RegisterCommand function ---
	RegServerCmd("sm_store_custom_credits", Command_CustomCredits);
	
	RegAdminCmd("sm_store_reloadconfig", Command_ReloadConfig, ADMFLAG_ROOT);
	
	// Add a say command listener for shortcuts
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

void Store_Commands_OnConfigsExecuted()
{	
	// Register commands
	char sCommands[10][60]; // 10 commands of 60 bytes max
	RegisterCommand(g_eCvars[g_cvarCommandsStore].sCache, Command_Store, sCommands, sizeof(sCommands), sizeof(sCommands[]));
	RegisterCommand(g_eCvars[g_cvarCommandsInventory].sCache, Command_Inventory, sCommands, sizeof(sCommands), sizeof(sCommands[]));
	RegisterCommand(g_eCvars[g_cvarCommandsGift].sCache, Command_Gift, sCommands, sizeof(sCommands), sizeof(sCommands[]));
	RegisterCommand(g_eCvars[g_cvarCommandsGive].sCache, Command_GiveCredits, sCommands, sizeof(sCommands), sizeof(sCommands[]));
	RegisterCommand(g_eCvars[g_cvarCommandsResetPlayer].sCache, Command_ResetPlayer, sCommands, sizeof(sCommands), sizeof(sCommands[]));
	RegisterCommand(g_eCvars[g_cvarCommandsCredits].sCache, Command_Credits, sCommands, sizeof(sCommands), sizeof(sCommands[]));
	RegisterCommand(g_eCvars[g_cvarCommandsResetLoadout].sCache, Command_ResetLoadout, sCommands, sizeof(sCommands), sizeof(sCommands[]));
}

/**
 * Registers one or multiple commands that point towards the same callback.
 * Designed to be used once in OnConfigsExecuted, to allow customizable commands.
 * -
 * const char[] command		A string containing the commands, starting with the sm_ prefix, and two commands being separated by a comma (,).
 * ConCmd callback			The command callback: the function that will be called when the command is executed.
 * char[][] sCommands		A 2D string array. First dimension: max number of commands, second dimension: max command size.
 * int sCommandsSize		sizeof(sCommands)
 * int sCommandsSize2		sizeof(sCommands[])
 */
stock void RegisterCommand(const char[] command, ConCmd callback, char[][] sCommands, int sCommandsSize, int sCommandsSize2)
{
	int iCommands = ExplodeString(command, ",", sCommands, sCommandsSize, sCommandsSize2);
	for (int i = 0; i < iCommands; i++)
	{
		RegConsoleCmd(sCommands[i], callback);
	}
}

//////////////////////////////////
//			COMMANDS	 		//
//////////////////////////////////

public Action Command_Say(int client, const char[] command,int argc)
{
	if(argc > 0)
	{
		char m_szArg[65];
		GetCmdArg(1, STRING(m_szArg));
		if(m_szArg[0] == g_iPublicChatTrigger)
		{
			for(int i=0;i<g_iItems;++i)
				if(strcmp(g_eItems[i].szShortcut, m_szArg[1])==0 && g_eItems[i].szShortcut[0] != 0)
				{
					g_bInvMode[client]=false;
					g_iMenuClient[client]=client;
					DisplayStoreMenu(client, i);
					break;
				}
		}
	}

	return Plugin_Continue;
}

public Action Command_Store(int client,int params)
{
	if(g_eCvars[g_cvarRequiredFlag].aCache && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag].aCache))
	{
		//Chat(client, "%t", "You dont have permission");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		//Chat(client, "%t", "Inventory hasnt been fetched");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	
	char itemname[64];
	GetCmdArg(1, itemname, sizeof(itemname));
	
	//if(itemname[0] == '$')
	//{
		//strcopy(itemname, sizeof(itemname), itemname);
	//Store_ItemName(client, itemname);
	//}
	
	if(params > 0)
	{
		Store_ItemName(client, itemname);
	}
	
	if(params == 0)
	{
		g_bInvMode[client]=false;
		g_iMenuClient[client]=client;
		DisplayStoreMenu(client);
	}
	
	return Plugin_Handled;
}


public Action Command_Inventory(int client,int params)
{
	if(g_eCvars[g_cvarRequiredFlag].aCache && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag].aCache))
	{
		//Chat(client, "%t", "You dont have permission");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		//Chat(client, "%t", "Inventory hasnt been fetched");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	
	g_bInvMode[client]=true;
	g_iMenuClient[client]=client;
	DisplayStoreMenu(client);

	return Plugin_Handled;
}


public Action Command_Gift(int client,int params)
{
	if(!g_eCvars[g_cvarCreditGiftEnabled].aCache)
	{
		//Chat(client, "%t", "Credit Gift Disabled");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Gift Disabled");
		return Plugin_Handled;
	}
	
	char m_szTmp[64];
	GetCmdArg(2, STRING(m_szTmp));
	
	int m_iCredits = StringToInt(m_szTmp);
	if(g_eClients[client].iCredits<m_iCredits || m_iCredits<=0)
	{
		//Chat(client, "%t", "Credit Invalid Amount");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Invalid Amount");
		return Plugin_Handled;
	}

	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));
	
	int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
	if(m_clients>2)
	{
		//Chat(client, "%t", "Credit Too Many Matches");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Too Many Matches");
		return Plugin_Handled;
	}
	
	if(m_clients != 1)
	{
		//Chat(client, "%t", "Credit No Match");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit No Match");
		return Plugin_Handled;
	}
	
	int m_iReceiver = m_iTargets[0];
	
	g_eClients[client].iCredits -= m_iCredits;
	g_eClients[m_iReceiver].iCredits += m_iCredits;
	
	//Chat(client, "%t", "Credit Gift Sent", m_iCredits, g_eClients[m_iReceiver].szName_Client);
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Gift Sent", m_iCredits, g_eClients[m_iReceiver].szName_Client);
	//Chat(m_iReceiver, "%t", "Credit Gift Received", m_iCredits, g_eClients[client].szName_Client);
	CPrintToChat(m_iReceiver, "%s%t", g_sChatPrefix, "Credit Gift Received", m_iCredits, g_eClients[client].szName_Client);

	Store_LogMessage(m_iReceiver, m_iCredits, "Gifted by %N", client);
	Store_LogMessage(client, -m_iCredits, "Gifted to %N", m_iReceiver);
	
	return Plugin_Handled;
}

public Action Command_GiveCredits(int client,int params)
{
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarAdminFlag].aCache))
	{
		//Chat(client, "%t", "You dont have permission");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	char m_szTmp[64];
	if(!GetCmdArg(2, STRING(m_szTmp)))
		CReplyToCommand(client, "%s Usage: sm_givecredits <target> <credits>", g_sChatPrefix);
	
	int m_iCredits = StringToInt(m_szTmp);

	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));

	int m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			char m_szQuery[512];
			if(g_bMySQL)
				SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "INSERT IGNORE INTO store_players (authid, credits) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE credits=credits+%d", m_szTmp[8], m_iCredits, m_iCredits);
			else
			{
				SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "INSERT OR IGNORE INTO store_players (authid) VALUES ('%s')", m_szTmp[8]);
				SQL_TVoid(g_hDatabase, m_szQuery);
				SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "UPDATE store_players SET credits=credits+%d WHERE authid='%s'", m_iCredits, m_szTmp[8]);
			}
			SQL_TVoid(g_hDatabase, m_szQuery);
			//ChatAll("%t", "Credits Given", m_szTmp[8], m_iCredits);
			CPrintToChatAll("%s%t", g_sChatPrefix, "Credits Given", m_szTmp[8], m_iCredits);
			m_iReceiver = -1;
		}
	} 
	else if(strcmp(m_szTmp, "@all")==0)
	{
		LoopIngamePlayers(i)
		{
			//FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
			AdminGiveCredits(i, m_iCredits);
		}
	} 
	else if(strcmp(m_szTmp, "@t")==0 || strcmp(m_szTmp, "@red")==0)
	{
		LoopIngamePlayers(i)
			if(GetClientTeam(i)==2)
			{
				//FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
				AdminGiveCredits(i, m_iCredits);
			}
	} 
	else if(strcmp(m_szTmp, "@ct")==0 || strcmp(m_szTmp, "@blu")==0)
	{
		LoopIngamePlayers(i)
			if(GetClientTeam(i)==3)
			{
				//FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
				AdminGiveCredits(i, m_iCredits);
			}
	}
	else
	{
		int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_clients>2)
		{
			if(client)
			{
				//Chat(client, "%t", "Credit Too Many Matches");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Too Many Matches");
			}
			else
				ReplyToCommand(client, "%t", "Credit Too Many Matches");
			return Plugin_Handled;
		} else if(m_clients != 1)
		{
			if(client)
			{
				//Chat(client, "%t", "Credit No Match");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit No Match");
			}
			else
				ReplyToCommand(client, "%t", "Credit No Match");
			return Plugin_Handled;
		}

		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		g_eClients[m_iReceiver].iCredits += m_iCredits;
		if(g_eCvars[g_cvarSilent].aCache == 1)
		{
			if(client)
			{
				//Chat(client, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			}
			else
				ReplyToCommand(client, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			//Chat(m_iReceiver, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			CPrintToChat(m_iReceiver, "%s%t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
		}
		else if(g_eCvars[g_cvarSilent].aCache == 0)
		{
			//ChatAll("%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			CPrintToChatAll("%s%t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
		}
		Store_LogMessage(m_iReceiver, m_iCredits, "Given by Admin");
		
		Store_SaveClientData(m_iReceiver);
		Store_SaveClientInventory(m_iReceiver);
		Store_SaveClientEquipment(m_iReceiver);
	}
	
	
	return Plugin_Handled;
}

public Action Command_ResetPlayer(int client,int params)
{
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarAdminFlag].aCache))
	{
		//Chat(client, "%t", "You dont have permission");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	char m_szTmp[64];
	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));

	int m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			char m_szQuery[512];
			SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "SELECT id, authid FROM store_players WHERE authid='%s'", m_szTmp[9]);
			SQL_TQuery(g_hDatabase, SQLCallback_ResetPlayer, m_szQuery, g_eClients[client].iUserId);
		}
	}
	else
	{	
		int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_clients>2)
		{
			//Chat(client, "%t", "Credit Too Many Matches");
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Too Many Matches");
			return Plugin_Handled;
		}
		
		if(m_clients != 1)
		{
			//Chat(client, "%t", "Credit No Match");
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit No Match");
			return Plugin_Handled;
		}

		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		Store_LogMessage(client, -g_eClients[m_iReceiver].iCredits, "Player resetted");
		g_eClients[m_iReceiver].iCredits = 0;
		for(int i=0;i<g_eClients[m_iReceiver].iItems;++i)
			Store_RemoveItem(m_iReceiver, g_eClientItems[m_iReceiver][i].iUniqueId);
		//ChatAll("%t", "Player Resetted", g_eClients[m_iReceiver].szName_Client);
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player Resetted", g_eClients[m_iReceiver].szName_Client);
	}
	
	return Plugin_Handled;
}

public Action Command_Credits(int client,int params)
{	
	if(g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1)
	{
		//Chat(client, "%t", "Inventory hasnt been fetched");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}

	if(g_iSpam[client]<GetTime())
	{
		//CPrintToChatAll("%t", "Player Credits", g_eClients[client][szName_Client], g_eClients[client][iCredits]);
		//ChatAll("%t", "Player Credits", g_eClients[client].szName_Client, g_eClients[client].iCredits);
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player Credits", g_eClients[client].szName_Client, g_eClients[client].iCredits);
		g_iSpam[client] = GetTime()+12;
		//g_iSpam[client] = GetTime()+ g_cvarCredits.FloatValue;
	}
	
	return Plugin_Handled;
}

public Action Command_CustomCredits(int params)
{
	if(params < 2)
	{
		PrintToServer("sm_store_custom_credits [flag] [multiplier]");
		return Plugin_Handled;
	}

	char tmp[16];
	GetCmdArg(1, STRING(tmp));
	char flag = ReadFlagString(tmp);
	GetCmdArg(2, STRING(tmp));
	float mult = StringToFloat(tmp);

	any size = GetArraySize(g_hCustomCredits);
	int index = -1;
	for(int i=0;i<size;++i)
	{
		int sflag = GetArrayCell(g_hCustomCredits, i, 0);
		if(sflag == flag)
		{
			index = i;
			break;
		}
	}

	if(index == -1)
	{
		index = PushArrayCell(g_hCustomCredits, flag);
	}

	SetArrayCell(g_hCustomCredits, index, mult, 1);

	return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
	
	if(g_eCvars[g_cvarConfirmation].aCache)
	{
		char buffer[128];
		if(!g_eCvars[gc_iReloadType].aCache)
			Format(buffer, sizeof(buffer), "%t", "confirm_reload_type_0", view_as<int>(g_eCvars[gc_iReloadDelay].aCache));
		else Format(buffer, sizeof(buffer), "%t", "confirm_reload_type_1");
		Store_DisplayConfirmMenu(client, buffer, FakeMenuHandler_StoreReloadConfig, 0);
	}
	else
	{
		Store_ReloadConfig();
		//ReplyToCommand(client, "%s %s", g_sChatPrefix, "Config reloaded. Please restart or change map");
		CReplyToCommand(client, "%s %t", g_sChatPrefix, "Config reloaded. Please restart or change map");
	}
	
	return Plugin_Handled;
}

public Action Command_ResetLoadout(int client, int args)
{
	if(!client)
		return Plugin_Handled;

	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		//Chat(client, "%t", "Inventory hasnt been fetched");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	else
	{
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "%t", "Store Confirm Reset Loadout");
		Store_DisplayConfirmMenu(client, sBuffer, FakeMenuHandler_StoreResetLoadout, 0);
	}

	return Plugin_Handled;
}