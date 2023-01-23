public void DisplayPreviewMenu(int client, int itemid)
{
	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];
	int m_iFlags = GetUserFlagBits(target);
	Handle m_hMenu = CreateMenu(MenuHandler_Item);
	Menu menu = new Menu(MenuHandler_Preview);
	menu.ExitBackButton = true;
	
	bool m_bEquipped = Store_IsEquipped(target, itemid);

	if(g_eCvars[gc_iDescription].aCache > 1)
	{
		menu.SetTitle("%s\n%s\n%t", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
	}
	else
	{
		menu.SetTitle("%s\n%t", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);
	}

	char sBuffer[128];

	if (Store_HasClientItem(client, itemid))
	{
		if(g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
		if(!m_bEquipped)
			AddMenuItemEx(m_hMenu, GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "0", "%t", "Item Equip");
		else
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "3", "%t", "Item Unequip");
		else
		AddMenuItemEx(m_hMenu, GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "0", "%t", "Item Use");
	}
	// Player don't own the item
	else if (!g_bInvMode[client] && !Store_HasClientItem(target, itemid))
	{
		//new String:m_szId[64];
		//new m_iId = StringToInt(m_szId);
					
		int iStyle = ITEMDRAW_DEFAULT;
		//if ((g_eClients[target][iCredits]<g_eItems[itemid][iPrice]) && !GetClientPrivilege(target, g_eItems[itemid][iFlagBits], m_iFlags) || !CheckSteamAuth(target, g_eItems[itemid][szSteam]))
		if (g_eClients[target].iCredits<g_eItems[itemid].iPrice)
		{
			iStyle = ITEMDRAW_DISABLED;
		}
		
		if(!GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags))
		{
			iStyle = ITEMDRAW_DISABLED;
		}
		
		if(!CheckSteamAuth(target, g_eItems[itemid].szSteam))
		{
			iStyle = ITEMDRAW_DISABLED;
		}

		// Player can buy the item as normal trade in
		/*
		if (g_eItems[itemid][iPlans]==0)
		{
			if (!GetClientPrivilege(target, g_eItems[itemid][iFlagBits], m_iFlags) || !CheckSteamAuth(target, g_eItems[itemid][szSteam]))
			{
				Format(sBuffer, sizeof(sBuffer), "%t %t", "Buy Item", price, reduced ? "discount" : "nodiscount");
				menu.AddItem("buy_item", sBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t %t", "Buy Item", price, reduced ? "discount" : "nodiscount");
				menu.AddItem("buy_item", sBuffer, ITEMDRAW_DISABLED);
			}
		}
		*/
		
		if (g_eItems[itemid].iPlans==0)
		{
			if (!GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) || !CheckSteamAuth(target, g_eItems[itemid].szSteam) || !g_eItems[itemid].bBuyable)
			{
				iStyle = ITEMDRAW_DISABLED;
			}
			Format(sBuffer, sizeof(sBuffer), "%t", "Buy Item", g_eItems[itemid].iPrice);
			menu.AddItem("buy_item", sBuffer, iStyle);
		}
		// Player can buy the item in a plan
		else
		{
			//Format(sBuffer, sizeof(sBuffer), "%t", "Choose Plan", g_eItems[itemid][szName]);
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Plan Available", g_eItems[itemid].szName);
			menu.AddItem("item_plan", sBuffer, iStyle);
		}
	}

	Format(sBuffer, sizeof(sBuffer), "%t", "Preview Item");
	menu.AddItem("preview_item", sBuffer, ITEMDRAW_DEFAULT);
	
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
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Preview(Menu menu, MenuAction action, int client, int param2)
{
	char m_szId[64];
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		char sId[24];
		menu.GetItem(param2, sId, sizeof(sId));
		int itemid = g_iSelectedItem[client];

		if (strcmp(sId, "buy_item") == 0)
		{
			if (g_eCvars[g_cvarConfirmation].aCache)
			{
				char sTitle[128];
				//g_eItems[g_iSelectedItem[client]][szName], g_eTypeHandlers[g_eItems[g_iSelectedItem[client]][iHandler]][szType]
				Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType);
				Store_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
				return 0;
			}
			else
			{
				Store_BuyItem(client, g_iSelectedItem[client], itemid);
				//BuyItem(client, itemid);
				DisplayPreviewMenu(client, itemid);
			}
		}
		else if (strcmp(sId, "item_plan") == 0)
		{
			DisplayPlanMenu(client, itemid);
		}
		else if (strcmp(sId, "item_use") == 0)
		{
			any bRet = Store_UseItem(client, g_iSelectedItem[client]);
			if (GetClientMenu(client) == MenuSource_None && bRet)
			{
				//g_eTypeHandlers[g_eItems[itemid][iHandler]][bEquipable]
				if (g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
				{
					if (g_eItems[g_iSelectedItem[client]].bPreview)
					{
						DisplayPreviewMenu(client, g_iSelectedItem[client]);
					}
					else
					{
						DisplayItemMenu(client, g_iSelectedItem[client]);
					}
				}
			}
		}
		else if (strcmp(sId, "item_unequipped") == 0)
		{
			Store_UnequipItem(client, itemid);
			if (g_eTypeHandlers[g_eItems[itemid].iHandler].bEquipable)
			{
				DisplayPreviewMenu(client, g_iSelectedItem[client]);
			}
			else
			{
				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
		}
		else if (strcmp(sId, "preview_item") == 0)
		{
			//if (g_iSpam[client] > GetTime())
			//{
			//	CPrintToChat(client, "%s%t", " {yellow}♛ J1BroS Store ♛ {default}", "Spam Cooldown", g_iSpam[client] - GetTime());
			//	DisplayPreviewMenu(client, itemid);
			//	return;
			//}

			if (!IsPlayerAlive(client))
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
				DisplayPreviewMenu(client, itemid);
				return 0;
			}
			if (g_eCvars[g_cvarPreview].aCache)
			{
				Store_Forward_PreviewForward(client, g_eTypeHandlers[g_eItems[itemid].iHandler].szType, g_eItems[itemid].iData);
				DisplayPreviewMenu(client, itemid);
			//g_iSpam[client] = GetTime() + 10;
			}
			else
			{
				CPrintToChat(client, "%s%s", g_sChatPrefix, " Preview disabled");
				DisplayPreviewMenu(client, itemid);
			}
		}
		else /*if (!(48 <= sId[0] <= 57))
		{
			bool ret;
			for (int i = 0; i < g_iItemHandlers; i++)
			{
				Call_StartFunction(g_hItemPlugin[i], g_fnItemHandler[i]);
				Call_PushCell(client);
				Call_PushString(sId);
				Call_PushCell(g_iSelectedItem[client]);
				Call_Finish(ret);

				if (ret)
					break;
			}
		}*/
		if(!(48 <= m_szId[0] <= 57))
			{
				any ret;
				for(int i=0;i<g_iMenuHandlers;++i)
				{
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnHandler);
					Call_PushCell(client);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	
	return 0;
}