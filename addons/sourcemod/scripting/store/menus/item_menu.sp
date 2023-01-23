public void DisplayItemMenu(int client,int itemid)
{
	g_iMenuNum[client] = 1;
	g_iMenuBack[client] = g_eItems[itemid].iParent;
	int target = g_iMenuClient[client];

	Handle m_hMenu = CreateMenu(MenuHandler_Item);
	SetMenuExitBackButton(m_hMenu, true);
	
	bool m_bEquipped = Store_IsEquipped(target, itemid);
	char m_szTitle[256];
	int idx = 0;
	if(m_bEquipped)
	{
		if (g_eCvars[gc_iDescription].aCache > 1)
		{
			idx = Format(STRING(m_szTitle), "%t\n%s\n%t", "Item Equipped", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
		}
		else idx = Format(STRING(m_szTitle), "%t\n%t", "Item Equipped", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);
	}
	else
	{
		if (g_eCvars[gc_iDescription].aCache > 1)
		{
			idx = Format(STRING(m_szTitle), "%s\n%s\n%t", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
		}
		else idx = Format(STRING(m_szTitle), "%s\n%t", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);
	}
	
	int m_iExpiration = Store_GetExpiration(target, itemid);
	if(m_iExpiration != 0)
	{
		m_iExpiration = m_iExpiration-GetTime();
		int m_iDays = m_iExpiration/(24*60*60);
		int m_iHours = (m_iExpiration-m_iDays*24*60*60)/(60*60);
		Format(m_szTitle[idx-1], sizeof(m_szTitle)-idx-1, "\n%t", "Title Expiration", m_iDays, m_iHours);
	}
	
	SetMenuTitle(m_hMenu, m_szTitle);
	
	if(g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
	{
		if(!m_bEquipped)
			AddMenuItemEx(m_hMenu, GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "0", "%t", "Item Equip");
		else
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "3", "%t", "Item Unequip");
	}
	else
	{
		AddMenuItemEx(m_hMenu, GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "0", "%t", "Item Use");
	}
	//
	if (g_eItems[itemid].bPreview)
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "4", "%t", "Preview Item");
		
	if(/*!Store_IsClientVIP(target) && */!Store_IsItemInBoughtPackage(target, itemid))
	{
		int m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, itemid)*view_as<float>(g_eCvars[g_cvarSellRatio].aCache));
		if(m_iCredits!=0)
		{
			int uid = Store_GetClientItemId(client, itemid);
			if(g_eClientItems[client][uid].iDateOfExpiration != 0)
			{
				int m_iLength = g_eClientItems[client][uid].iDateOfExpiration-g_eClientItems[client][uid].iDateOfPurchase;
				int m_iLeft = g_eClientItems[client][uid].iDateOfExpiration-GetTime();
				if(m_iLeft < 0)
					m_iLeft = 0;
				m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
			}

			if(g_eCvars[g_cvarSellEnabled].aCache)
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "1", "%t", "Item Sell", m_iCredits);
			if(g_eCvars[g_cvarGiftEnabled].aCache == 1 || (g_eCvars[g_cvarGiftEnabled].aCache == 2 && GetUserFlagBits(client) & g_eCvars[g_cvarAdminFlag].aCache))
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "2", "%t", "Item Gift");
		}
	}

	for(int i=0;i<g_iMenuHandlers;++i)
	{
		if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
			continue;
		Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnMenu);
		Call_PushCellRef(m_hMenu);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	
	DisplayMenu(m_hMenu, client, 0);
}

public int MenuHandler_Item(Handle menu, MenuAction action,int client,int param2)
{
		
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		int itemid = g_iSelectedItem[client];
		int target = g_iMenuClient[client];
		// Confirmation was sent
		if(menu == INVALID_HANDLE)
		{
			if(param2 == 0)
			{
				g_iMenuNum[client] = 1;
				Store_SellItem(target, g_iSelectedItem[client]);
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			char m_szId[64];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			int m_iId = StringToInt(m_szId);
			
			// Menu handlers
			if(!(48 <= m_szId[0] <= 57))
			{
				any ret;
				for(int i=0;i<g_iMenuHandlers;++i)
				{
					if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
						continue;
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnHandler);
					Call_PushCell(client);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
			// Player wants to equip this item
			else if(m_iId == 0)
			{
				int m_iRet = Store_UseItem(target, g_iSelectedItem[client]);
				if(GetClientMenu(client)==MenuSource_None && m_iRet == 0)
					DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			// Player wants to sell this item
			else if(m_iId == 1)
			{
				if(g_eCvars[g_cvarConfirmation].aCache)
				{
					int m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, g_iSelectedItem[client])*view_as<float>(g_eCvars[g_cvarSellRatio].aCache));
					int uid = Store_GetClientItemId(client, g_iSelectedItem[client]);
					if(g_eClientItems[client][uid].iDateOfExpiration != 0)
					{
						int m_iLength = g_eClientItems[client][uid].iDateOfExpiration-g_eClientItems[client][uid].iDateOfPurchase;
						int m_iLeft = g_eClientItems[client][uid].iDateOfExpiration-GetTime();
						if(m_iLeft < 0)
							m_iLeft = 0;
						m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
					}

					char m_szTitle[128];
					Format(STRING(m_szTitle), "%t", "Confirm_Sell", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, m_iCredits);
					g_iMenuNum[client] = 2;
					Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Item, 0);
				}
				else
				{
					Store_SellItem(target, g_iSelectedItem[client]);
					Store_DisplayPreviousMenu(client);
				}
			}
			// Player wants to gift this item
			else if(m_iId == 2)
			{
				g_iMenuNum[client] = 2;
				DisplayPlayerMenu(client);
			}
			// Player wants to unequip this item
			else if(m_iId == 3)
			{
				Store_UnequipItem(target, g_iSelectedItem[client]);
				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			else if(m_iId == 4)
			{
				if (g_eCvars[g_cvarPreview].aCache)
				{
					Store_Forward_PreviewForward(client, g_eTypeHandlers[g_eItems[itemid].iHandler].szType, g_eItems[itemid].iData);
					DisplayItemMenu(client, g_iSelectedItem[client]);
				}

				else
				{
					CPrintToChat(client, "%s%s", g_sChatPrefix, " Preview disabled");
					DisplayItemMenu(client, g_iSelectedItem[client]);
				}
			}
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
			
	return 0;
}