void StoreLogMessage(int client = 0, int level, char[] message, any ...)
{
	if (g_eCvars[g_cvarPluginsLogging].aCache < 1)
		return;

	char sLevel[8];
	char sReason[256];
	VFormat(sReason, sizeof(sReason), message, 4);
	
	char steamid[64], name[64];
	if(client)
	{
		// steam id, name
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		GetClientName(client, name, sizeof(name));
	}
	
	switch(level)
	{
		case LOG_ADMIN: strcopy(sLevel, sizeof(sLevel), "[Admin]");
		case LOG_EVENT: strcopy(sLevel, sizeof(sLevel), "[Event]");
		case LOG_CREDITS: strcopy(sLevel, sizeof(sLevel), "[Credits]");
		case LOG_ERROR:
		{
			strcopy(sLevel, sizeof(sLevel), "[ERROR]");
			LogError("%s - %L - %s", sLevel, client, sReason);
		}
	}

	if(g_eCvars[g_cvarPluginsLogging].aCache == 2)
	{
		char sQuery[1024];
		SQL_EscapeString(g_hDatabase, sQuery, sQuery, sizeof(sQuery));
		if (client)
		{
			if(g_bMySQL)
				Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", %i, \"%s\", CURRENT_TIMESTAMP, \"%s\", \"%s\")", sLevel, g_eClients[client].iId_Client, sReason, name, steamid);
			else
				Format(sQuery, sizeof(sQuery), "INSERT INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", %i, \"%s\", CURRENT_TIMESTAMP, \"%s\", \"%s\")", sLevel, g_eClients[client].iId_Client, sReason, name, steamid);
		}
		else
		{
			if(g_bMySQL)
				Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", \"0\", \"%s\", CURRENT_TIMESTAMP, \"Console\", \"0\")", sLevel, sReason);
			else
				Format(sQuery, sizeof(sQuery), "INSERT INTO store_plugin_logs (level, player_id, reason, date, name, steam) VALUES(\"%s\", \"0\", \"%s\", CURRENT_TIMESTAMP, \"Console\", \"0\")", sLevel, sReason);
		}
		SQL_TQuery(g_hDatabase, SQLCallback_Void_Error, sQuery);
	}
	else if(g_eCvars[g_cvarPluginsLogging].aCache == 1)
	{
		LogToOpenFileEx(g_hLogFile, "%s - %L - %s", sLevel, client, sReason); //WriteFileLine(g_hLogFile, "%s - %L - %s", sLevel, client, sReason); //todo dont work
	}
}

//////////////////////////////
//			TIMERS	 		//
//////////////////////////////
public int GetMultipliedCredits(int client,int amount)
{
	int flags = GetUserFlagBits(client);
	int size = GetArraySize(g_hCustomCredits);
	float multiplier = 1.0;
	for(int i=0;i<size;++i)
	{
		if(GetClientPrivilege(client, GetArrayCell(g_hCustomCredits, i, 0), flags))
		{
			float mul = GetArrayCell(g_hCustomCredits, i, 1);

			if(multiplier < mul)
				multiplier = mul;
		}
	}

	return RoundFloat(amount * multiplier);
}

public Action Timer_CreditTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	int m_iCredits;

	//if(2<=GetClientTeam(client)<=3)
	int team = GetClientTeam(client);
	if(2<=team<=3)
		m_iCredits = g_eCvars[g_cvarCreditAmountActive].aCache;
	else
		m_iCredits = g_eCvars[g_cvarCreditAmountInactive].aCache;
		
	m_iCredits = GetMultipliedCredits(client, m_iCredits);

	if(m_iCredits)
	{
		g_eClients[client].iCredits += m_iCredits;
		if(g_eCvars[g_cvarCreditMessages].aCache)
		{
			//Chat(client, "%t", "Credits Earned For Playing", m_iCredits);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Credits Earned For Playing", m_iCredits);
		}
		Store_LogMessage(client, m_iCredits, "Earned for playing");
	}

	return Plugin_Continue;
}

//////////////////////////////
//			STOCKS			//
//////////////////////////////

