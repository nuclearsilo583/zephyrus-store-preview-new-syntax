public void DisplayPlanMenu(int client, int itemid)
{
	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];
	int m_iFlags = GetUserFlagBits(target);
	
	Menu menu = new Menu(MenuHandler_Plan);
	menu.ExitBackButton = true;

	if (g_eCvars[gc_iDescription].aCache > 1)
	{
		menu.SetTitle("%s\n%s\n%t", g_eItems[itemid].szName, g_eItems[itemid].szDescription, "Title Credits", g_eClients[target].iCredits);
	}
	else menu.SetTitle("%s\n%t", g_eItems[itemid].szName, "Title Credits", g_eClients[target].iCredits);

	char sBuffer[64];
	if (g_eItems[itemid].bPreview)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Preview Item");
		menu.AddItem("preview", sBuffer, ITEMDRAW_DEFAULT);
	}

	for (int i = 0; i < g_eItems[itemid].iPlans; ++i)
	{
		if(!CheckSteamAuth(target, g_eItems[itemid].szSteam))
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}
		else if (GetClientPrivilege(target, g_eItems[itemid].iFlagBits, m_iFlags) || g_eItems[itemid].szSteam[0])
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, (g_eClients[target].iCredits>=g_ePlans[itemid][i].iPrice_Plan)? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		else if (!g_eItems[itemid].bBuyable)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Available", g_ePlans[itemid][i].szName_Plan, g_ePlans[itemid][i].iPrice_Plan);
			menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
		}
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Plan(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];
		g_iMenuNum[client] = 5;

		char sId[24];
		menu.GetItem(param2, sId, sizeof(sId));
		int itemid = g_iSelectedItem[client];

		if (strcmp(sId, "preview") == 0)
		{
			//if (g_iSpam[client] < GetTime())
			//{
			if (g_eCvars[g_cvarPreview].aCache)
			{
				Store_Forward_PreviewForward(client, g_eTypeHandlers[g_eItems[itemid].iHandler].szType, g_eItems[itemid].iData);
				DisplayPlanMenu(client, itemid);
			}
				//g_iSpam[client] = GetTime() + 10;
			//}
			//else
			//{
			//	CPrintToChat(client, "%s%t", " {yellow}♛ J1BroS Store ♛ {default}", "Spam Cooldown", g_iSpam[client] - GetTime());
			//}
			else 
			{
				CPrintToChat(client, "%s%s", g_sChatPrefix, " Preview disabled");
				DisplayPlanMenu(client, itemid);
			}
			return 0;
		}

		g_iSelectedPlan[client] = param2;

		if (g_eItems[g_iSelectedItem[client]].bPreview)
		{
			g_iSelectedPlan[client]--;
		}

		if (g_eCvars[g_cvarConfirmation].aCache)
		{
			char sTitle[128];
			Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType);
			Store_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
		}
		else
		{
			Store_BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);
			DisplayItemMenu(client, g_iSelectedItem[client]);
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