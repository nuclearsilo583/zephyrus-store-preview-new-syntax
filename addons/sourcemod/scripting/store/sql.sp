//////////////////////////////
//		SQL CALLBACKS		//
//////////////////////////////
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

		if(m_szDriver[0] == 'm')
		{
			g_bMySQL = true;
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_players` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `authid` varchar(32) NOT NULL,\
										  `name` varchar(64) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `date_of_join` int(11) NOT NULL,\
										  `date_of_last_join` int(11) NOT NULL,\
										  PRIMARY KEY (`id`),\
										  UNIQUE KEY `id` (`id`),\
										  UNIQUE KEY `authid` (`authid`)\
										) ENGINE=InnoDB AUTO_INCREMENT=0 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_items` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `date_of_purchase` int(11) NOT NULL,\
										  `date_of_expiration` int(11) NOT NULL,\
										  PRIMARY KEY (`id`)\
										) ENGINE=InnoDB AUTO_INCREMENT=0 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_equipment` (\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `slot` int(11) NOT NULL\
										) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_logs` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` timestamp NOT NULL,\
										  PRIMARY KEY (`id`)\
										) ENGINE=InnoDB AUTO_INCREMENT=0 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_plugin_logs` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `level` varchar(8) NOT NULL,\
										   name varchar(64) NOT NULL default '',\
										   steam varchar(64) NOT NULL default '',\
										  `player_id` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` timestamp NOT NULL,\
										  PRIMARY KEY (`id`),\
										  UNIQUE KEY `id` (`id`)\
										) ENGINE=InnoDB AUTO_INCREMENT=0 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_items ADD COLUMN price_of_purchase int(11)");
			// Edit exist date column
			SQL_TQuery(g_hDatabase, SQLCallback_CheckError, "ALTER TABLE store_logs MODIFY COLUMN date TIMESTAMP NOT NULL");
			
			SQL_TQuery(g_hDatabase, SQLCallback_CheckError, "ALTER TABLE store_players CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
			SQL_TQuery(g_hDatabase, SQLCallback_CheckError, "ALTER TABLE store_plugin_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
			char m_szQuery[512];
			Format(STRING(m_szQuery), "CREATE TABLE IF NOT EXISTS `%s` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `parent_id` int(11) NOT NULL DEFAULT '-1',\
										  `item_price` int(32) NOT NULL,\
										  `item_type` varchar(64) NOT NULL,\
										  `item_flag` varchar(64) NOT NULL,\
										  `item_name` varchar(64) NOT NULL,\
										  `additional_info` text NOT NULL,\
										  `item_status` tinyint(1) NOT NULL,\
										  `supported_game` varchar(64) NOT NULL,\
										  PRIMARY KEY (`id`)\
										) ENGINE=InnoDB AUTO_INCREMENT=0 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", g_eCvars[g_cvarItemsTable].sCache);
			SQL_TVoid(g_hDatabase, m_szQuery);
		}
		else
		{
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_players` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `authid` varchar(32) NOT NULL,\
										  `name` varchar(64) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `date_of_join` int(11) NOT NULL,\
										  `date_of_last_join` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_items` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `date_of_purchase` int(11) NOT NULL,\
										  `date_of_expiration` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_equipment` (\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `slot` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_plugin_logs` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `level` varchar(8) NOT NULL,\
										   name varchar(64) NOT NULL default '',\
										   steam varchar(64) NOT NULL default '',\
										  `player_id` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` timestamp NOT NULL\
										)");	
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_items ADD COLUMN price_of_purchase int(11)");
			if(strcmp(g_eCvars[g_cvarItemSource].sCache, "database")==0)
			{
	
				SetFailState("Database item source can only be used with MySQL databases");
			}
		}
		
		// Do some housekeeping
		char m_szQuery[256], m_szLogCleaningQuery[256];
		Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `date_of_expiration` <> 0 AND `date_of_expiration` < %d", GetTime());
		SQL_TVoid(g_hDatabase, m_szQuery);
		

		if (g_eCvars[g_cvarLogLast].aCache>0)
		{
			if(m_szDriver[0] == 'm')
			{
				Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_plugin_logs WHERE `date` < CURDATE()-%i", g_eCvars[g_cvarLogLast].aCache);
				SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
				Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_logs WHERE `date` < CURDATE()-%i", g_eCvars[g_cvarLogLast].aCache);
				SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
			}
			else
			{
				Format(STRING(m_szLogCleaningQuery), "DELETE FROM store_plugin_logs WHERE `date` < (SELECT DATETIME('now', '-%i day'))", g_eCvars[g_cvarLogLast].aCache);
				SQL_TVoid(g_hDatabase, m_szLogCleaningQuery);
			}
		}
		
		if(!SQL_SetCharset(g_hDatabase, "utf8mb4")){
			SQL_SetCharset(g_hDatabase, "utf8");
		}
	}
}