public void Store_LoadClientInventory(int client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	char m_szQuery[256];
	char m_szAuthId[32];

	GetLegacyAuthString(client, STRING(m_szAuthId));
	if(m_szAuthId[0] == 0)
		return;

	Format(STRING(m_szQuery), "SELECT * FROM store_players WHERE `authid`=\"%s\"", m_szAuthId[8]);

	SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Credits, m_szQuery, g_eClients[client].iUserId);
}

public void Store_SaveClientInventory(int client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	// Player disconnected before his inventory was even fetched
	if(g_eClients[client].iCredits==-1 && g_eClients[client].iItems==-1)
		return;
	
	char m_szQuery[2048];
	char m_szType[32];
	char m_szUniqueId[PLATFORM_MAX_PATH];
	
	for(int i=0;i<g_eClients[client].iItems;++i)
	{
		strcopy(STRING(m_szType), g_eTypeHandlers[g_eItems[g_eClientItems[client][i].iUniqueId].iHandler].szType);
		strcopy(STRING(m_szUniqueId), g_eItems[g_eClientItems[client][i].iUniqueId].szUniqueId);
	
		if(!g_eClientItems[client][i].bSynced && !g_eClientItems[client][i].bDeleted)
		{
			g_eClientItems[client][i].bSynced = true;
			Format(STRING(m_szQuery), "INSERT INTO store_items (`player_id`, `type`, `unique_id`, `date_of_purchase`, `date_of_expiration`, `price_of_purchase`) VALUES(%d, \"%s\", \"%s\", %d, %d, %d)", g_eClients[client].iId_Client, m_szType, m_szUniqueId, g_eClientItems[client][i].iDateOfPurchase, g_eClientItems[client][i].iDateOfExpiration, g_eClientItems[client][i].iPriceOfPurchase);
			SQL_TVoid(g_hDatabase, m_szQuery);
		} else if(g_eClientItems[client][i].bSynced && g_eClientItems[client][i].bDeleted)
		{
			// Might have been synced already but ID wasn't acquired
			if(g_eClientItems[client][i].iId_Client_Item==-1)
				Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `player_id`=%d AND `type`=\"%s\" AND `unique_id`=\"%s\"", g_eClients[client].iId_Client, m_szType, m_szUniqueId);
			else
				Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `id`=%d", g_eClientItems[client][i].iId_Client_Item);
			SQL_TVoid(g_hDatabase, m_szQuery);
		}
	}
}

public void Store_SaveClientEquipment(int client)
{
	char m_szQuery[256];
	int m_iId;
	for(int i=0;i<STORE_MAX_HANDLERS;++i)
	{
		for(int a=0;a<STORE_MAX_SLOTS;++a)
		{
			m_iId = i*STORE_MAX_SLOTS+a;
			if(g_eClients[client].aEquipmentSynced[m_iId] == g_eClients[client].aEquipment[m_iId])
			{
				//PrintToConsole(client, "continue");
				continue;
			}
			else if(g_eClients[client].aEquipmentSynced[m_iId] != -2)
			{
				if(g_eClients[client].aEquipment[m_iId]==-1)
				{
					Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", 
											g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, a);
				}
				else Format(STRING(m_szQuery), "UPDATE store_equipment SET `unique_id`=\"%s\" WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", 
												g_eItems[g_eClients[client].aEquipment[m_iId]].szUniqueId, g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, a);
			}
			else Format(STRING(m_szQuery), "INSERT INTO store_equipment (`player_id`, `type`, `unique_id`, `slot`) VALUES(%d, \"%s\", \"%s\", %d)", 
											g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, g_eItems[g_eClients[client].aEquipment[m_iId]].szUniqueId, a);
	
			SQL_TVoid(g_hDatabase, m_szQuery);
			//PrintToConsole(client, m_szQuery);
			g_eClients[client].aEquipmentSynced[m_iId] = g_eClients[client].aEquipment[m_iId];
		}
	}
}

