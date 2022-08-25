void Store_Natives_OnNativeInit()
{
	CreateNative("Store_RegisterHandler", Native_RegisterHandler);
	CreateNative("Store_RegisterMenuHandler", Native_RegisterMenuHandler);
	CreateNative("Store_SetDataIndex", Native_SetDataIndex);
	CreateNative("Store_GetDataIndex", Native_GetDataIndex);
	CreateNative("Store_GetEquippedItem", Native_GetEquippedItem);
	CreateNative("Store_IsClientLoaded", Native_IsClientLoaded);
	CreateNative("Store_DisplayPreviousMenu", Native_DisplayPreviousMenu);
	CreateNative("Store_SetClientMenu", Native_SetClientMenu);
	CreateNative("Store_GetClientCredits", Native_GetClientCredits);
	CreateNative("Store_SetClientCredits", Native_SetClientCredits);
	CreateNative("Store_IsClientVIP", Native_IsClientVIP);
	CreateNative("Store_IsItemInBoughtPackage", Native_IsItemInBoughtPackage);
	CreateNative("Store_DisplayConfirmMenu", Native_DisplayConfirmMenu);
	CreateNative("Store_ShouldConfirm", Native_ShouldConfirm);
	CreateNative("Store_GetItem", Native_GetItem);
	CreateNative("Store_GetHandler", Native_GetHandler);
	CreateNative("Store_GiveItem", Native_GiveItem);
	CreateNative("Store_GetItemIdbyUniqueId", Native_GetItemIdbyUniqueId);
	CreateNative("Store_RemoveItem", Native_RemoveItem);
	CreateNative("Store_GetClientItem", Native_GetClientItem);
	CreateNative("Store_GetClientTarget", Native_GetClientTarget);
	CreateNative("Store_GiveClientItem", Native_GiveClientItem);
	CreateNative("Store_HasClientItem", Native_HasClientItem);
	CreateNative("Store_IterateEquippedItems", Native_IterateEquippedItems);
	CreateNative("Store_IsInRecurringMenu", Native_IsInRecurringMenu);
	CreateNative("Store_SetClientRecurringMenu", Native_SetClientRecurringMenu);
	
	CreateNative("Store_GetPlansPrice", Native_GetPlansPrice);
	
	CreateNative("Store_GetStoreItemsCount", Native_GetStoreItemsCount);
	
	CreateNative("Store_SQLEscape", Native_SQLEscape);
	CreateNative("Store_SQLQuery", Native_SQLQuery);
	CreateNative("Store_SQLLogMessage", Native_LogMessage);	
	CreateNative("Store_SQLTransaction", Native_SQLTransaction);	
}

//////////////////////////////
//			NATIVES			//
//////////////////////////////

public int Native_GetStoreItemsCount(Handle plugin,int numParams)
{
	return g_iItems;
}

public int Native_GetPlansPrice(Handle plugin,int numParams)
{
	int itemid = GetNativeCell(1);
	int highest = GetNativeCell(2);
	
	return highest ? Store_GetHighestPrice(itemid) : Store_GetLowestPrice(itemid);
}

public int Native_RegisterHandler(Handle plugin,int numParams)
{
	if(g_iTypeHandlers == STORE_MAX_HANDLERS)
		return -1;
		
	char m_szType[32];
	GetNativeString(1, STRING(m_szType));
	int m_iHandler = Store_GetTypeHandler(m_szType);	
	int m_iId = g_iTypeHandlers;
	
	if(m_iHandler != -1)
		m_iId = m_iHandler;
	else
		++g_iTypeHandlers;
	
	g_eTypeHandlers[m_iId].hPlugin = plugin;
	g_eTypeHandlers[m_iId].fnMapStart = GetNativeCell(3);
	g_eTypeHandlers[m_iId].fnReset = GetNativeCell(4);
	g_eTypeHandlers[m_iId].fnConfig = GetNativeCell(5);
	g_eTypeHandlers[m_iId].fnUse = GetNativeCell(6);
	g_eTypeHandlers[m_iId].fnRemove = GetNativeCell(7);
	g_eTypeHandlers[m_iId].bEquipable = GetNativeCell(8);
	g_eTypeHandlers[m_iId].bRaw = GetNativeCell(9);
	//strcopy(g_eTypeHandlers[m_iId][szType], 32, m_szType);
	strcopy(g_eTypeHandlers[m_iId].szType, sizeof(Type_Handler::szType), m_szType);
	//GetNativeString(2, g_eTypeHandlers[m_iId].szUniqueKey, 32);
	GetNativeString(2, g_eTypeHandlers[m_iId].szUniqueKey, sizeof(Type_Handler::szUniqueKey));

	return m_iId;
}