public void SQLCallback_CheckError(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(!StrEqual("", error))
		LogError("Error happened. Error: %s", error);
}

public void SQLCallback_LoadClientInventory_Credits(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
		
		char m_szQuery[256];
		char m_szSteamID[32];
		int m_iTime = GetTime();
		g_eClients[client].iUserId = userid;
		g_eClients[client].iItems = -1;
		GetLegacyAuthString(client, STRING(m_szSteamID), false);
		//strcopy(g_eClients[client].szAuthId, 32, m_szSteamID[8]);
		strcopy(g_eClients[client].szAuthId, sizeof(Client_Data::szAuthId), m_szSteamID[8]);
		GetClientName(client, g_eClients[client].szName_Client, 64);
		SQL_EscapeString(g_hDatabase, g_eClients[client].szName_Client, g_eClients[client].szNameEscaped, 128);
		
		if(SQL_FetchRow(hndl))
		{
			g_eClients[client].iId_Client = SQL_FetchInt(hndl, 0);
			g_eClients[client].iCredits = SQL_FetchInt(hndl, 3);
			g_eClients[client].iOriginalCredits = SQL_FetchInt(hndl, 3);
			g_eClients[client].iDateOfJoin = SQL_FetchInt(hndl, 4);
			g_eClients[client].iDateOfLastJoin = m_iTime;
			
			Format(STRING(m_szQuery), "SELECT * FROM store_items WHERE `player_id`=%d", g_eClients[client].iId_Client);
			SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Items, m_szQuery, userid);

			Store_LogMessage(client, g_eClients[client].iCredits, "Amount of credits when the player joined");
			
			Store_SaveClientData(client);
		}
		else
		{
			Format(STRING(m_szQuery), "INSERT INTO store_players (`authid`, `name`, `credits`, `date_of_join`, `date_of_last_join`) VALUES('%s', '%s', %d, %d, %d)",
						g_eClients[client].szAuthId, g_eClients[client].szNameEscaped, g_eCvars[g_cvarStartCredits].aCache, m_iTime, m_iTime);
			SQL_TQuery(g_hDatabase, SQLCallback_InsertClient, m_szQuery, userid);
			g_eClients[client].iCredits = g_eCvars[g_cvarStartCredits].aCache;
			g_eClients[client].iOriginalCredits = g_eCvars[g_cvarStartCredits].aCache;
			g_eClients[client].iDateOfJoin = m_iTime;
			g_eClients[client].iDateOfLastJoin = m_iTime;
			g_eClients[client].bLoaded= true;
			g_eClients[client].iItems = 0;

			if(g_eCvars[g_cvarStartCredits].aCache > 0)
				Store_LogMessage(client, g_eCvars[g_cvarStartCredits].aCache, "Start credits");
		}
		
		g_eClients[client].hCreditTimer = Store_CreditTimer(client);
	}
}