public void Store_SaveClientData(int client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	if((g_eClients[client].iCredits==-1 && g_eClients[client].iItems==-1) || !g_eClients[client].bLoaded)
		return;
	
	char m_szQuery[256];
	if(g_bMySQL)
		Format(STRING(m_szQuery), "UPDATE store_players SET `credits`=GREATEST(`credits`+%d,0), `date_of_last_join`=%d, `name`='%s' WHERE `id`=%d", g_eClients[client].iCredits-g_eClients[client].iOriginalCredits, g_eClients[client].iDateOfLastJoin, g_eClients[client].szNameEscaped, g_eClients[client].iId_Client);
	else
		Format(STRING(m_szQuery), "UPDATE store_players SET `credits`=MAX(`credits`+%d,0), `date_of_last_join`=%d, `name`='%s' WHERE `id`=%d", g_eClients[client].iCredits-g_eClients[client].iOriginalCredits, g_eClients[client].iDateOfLastJoin, g_eClients[client].szNameEscaped, g_eClients[client].iId_Client);

	g_eClients[client].iOriginalCredits = g_eClients[client].iCredits;

	SQL_TVoid(g_hDatabase, m_szQuery);
}

public void Store_DisconnectClient(int client)
{
	Store_LogMessage(client, g_eClients[client].iCredits, "Amount of credits when the player left");
	g_eClients[client].iCredits = -1;
	g_eClients[client].iOriginalCredits = -1;
	g_eClients[client].iItems = -1;
	g_eClients[client].bLoaded = false;
	if (g_eClients[client].hCreditTimer != null)
	{
		ClearTimer(g_eClients[client].hCreditTimer);
	}
}

int Store_GetItemId(char[] type, char[] uid,int start=-1)
{
	for(int i=start+1;i<g_iItems;++i)
		if(strcmp(g_eTypeHandlers[g_eItems[i].iHandler].szType, type)==0 && strcmp(g_eItems[i].szUniqueId, uid)==0 && g_eItems[i].iPrice >= 0)
			return i;
	return -1;
}