public int Native_RegisterMenuHandler(Handle plugin,int numParams)
{
	if(g_iMenuHandlers == STORE_MAX_HANDLERS)
		return -1;
		
	char m_szIdentifier[64];
	GetNativeString(1, STRING(m_szIdentifier));
	int m_iHandler = Store_GetMenuHandler(m_szIdentifier);	
	int m_iId = g_iMenuHandlers;
	
	if(m_iHandler != -1)
		m_iId = m_iHandler;
	else
		++g_iMenuHandlers;
	
	g_eMenuHandlers[m_iId].hPlugin_Handler = plugin;
	g_eMenuHandlers[m_iId].fnMenu = GetNativeCell(2);
	g_eMenuHandlers[m_iId].fnHandler = GetNativeCell(3);
	strcopy(g_eMenuHandlers[m_iId].szIdentifier, sizeof(Menu_Handler::szIdentifier), m_szIdentifier);

	return m_iId;
}

public int Native_IsInRecurringMenu(Handle plugin, int numParams)
{
	return g_bIsInRecurringMenu[GetNativeCell(1)];
}

public int Native_SetClientRecurringMenu(Handle plugin, int numParams)
{
	g_bIsInRecurringMenu[GetNativeCell(1)] = view_as<bool>(GetNativeCell(2));
	
	return 0;
}

public any Native_SetDataIndex(Handle plugin,int numParams)
{
	g_eItems[GetNativeCell(1)].iData = GetNativeCell(2);
	
	return 0;
}

public any Native_GetDataIndex(Handle plugin,int numParams)
{
	return g_eItems[GetNativeCell(1)].iData;
}

public any Native_GetEquippedItem(Handle plugin,int numParams)
{
	char m_szType[16];
	GetNativeString(2, STRING(m_szType));
	
	int m_iHandler = Store_GetTypeHandler(m_szType);
	if(m_iHandler == -1)
		return -1;
	
	return Store_GetEquippedItemFromHandler(GetNativeCell(1), m_iHandler, GetNativeCell(3));
}

public any Native_IsClientLoaded(Handle plugin,int numParams)
{
	return g_eClients[GetNativeCell(1)].bLoaded;
}

public any Native_DisplayPreviousMenu(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	if(g_iMenuNum[client] == 1)
		DisplayStoreMenu(client, g_iMenuBack[client], g_iLastSelection[client]);
	else if(g_iMenuNum[client] == 2)
		DisplayItemMenu(client, g_iSelectedItem[client]);
	else if(g_iMenuNum[client] == 3)
		DisplayPlayerMenu(client);
	else if(g_iMenuNum[client] == 4)
		AdminMenu_ResetPlayer(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
	else if(g_iMenuNum[client] == 5)
		DisplayPlanMenu(client, g_iSelectedItem[client]);
	else if(g_iMenuNum[client] == 0)
		RedisplayAdminMenu(g_hAdminMenu, client);
		
	return 0;
}

public any Native_SetClientMenu(Handle plugin,int numParams)
{
	g_iMenuNum[GetNativeCell(1)] = GetNativeCell(2);
	
	return 0;
}

public any Native_GetClientCredits(Handle plugin,int numParams)
{
	return g_eClients[GetNativeCell(1)].iCredits;
}

public int Native_SetClientCredits(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int m_iCredits = GetNativeCell(2);
	Store_LogMessage(client, m_iCredits-g_eClients[client].iCredits, "Set by external plugin");
	g_eClients[client].iCredits = m_iCredits;
	Store_SaveClientData(client);
	return 1;
}

public any Native_IsClientVIP(Handle plugin,int numParams)
{
	return (g_eCvars[g_cvarVIPFlag].aCache != 0 && GetClientPrivilege(GetNativeCell(1), g_eCvars[g_cvarVIPFlag].aCache));
}

public int Native_IsItemInBoughtPackage(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	any uid = GetNativeCell(3);

	any m_iParent;
	if(itemid<0)
		m_iParent = g_eItems[itemid].iParent;
	else
		m_iParent = g_eItems[itemid].iParent;
		
	while(m_iParent != -1)
	{
		for(int i=0;i<g_eClients[client].iItems;++i)
			if(((uid == -1 && g_eClientItems[client][i].iUniqueId == m_iParent) || (uid != -1 && g_eClientItems[client][i].iUniqueId == uid)) && !g_eClientItems[client][i].bDeleted)
				return true;
		m_iParent = g_eItems[m_iParent].iParent;
	}
	return false;
}

public int Native_DisplayConfirmMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char sBuffer[255];
	GetNativeString(2, sBuffer, sizeof(sBuffer));

	//Zephyrus magic with pinch of kxnlr
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteCell(GetNativeCell(3));
	pack.Reset();

	char sCallback[32];
	char sData[11];
	IntToString(view_as<int>(pack), sCallback, sizeof(sCallback));
	IntToString(GetNativeCell(4), sData, sizeof(sData));

	//delete pack;
	Menu menu = new Menu(MenuHandler_Confirm);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Confirm_Yes");
	menu.AddItem(sCallback, sBuffer, ITEMDRAW_DEFAULT);

	Format(sBuffer, sizeof(sBuffer), "%t", "Confirm_No");
	menu.AddItem(sData, sBuffer, ITEMDRAW_DEFAULT);
	//Zephyrus magic

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return 0;
}