public void SQLCallback_LoadClientInventory_Items(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{	
		int client = GetClientOfUserId(userid);
		if(!client)
			return;

		char m_szQuery[256];
		Format(STRING(m_szQuery), "SELECT * FROM store_equipment WHERE `player_id`=%d", g_eClients[client].iId_Client);
		SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Equipment, m_szQuery, userid);

		if(!SQL_GetRowCount(hndl))
		{
			g_eClients[client].bLoaded = true;
			g_eClients[client].iItems = 0;
			return;
		}
		
		char m_szUniqueId[PLATFORM_MAX_PATH];
		char m_szType[16];
		int m_iExpiration;
		int m_iUniqueId;
		int m_iTime = GetTime();
		
		int i = 0;
		while(SQL_FetchRow(hndl))
		{
			m_iUniqueId = -1;
			m_iExpiration = SQL_FetchInt(hndl, 5);
			if(m_iExpiration && m_iExpiration<=m_iTime)
				continue;
			
			SQL_FetchString(hndl, 2, STRING(m_szType));
			SQL_FetchString(hndl, 3, STRING(m_szUniqueId));
			while((m_iUniqueId = Store_GetItemId(m_szType, m_szUniqueId, m_iUniqueId))!=-1)
			{
				g_eClientItems[client][i].iId_Client_Item = SQL_FetchInt(hndl, 0);
				g_eClientItems[client][i].iUniqueId = m_iUniqueId;
				g_eClientItems[client][i].bSynced = true;
				g_eClientItems[client][i].bDeleted = false;
				g_eClientItems[client][i].iDateOfPurchase = SQL_FetchInt(hndl, 4);
				g_eClientItems[client][i].iDateOfExpiration = m_iExpiration;
				g_eClientItems[client][i].iPriceOfPurchase = SQL_FetchInt(hndl, 6);
			
				++i;
			}
		}
		g_eClients[client].iItems = i;
	}
}

public void SQLCallback_LoadClientInventory_Equipment(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
		
		char m_szUniqueId[PLATFORM_MAX_PATH];
		char m_szType[16];
		int m_iUniqueId;
		//int m_iFlags = GetUserFlagBits(client);
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 1, STRING(m_szType));
			SQL_FetchString(hndl, 2, STRING(m_szUniqueId));
			m_iUniqueId = Store_GetItemId(m_szType, m_szUniqueId);
			if(m_iUniqueId == -1)
				continue;
			
			// Client Dont have the item
			if(!Store_HasClientItem(client, m_iUniqueId)) 
			{
				//PrintToChat(client, "You dont have item/ unequip");
				Store_UnequipItem(client, m_iUniqueId);
			}
			// Client has item but VIP period is expired.
			else if(Store_HasClientItem(client, m_iUniqueId) && !GetClientPrivilege(client, g_eItems[m_iUniqueId].iFlagBits))
			{
				//PrintToChat(client, "You ahve have item but no flag/ Sold.");
				if (g_eCvars[g_cvarSellRestricted].aCache)
				{
					Store_SellItem(client, m_iUniqueId); // Sell the item.
				}
				else
				{
					Store_UnequipItem(client, m_iUniqueId); // Just prevent the player from equipping it.
				}
			}
			// Client has item and has access to the item.
			else 
			{
				//PrintToChat(client, "You have item/ equip");
				Store_UseItem(client, m_iUniqueId, true, SQL_FetchInt(hndl, 3)); 
			}
		}
		g_eClients[client].bLoaded = true;
	}
}

public void SQLCallback_RefreshCredits(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
			
		if(SQL_FetchRow(hndl))
		{
			g_eClients[client].iCredits = SQL_FetchInt(hndl, 3);
			g_eClients[client].iOriginalCredits = SQL_FetchInt(hndl, 3);
		}
	}
}

public void SQLCallback_InsertClient(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);
		if(!client)
			return;
			
		g_eClients[client].iId_Client = SQL_GetInsertId(hndl);
	}
}