void Store_BuyItem(int client,int itemid,int plan=-1)
{
	if(Store_HasClientItem(client, itemid))
		return;
	
	int m_iPrice = 0;
	if(plan==-1)
	{
		m_iPrice = g_eItems[itemid].iPrice;
	}
	else
	{
		m_iPrice = g_ePlans[itemid][plan].iPrice_Plan;
	}
	
	if(g_eClients[client].iCredits<m_iPrice)
		return;
		
	int m_iId = g_eClients[client].iItems++;
	g_eClientItems[client][m_iId].iId_Client_Item = -1;
	g_eClientItems[client][m_iId].iUniqueId = itemid;
	g_eClientItems[client][m_iId].iDateOfPurchase = GetTime();
	g_eClientItems[client][m_iId].iDateOfExpiration = (plan==-1?0:(g_ePlans[itemid][plan].iTime_Plan?GetTime()+g_ePlans[itemid][plan].iTime_Plan:0));
	g_eClientItems[client][m_iId].iPriceOfPurchase = m_iPrice;
	g_eClientItems[client][m_iId].bSynced = false;
	g_eClientItems[client][m_iId].bDeleted = false;
	
	g_eClients[client].iCredits -= m_iPrice;

	Store_LogMessage(client, -g_eItems[itemid].iPrice, "Bought a %s %s", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	Store_SQLLogMessage(client, LOG_EVENT, "Bought a %s %s.", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	//Chat(client, "%t", "Chat Bought Item", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Chat Bought Item", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
}

public void Store_SellItem(int client,int itemid)
{
	int m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, itemid)*view_as<float>(g_eCvars[g_cvarSellRatio].aCache));
	int uid = Store_GetClientItemId(client, itemid);
	//char m_szQuery[1024];
	
	if(g_eClientItems[client][uid].iDateOfExpiration != 0)
	{
		int m_iLength = g_eClientItems[client][uid].iDateOfExpiration-g_eClientItems[client][uid].iDateOfPurchase;
		int m_iLeft = g_eClientItems[client][uid].iDateOfExpiration-GetTime();
		if(m_iLeft<0)
			m_iLeft = 0;
		m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
	}

	g_eClients[client].iCredits += m_iCredits;
	//Chat(client, "%t", "Chat Sold Item", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Chat Sold Item", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	
	Store_UnequipItem(client, itemid);
	
	Store_LogMessage(client, m_iCredits, "Sold a %s %s", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	Store_SQLLogMessage(client, LOG_EVENT, "Sold a %s %s", g_eItems[itemid].szName, g_eTypeHandlers[g_eItems[itemid].iHandler].szType);
	
	Store_RemoveItem(client, itemid);
	
	//Remove the item from equipment to free memories
	//Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", 
	//										g_eClients[client].iId_Client, g_eTypeHandlers[i].szType, a);
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
}

public void Store_GiftItem(int client,int receiver,int item)
{
	int m_iId = g_eClientItems[client][item].iUniqueId;
	int target = g_iMenuClient[client];
	g_eClientItems[client][item].bDeleted = true;
	Store_UnequipItem(client, m_iId);

	g_eClientItems[receiver][g_eClients[receiver].iItems].iId_Client_Item = -1;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iUniqueId = m_iId;
	g_eClientItems[receiver][g_eClients[receiver].iItems].bSynced = false;
	g_eClientItems[receiver][g_eClients[receiver].iItems].bDeleted = false;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iDateOfPurchase = g_eClientItems[target][item].iDateOfPurchase;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iDateOfExpiration = g_eClientItems[target][item].iDateOfExpiration;
	g_eClientItems[receiver][g_eClients[receiver].iItems].iPriceOfPurchase = g_eClientItems[target][item].iPriceOfPurchase;
	
	++g_eClients[receiver].iItems;

	//Chat(client, "%t", "Chat Gift Item Sent", g_eClients[receiver].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Chat Gift Item Sent", g_eClients[receiver].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
	//Chat(receiver, "%t", "Chat Gift Item Received", g_eClients[target].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
	CPrintToChat(receiver, "%s%t", g_sChatPrefix, "Chat Gift Item Received", g_eClients[target].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
	
	Store_SQLLogMessage(0, LOG_EVENT, "%s gift %s (%s) to %s", g_eClients[target].szName_Client, g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType, g_eClients[receiver].szName_Client);

	Store_LogMessage(client, 0, "Gifted a %s to %N", g_eItems[m_iId].szName, receiver);
}

public int Store_GetClientItemId(int client,int itemid)
{
	for(int i=0;i<g_eClients[client].iItems;++i)
	{
		if(g_eClientItems[client][i].iUniqueId == itemid && !g_eClientItems[client][i].bDeleted)
			return i;
	}
		
	return -1;
}

public Handle Store_CreditTimer(int client)
{
	return CreateTimer(g_eCvars[g_cvarCreditTimer].aCache, Timer_CreditTimer, g_eClients[client].iUserId, TIMER_REPEAT);
}

public void FakeMenuHandler_StoreReloadConfig(Handle menu, MenuAction action, int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			if(!g_eCvars[gc_iReloadType].aCache)
			{
				if(ReloadTimer != INVALID_HANDLE)
				{
					//Chat(client, "%t", "Admin chat reload timer exist");
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Admin chat reload timer exist");
				}
				else
				{
					hTime = view_as<int>(g_eCvars[gc_iReloadDelay].aCache);
					ReloadTimer = CreateTimer(1.0, Timer_ReloadConfig);
				}
			}
			else
			{
				Store_ReloadConfig();
				//Chat(client, "%s", "Config reloaded. Please restart or change map");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Config reloaded. Please restart or change map");
			}
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

public Action Timer_ReloadConfig(Handle timer, DataPack pack)
{
	char map[128];
	GetCurrentMap(map, 128);
	
	if(hTime > 0)
	{
		if(g_eCvars[gc_iReloadNotify].aCache)
		{
			//CPrintToChatAll("%t" , "Timer_Server_ReloadConfig", time);
			ChatAll("%t" , "Timer_Server_ReloadConfig", hTime);
			CPrintToChatAll("%s%t", g_sChatPrefix, "Timer_Server_ReloadConfig", hTime);
		}
		--hTime;
		ReloadTimer = CreateTimer(1.0, Timer_ReloadConfig);
	}
	else 
	{
		Store_ReloadConfig();
		ServerCommand("sm_map %s", map);
	}
	
	return Plugin_Continue;
}

public int Store_GetTypeHandler(char[] type)
{
	for(int i=0;i<g_iTypeHandlers;++i)
	{
		if(strcmp(g_eTypeHandlers[i].szType, type)==0)
			return i;
	}
	return -1;
}

public int Store_GetMenuHandler(char[] id)
{
	for(int i=0;i<g_iMenuHandlers;++i)
	{
		if(strcmp(g_eMenuHandlers[i].szIdentifier, id)==0)
			return i;
	}
	return -1;
}

public bool Store_IsEquipped(int client,int itemid)
{
	for(int i=0;i<STORE_MAX_SLOTS;++i)
		if(g_eClients[client].aEquipment[g_eItems[itemid].iHandler*STORE_MAX_SLOTS+i] == itemid)
			return true;
	return false;
}

public int Store_GetExpiration(int client,int itemid)
{
	int uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;
	return g_eClientItems[client][uid].iDateOfExpiration;
}

int Store_UseItem(int client,int itemid, bool synced=false,int slot=0)
{
	int m_iSlot = slot;
	if(g_eTypeHandlers[g_eItems[itemid].iHandler].fnUse != INVALID_FUNCTION)
	{
		int m_iReturn = -1;
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid].iHandler].hPlugin, g_eTypeHandlers[g_eItems[itemid].iHandler].fnUse);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(m_iReturn);
		
		if(m_iReturn != -1)
			m_iSlot = m_iReturn;
	}

	if(g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
	{
		g_eClients[client].aEquipment[g_eItems[itemid].iHandler*STORE_MAX_SLOTS+m_iSlot]=itemid;
		if(synced)
			g_eClients[client].aEquipmentSynced[g_eItems[itemid].iHandler*STORE_MAX_SLOTS+m_iSlot]=itemid;
	}
	else if(m_iSlot == 0)
	{
		Store_RemoveItem(client, itemid);
		return 1;
	}
	
	//Store_SaveClientData(client);
	//Store_SaveClientInventory(client);
	//Store_SaveClientEquipment(client);
	
	return 0;
}

void Store_UnequipItem(int client,int itemid, bool fn=true)
{
	int m_iSlot = 0;
	if(fn && itemid > 0 && g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove != INVALID_FUNCTION)
	{
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid].iHandler].hPlugin, g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(m_iSlot);
	}

	int m_iId;
	if(g_eItems[itemid].iHandler != g_iPackageHandler)
	{
		m_iId = g_eItems[itemid].iHandler*STORE_MAX_SLOTS+m_iSlot;
		if(g_eClients[client].aEquipmentSynced[m_iId]==-2)
			g_eClients[client].aEquipment[m_iId]=-2;
		else
			g_eClients[client].aEquipment[m_iId]=-1;
	}
	else
	{
		for(int i=0;i<STORE_MAX_HANDLERS;++i)
		{
			for(int a=0;i<STORE_MAX_SLOTS;++i)
			{
				if(g_eClients[client].aEquipment[i+a] < 0)
					continue;
				m_iId = i*STORE_MAX_SLOTS+a;
				if(Store_IsItemInBoughtPackage(client, g_eClients[client].aEquipment[m_iId], itemid))
					if(g_eClients[client].aEquipmentSynced[m_iId]==-2)
						g_eClients[client].aEquipment[m_iId]=-2;
					else
						g_eClients[client].aEquipment[m_iId]=-1;
			}
		}
	}
	
	//Store_SaveClientData(client);
	//Store_SaveClientInventory(client);
	//Store_SaveClientEquipment(client);
}