public int Native_ShouldConfirm(Handle plugin,int numParams)
{
	return g_eCvars[g_cvarConfirmation].aCache;
}

public int Native_GetItem(Handle plugin,int numParams)
{
	SetNativeArray(2, view_as<int>(g_eItems[GetNativeCell(1)]), sizeof(g_eItems[])); 
	
	return 0;
}

public int Native_GetItemIdbyUniqueId(Handle plugin, int numParams)
{
	char sUId[1024];
	GetNativeString(1, sUId, sizeof(sUId));

	for (int i = 0; i < g_iItems; i++)
	{
		if (StrEqual(sUId, g_eItems[i].szUniqueId))
			return i;
	}

	return -1;
}

public int Native_GetHandler(Handle plugin,int numParams)
{
	SetNativeArray(2, view_as<int>(g_eTypeHandlers[GetNativeCell(1)]), sizeof(g_eTypeHandlers[])); 
	
	return 0;
}

public int Native_GetClientItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);

	int uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;

	SetNativeArray(3, view_as<int>(g_eClientItems[client][uid]), sizeof(g_eClientItems[][])); 

	return 1;
}

public int Native_GiveItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int purchase = GetNativeCell(3);
	int expiration = GetNativeCell(4);
	int price = GetNativeCell(5);

	int m_iDateOfPurchase = (purchase==0?GetTime():purchase);
	int m_iDateOfExpiration = expiration;

	int m_iId = g_eClients[client].iItems++;
	g_eClientItems[client][m_iId].iId_Client_Item = -1;
	g_eClientItems[client][m_iId].iUniqueId = itemid;
	g_eClientItems[client][m_iId].iDateOfPurchase = m_iDateOfPurchase;
	g_eClientItems[client][m_iId].iDateOfExpiration = m_iDateOfExpiration;
	g_eClientItems[client][m_iId].iPriceOfPurchase = price;
	g_eClientItems[client][m_iId].bSynced = false;
	g_eClientItems[client][m_iId].bDeleted = false;
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
	
	return 0;
}

public int Native_RemoveItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	if(itemid>0 && g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove != INVALID_FUNCTION)
	{
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid].iHandler].hPlugin, g_eTypeHandlers[g_eItems[itemid].iHandler].fnRemove);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	
	Store_UnequipItem(client, itemid, false);
	
	int m_iId = Store_GetClientItemId(client, itemid);
	if(m_iId != -1)
		g_eClientItems[client][m_iId].bDeleted = true;
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
	
	return 0;
}

public int Native_GetClientTarget(Handle plugin,int numParams)
{
	return g_iMenuClient[GetNativeCell(1)];
}

public int Native_GiveClientItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int receiver = GetNativeCell(2);
	int itemid = GetNativeCell(3);

	int item = Store_GetClientItemId(client, itemid);
	if(item == -1)
		return 1;

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
	
	LoopIngamePlayers(i)
	{
		Store_SaveClientData(i);
		Store_SaveClientInventory(i);
		Store_SaveClientEquipment(i);
	}

	return 1;
}