public void SQLCallback_ReloadConfig(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
	{
		SetFailState("Error happened reading the config table. The plugin cannot continue.", error);
	}
	else
	{
		char m_szType[64];
		char m_szFlag[64];
		char m_szInfo[2048];
		char m_szKey[64];
		char m_szValue[256];
		
		Handle m_hKV;
		
		bool m_bSuccess;
		
		int m_iLength;
		int m_iHandler;
		int m_iIndex = 0;
	
		while(SQL_FetchRow(hndl))
		{
			if(g_iItems == STORE_MAX_ITEMS)
				return;
				
			if(!SQL_FetchInt(hndl, 7))
				continue;
			
			g_eItems[g_iItems].iId = SQL_FetchInt(hndl, 0);
			g_eItems[g_iItems].iParent = SQL_FetchInt(hndl, 1);
			g_eItems[g_iItems].iPrice = SQL_FetchInt(hndl, 2);
			
			IntToString(g_eItems[g_iItems].iId, g_eItems[g_iItems].szUniqueId, PLATFORM_MAX_PATH);
			
			SQL_FetchString(hndl, 3, STRING(m_szType));
			m_iHandler = Store_GetTypeHandler(m_szType);
			if(m_iHandler == -1)
				continue;
			
			g_eItems[g_iItems].iHandler = m_iHandler;
			
			SQL_FetchString(hndl, 4, STRING(m_szFlag));
			g_eItems[g_iItems].iFlagBits = ReadFlagString(m_szFlag);
			
			SQL_FetchString(hndl, 5, g_eItems[g_iItems].szName, ITEM_NAME_LENGTH);
			SQL_FetchString(hndl, 6, STRING(m_szInfo));
			
			m_hKV = CreateKeyValues("Additional Info");
			
			m_iLength = strlen(m_szInfo);
			while(m_iIndex != m_iLength)
			{
				m_iIndex += strcopy(m_szKey, StrContains(m_szInfo[m_iIndex], "="), m_szInfo[m_iIndex])+2;
				m_iIndex += strcopy(m_szValue, StrContains(m_szInfo[m_iIndex], "\";"), m_szInfo[m_iIndex])+2; // \"
				
				KvJumpToKey(m_hKV, m_szKey, true);
				KvSetString(m_hKV, m_szKey, m_szValue);
				
				m_bSuccess = true;
				if(g_eTypeHandlers[m_iHandler].fnConfig!=INVALID_FUNCTION)
				{
					Call_StartFunction(g_eTypeHandlers[m_iHandler].hPlugin, g_eTypeHandlers[m_iHandler].fnConfig);
					Call_PushCellRef(m_hKV);
					Call_PushCell(g_iItems);
					Call_Finish(m_bSuccess); 
				}
				
				if(m_bSuccess)
					++g_iItems;
			}
			CloseHandle(m_hKV);
		}
	}
}

public void SQLCallback_ResetPlayer(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		int client = GetClientOfUserId(userid);

		if(SQL_GetRowCount(hndl))
		{
			SQL_FetchRow(hndl);
			int id = SQL_FetchInt(hndl, 0);
			char m_szAuthId[32];
			SQL_FetchString(hndl, 1, STRING(m_szAuthId));

			char m_szQuery[512];
			Format(STRING(m_szQuery), "DELETE FROM store_players WHERE id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);
			Format(STRING(m_szQuery), "DELETE FROM store_items WHERE player_id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);
			Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE player_id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);

			//ChatAll("%t", "Player Resetted", m_szAuthId);
			CPrintToChatAll("%s%t", g_sChatPrefix, "Player Resetted", m_szAuthId);

		}
		else
			if(client)
			{
				//Chat(client, "%t", "Credit No Match");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit No Match");
			}
	}
}

public void SQLCallback_Void_Error(Handle owner, Handle hndl, const char[] error, any data)
{
	if (owner == null)
	{
		StoreLogMessage(0, LOG_ERROR, "SQLCallback_Void_Error: %s", error);
	}
}