int Store_GetEquippedItemFromHandler(int client,any handler,int slot=0)
{
	return g_eClients[client].aEquipment[handler*STORE_MAX_SLOTS+slot];
}

bool Store_PackageHasClientItem(int client,int packageid, bool invmode=false)
{
	int m_iFlags = GetUserFlagBits(client);
	if(!g_eCvars[g_cvarShowVIP].aCache && !GetClientPrivilege(client, g_eItems[packageid].iFlagBits, m_iFlags))
		return false;
		
	if(!g_eCvars[g_cvarShowSTEAM].aCache && !CheckSteamAuth(client, g_eItems[packageid].szSteam))
		return false;
	for(int i=0;i<g_iItems;++i)
		if(g_eItems[i].iParent == packageid && (g_eCvars[g_cvarShowVIP].aCache || GetClientPrivilege(client, g_eItems[i].iFlagBits, m_iFlags)) && (g_eCvars[g_cvarShowSTEAM].aCache || CheckSteamAuth(client, g_eItems[i].szSteam)) && (invmode && Store_HasClientItem(client, i) || !invmode))
			if((g_eItems[i].iHandler == g_iPackageHandler && Store_PackageHasClientItem(client, i, invmode)) || g_eItems[i].iHandler != g_iPackageHandler)
				return true;
	return false;
}