public int Native_HasClientItem(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);

	// Can he even have it?	
	if(!GetClientPrivilege(client, g_eItems[itemid].iFlagBits) || !CheckSteamAuth(client, g_eItems[itemid].szSteam))
	{
		if (g_eItems[itemid].iPrice <= 0 && g_eItems[itemid].iPlans==0)
			return false;
			//if(g_eClientItems[client][i][iDateOfExpiration]==0 || (g_eClientItems[client][i][iDateOfExpiration] && GetTime()<g_eClientItems[client][i][iDateOfExpiration]))
		
		for(int i=0;i<g_eClients[client].iItems;++i)
		{	
			if(g_eClientItems[client][i].iUniqueId == itemid && !g_eClientItems[client][i].bDeleted)
				if(g_eClientItems[client][i].iDateOfExpiration==0 || (g_eClientItems[client][i].iDateOfExpiration && GetTime()<g_eClientItems[client][i].iDateOfExpiration))
					return true;
				else
					return false;
		}
	}

	// Is the item free (available for everyone)?
	if (g_eItems[itemid].iPrice <= 0 && g_eItems[itemid].iPlans==0)
		return true;
		
	// Is the client a VIP therefore has access to all the items already?
	if(Store_IsClientVIP(client) && !g_eItems[itemid].bIgnoreVIP && !g_eItems[itemid].bIgnoreFree)
		return true;
		
	// Check if the client actually has the item
	for(int i=0;i<g_eClients[client].iItems;++i)
	{
		if(g_eClientItems[client][i].iUniqueId == itemid && !g_eClientItems[client][i].bDeleted)
			if(g_eClientItems[client][i].iDateOfExpiration==0 || (g_eClientItems[client][i].iDateOfExpiration && GetTime()<g_eClientItems[client][i].iDateOfExpiration))
				return true;
			else
				return false;
	}
	
	// Check if the item is part of a group the client already has
	if(Store_IsItemInBoughtPackage(client, itemid))
		return true;
		
	return false;
}

public int Native_IterateEquippedItems(Handle plugin,int numParams)
{
	int client = GetNativeCell(1);
	int start = GetNativeCellRef(2);
	bool attributes = GetNativeCell(3);

	for(int i=start+1;i<STORE_MAX_HANDLERS*STORE_MAX_SLOTS;++i)
	{
		if(g_eClients[client].aEquipment[i] >= 0 && (attributes==false || (attributes && g_eItems[g_eClients[client].aEquipment[i]].hAttributes!=INVALID_HANDLE)))
		{
			SetNativeCellRef(2, i);
			return g_eClients[client].aEquipment[i];
		}
	}
		
	return -1;
}

public int Native_SQLEscape(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	char sBuffer[512], sBuffer2[512];
	GetNativeString(1, sBuffer, sizeof(sBuffer));

	SQL_EscapeString(g_hDatabase, sBuffer, sBuffer2, sizeof(sBuffer2));

	SetNativeString(1, sBuffer2, sizeof(sBuffer2));

	return 1;
}

public int Native_SQLQuery(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	char sQuery[512];
	GetNativeString(1, sQuery, sizeof(sQuery));
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));

	SQL_TQuery(g_hDatabase, Natives_SQLCallback, sQuery, pack);
	return 1;
}

public void Natives_SQLCallback(Handle owner, Handle results, const char[] error, DataPack pack)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	any data = pack.ReadCell();
	delete pack;

	Call_StartFunction(plugin, callback);
	Call_PushCell(owner);
	Call_PushCell(results);
	Call_PushString(error);
	Call_PushCell(data);
	Call_Finish();
}

public int Native_SQLTransaction(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	Transaction tnx = GetNativeCell(1);
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));

	SQL_ExecuteTransaction(g_hDatabase, tnx, Natives_SQLTXNCallback_Success, Natives_SQLTXNCallback_Error, pack);

	return 1;
}

public void Natives_SQLTXNCallback_Success(Database db, DataPack pack, int numQueries, Handle[] results, any[] queryData)
{
	PrintToServer("Store - Native Transaction Complete - Querys: %i", numQueries);

	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	any data = pack.ReadCell();
	delete pack;

	Call_StartFunction(plugin, callback);
	Call_PushCell(db);
	Call_PushCell(data);
	Call_PushCell(numQueries);
	Call_PushArray(results, numQueries);
	Call_PushArray(queryData, numQueries);
	Call_Finish();
}

public void Natives_SQLTXNCallback_Error(Database db, DataPack pack, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	delete pack;

	char sBuffer[64];
	GetPluginFilename(plugin, sBuffer, sizeof(sBuffer));

	StoreLogMessage(0, LOG_ERROR, "Natives_SQLTXNCallback_Error: %s - Plugin: %s Querys: %i - FailedIndex: %i", error, sBuffer, numQueries, failIndex);
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sBuffer[256];
	char sPlugin[256];
	int client = GetNativeCell(1);
	int level = GetNativeCell(2);
	GetNativeString(3, sBuffer, sizeof(sBuffer));
	FormatNativeString(0, 3, 4, sizeof(sBuffer), _, sBuffer);

	GetPluginFilename(plugin, sPlugin, sizeof(sPlugin));
	Format(sBuffer, sizeof(sBuffer), "Plugin: %s - %s", sPlugin, sBuffer);

	StoreLogMessage(client, level, sBuffer);
	
	return 0;
}

//////////////////////////////////////
//			END OF NATIVES			//
//////////////////////////////////////