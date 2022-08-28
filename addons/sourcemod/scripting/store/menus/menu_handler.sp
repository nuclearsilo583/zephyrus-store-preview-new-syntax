public int MenuHandler_Gift(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		int m_iItem, m_iReceiver;
		int target = g_iMenuClient[client];
	
		// Confirmation was given
		if(menu == INVALID_HANDLE)
		{
			m_iItem = Store_GetClientItemId(target, g_iSelectedItem[client]);
			m_iReceiver = GetClientOfUserId(param2);
			if(!m_iReceiver)
			{
				//Chat(client, "%t", "Gift Player Left");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Gift Player Left");
				return 0;
			}
			Store_GiftItem(target, m_iReceiver, m_iItem);
			g_iMenuNum[client] = 1;
			Store_DisplayPreviousMenu(client);
		}
		else
		{
			char m_szId[11];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			int m_iId = StringToInt(m_szId);
			m_iReceiver = GetClientOfUserId(m_iId);
			if(!m_iReceiver)
			{
				//Chat(client, "%t", "Gift Player Left");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Gift Player Left");
				return 0;
			}
				
			m_iItem = Store_GetClientItemId(target, g_iSelectedItem[client]);
			
			if(g_eCvars[g_cvarConfirmation].aCache)
			{
				char m_szTitle[128];
				Format(STRING(m_szTitle), "%t", "Confirm_Gift", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, g_eClients[m_iReceiver].szName_Client);
				Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Gift, m_iId);
				return 0;
			}
			else
				Store_GiftItem(target, m_iReceiver, m_iItem);
			Store_DisplayPreviousMenu(client);
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			DisplayItemMenu(client, g_iSelectedItem[client]);
			
	return 0;
}

public int MenuHandler_Confirm(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		if (param2 == 0)
		{
			char sCallback[32];
			char sData[11];
			GetMenuItem(menu, 0, sCallback, sizeof(sCallback));
			GetMenuItem(menu, 1, sData, sizeof(sData));

			DataPack pack = view_as<DataPack>(StringToInt(sCallback));
			Handle m_hPlugin = view_as<Handle>(pack.ReadCell());
			Function fnMenuCallback = pack.ReadCell();
			delete pack;

			if (fnMenuCallback != INVALID_FUNCTION)
			{
				Call_StartFunction(m_hPlugin, fnMenuCallback);
				Call_PushCell(INVALID_HANDLE);
				Call_PushCell(MenuAction_Select);
				Call_PushCell(client);
				Call_PushCell(StringToInt(sData));
				Call_Finish();
			}
			else
			{
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	
	return 0;
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

public void FakeMenuHandler_StoreResetLoadout(Handle menu, MenuAction action, int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			Store_Player_ResetLoadout(client);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Client Loadout Reset");
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}