void Store_LogMessage(int client,int credits, const char[] message,any ...)
{
	if(!g_eCvars[g_cvarLogging].aCache)
		return;

	char m_szReason[256];
	VFormat(STRING(m_szReason), message, 4);

	if(g_eCvars[g_cvarLogging].aCache == 1)
	{
		LogToOpenFileEx(g_hLogFile, "%N's credits have changed by %d. Reason: %s", client, credits, m_szReason);
	} else if(g_eCvars[g_cvarLogging].aCache == 2)
	{
		char m_szQuery[256];
		Format(STRING(m_szQuery), "INSERT INTO store_logs (player_id, credits, reason, date) VALUES(%d, %d, \"%s\", CURRENT_TIMESTAMP)", g_eClients[client].iId_Client, credits, m_szReason);
		SQL_TVoid(g_hDatabase, m_szQuery);
	}
}

int Store_GetLowestPrice(int itemid)
{
	if(g_eItems[itemid].iPlans==0)
		return g_eItems[itemid].iPrice;

	int m_iLowest=g_ePlans[itemid][0].iPrice_Plan;
	for(int i=1;i<g_eItems[itemid].iPlans;++i)
	{
		if(m_iLowest>g_ePlans[itemid][i].iPrice_Plan)
			m_iLowest = g_ePlans[itemid][i].iPrice_Plan;
	}
	return m_iLowest;
}

int Store_GetHighestPrice(int itemid)
{
	if(g_eItems[itemid].iPlans==0)
		return g_eItems[itemid].iPrice;

	int m_iHighest=g_ePlans[itemid][0].iPrice_Plan;
	for(int i=1;i<g_eItems[itemid].iPlans;++i)
	{
		if(m_iHighest<g_ePlans[itemid][i].iPrice_Plan)
			m_iHighest = g_ePlans[itemid][i].iPrice_Plan;
	}
	return m_iHighest;
}

int Store_GetClientItemPrice(int client,int itemid)
{
	int uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;
		
	if(g_eClientItems[client][uid].iPriceOfPurchase==0)
		return g_eItems[itemid].iPrice;

	return g_eClientItems[client][uid].iPriceOfPurchase;
}

public void Store_OnPaymentReceived(any FriendID,any quanity, Handle data)
{
	LoopIngamePlayers(i)
	{
		if(GetFriendID(i)==FriendID)
		{
			Store_SaveClientData(i);

			any m_unMod = FriendID % 2;
			any m_unAccountID = (FriendID-m_unMod)/2;

			char m_szQuery[256];
			Format(STRING(m_szQuery), "SELECT * FROM store_players WHERE `authid`=\"%d:%d\"", m_unMod, m_unAccountID);
			SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Credits, m_szQuery, GetClientUserId(i));
			break;
		}
	}
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

stock void AdminGiveCredits(int client, int m_iCredits)
{
	g_eClients[client].iCredits += m_iCredits;
	if(g_eCvars[g_cvarSilent].aCache == 1)
	{
		if(client)
		{
			//Chat(client, "%t", "Credits Given", g_eClients[client].szName_Client, m_iCredits);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Credits Given", g_eClients[client].szName_Client, m_iCredits);
		}
		else
			ReplyToCommand(client, "%t", "Credits Given", g_eClients[client].szName_Client, m_iCredits);
		//Chat(client, "%t", "Credits Given", g_eClients[client].szName_Client, m_iCredits);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Credits Given", g_eClients[client].szName_Client, m_iCredits);
	}
	else if(g_eCvars[g_cvarSilent].aCache == 0)
	{
		//ChatAll("%t", "Credits Given", g_eClients[client].szName_Client, m_iCredits);
		CPrintToChatAll("%s%t", g_sChatPrefix, "Credits Given", g_eClients[client].szName_Client, m_iCredits);
	}
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
}