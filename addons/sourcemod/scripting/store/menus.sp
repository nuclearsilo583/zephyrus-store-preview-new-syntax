#include "store/menus/menu_handler.sp"
#include "store/menus/search_menu.sp"
#include "store/menus/player_menu.sp"
#include "store/menus/item_menu.sp"
#include "store/menus/plan_menu.sp"
#include "store/menus/preview_menu.sp"

//////////////////////////////
//			MENUS	 		//
//////////////////////////////
void DisplayStoreMenu(int client,int parent=-1,int last=-1)
{
	if(!client || !IsClientInGame(client))
		return;

	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];

	Handle m_hMenu = CreateMenu(MenuHandler_Store);
	if(parent!=-1)
	{
		SetMenuExitBackButton(m_hMenu, true);
		if(client == target)
		{
			if (g_eCvars[gc_iDescription].aCache > 1)
			{
				SetMenuTitle(m_hMenu, "%s\n%s\n%t", g_eItems[parent].szName, g_eItems[parent].szDescription, "Title Credits", g_eClients[target].iCredits);
			}
			else SetMenuTitle(m_hMenu, "%s\n%t", g_eItems[parent].szName, "Title Credits", g_eClients[target].iCredits);
		}
		else
			SetMenuTitle(m_hMenu, "%N\n%s\n%t", target, g_eItems[parent].szName, "Title Credits", g_eClients[target].iCredits);
		g_iMenuBack[client] = g_eItems[parent].iParent;
	}
	else if(client == target)
		SetMenuTitle(m_hMenu, "%t\n%t", "Title Store", "Title Credits", g_eClients[target].iCredits);
	else
		SetMenuTitle(m_hMenu, "%N\n%t\n%t", target, "Title Store", "Title Credits", g_eClients[target].iCredits);
	
	char m_szId[11];
	int m_iFlags = GetUserFlagBits(target);
	int m_iPosition = 0;
	
	g_iSelectedItem[client] = parent;
	if(parent != -1)
	{
		if(g_eItems[parent].iPrice>0)
		{
			if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, parent))
			{
				if(g_eCvars[g_cvarSellEnabled].aCache)
				{
					AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "sell_package", "%t", "Package Sell", RoundToFloor(g_eItems[parent].iPrice*view_as<float>(g_eCvars[g_cvarSellRatio].aCache)));
					++m_iPosition;
				}
				if(g_eCvars[g_cvarGiftEnabled].aCache == 1 || (g_eCvars[g_cvarGiftEnabled].aCache == 2 && GetUserFlagBits(client) & g_eCvars[g_cvarAdminFlag].aCache))
				{
					AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "gift_package", "%t", "Package Gift");
					++m_iPosition;
				}

				for(int i=0;i<g_iMenuHandlers;++i)
				{
					if(g_eMenuHandlers[i].hPlugin_Handler == INVALID_HANDLE)
						continue;
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnMenu);
					Call_PushCellRef(m_hMenu);
					Call_PushCell(client);
					Call_PushCell(parent);
					Call_Finish();
				}
			}
		}
	}
	
	for(int i=0;i<g_iItems;++i)
	{
		if(g_eItems[i].iParent==parent && 
			(g_eCvars[g_cvarShowVIP].aCache == 0 && GetClientPrivilege(target, g_eItems[i].iFlagBits, m_iFlags) || g_eCvars[g_cvarShowVIP].aCache) &&
			(g_eCvars[g_cvarShowSTEAM].aCache == 0 && CheckSteamAuth(target, g_eItems[i].szSteam) || g_eCvars[g_cvarShowSTEAM].aCache))
		{
			int m_iPrice = Store_GetLowestPrice(i);
			//bool reduced = false;

			// This is a package
			if(g_eItems[i].iHandler == g_iPackageHandler)
			{
				if(!Store_PackageHasClientItem(target, i, g_bInvMode[client]))
					continue;

				int m_iStyle = ITEMDRAW_DEFAULT;

				char sBuffer[256];
				IntToString(i, STRING(m_szId));
				if(g_eItems[i].iPrice == -1 || Store_HasClientItem(target, i))
				{
					if (g_eCvars[gc_iDescription].aCache < 3)
					{
						Format(sBuffer, sizeof(sBuffer), "%s\n%s", g_eItems[i].szName, g_eItems[i].szDescription);
					}
					else Format(sBuffer, sizeof(sBuffer), "%s", g_eItems[i].szName);
					
					AddMenuItem(m_hMenu, m_szId, sBuffer, m_iStyle);

				}
				else if(!g_bInvMode[client] && g_eItems[i].iPlans==0 /*&& g_eItems[i][bBuyable]*/)
					InsertMenuItemEx(m_hMenu, m_iPosition, (m_iPrice<=g_eClients[target].iCredits?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), m_szId, "%t", "Item Available", g_eItems[i].szName, g_eItems[i].iPrice);
				else if(!g_bInvMode[client])
					InsertMenuItemEx(m_hMenu, m_iPosition, (m_iPrice<=g_eClients[target].iCredits?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), m_szId, "%t", "Item Plan Available", g_eItems[i].szName);
				++m_iPosition;
			}
			// This is a normal item
			else
			{
				IntToString(i, STRING(m_szId));
				if(Store_HasClientItem(target, i))
				{
					if(Store_IsEquipped(target, i))
						InsertMenuItemEx(m_hMenu, m_iPosition, ITEMDRAW_DEFAULT, m_szId, "%t", "Item Equipped", g_eItems[i].szName);
					else
						InsertMenuItemEx(m_hMenu, m_iPosition, ITEMDRAW_DEFAULT, m_szId, "%t", "Item Bought", g_eItems[i].szName);
				}
				else if(!g_bInvMode[client] /*&& g_eItems[i][bBuyable]*/)
				{				
					int m_iStyle = ITEMDRAW_DEFAULT;
					
					if((!g_eItems[i].bPreview) && (g_eCvars[g_cvarShowVIP].aCache && !GetClientPrivilege(target, g_eItems[i].iFlagBits, m_iFlags) || (g_eCvars[g_cvarShowSTEAM].aCache && !CheckSteamAuth(target, g_eItems[i].szSteam))))
						m_iStyle = ITEMDRAW_DISABLED;
					
					if(!g_eItems[i].bBuyable && !g_eItems[i].bPreview)
						m_iStyle = ITEMDRAW_DISABLED;
						
					if(!g_eItems[i].bPreview && g_eClients[target].iCredits<m_iPrice && g_eItems[i].iPlans==0)
						m_iStyle = ITEMDRAW_DISABLED;

					if(g_eItems[i].iPlans==0)
					{
						if (g_eCvars[gc_iDescription].aCache < 3)
						{
							AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t\n%s", "Item Available", g_eItems[i].szName, g_eItems[i].iPrice, g_eItems[i].szDescription);
						}
						else AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t", "Item Available", g_eItems[i].szName, g_eItems[i].iPrice);
					}
					else
					{
						if (g_eCvars[gc_iDescription].aCache < 3)
						{
							AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t\n%s", "Item Plan Available", g_eItems[i].szName, g_eItems[i].szDescription);
						}
						else AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t", "Item Plan Available", g_eItems[i].szName);
					}
				}
			}
		}
	}
	
	if(last == -1)
		DisplayMenu(m_hMenu, client, 0);
	else
		DisplayMenuAtItem(m_hMenu, client, (last/GetMenuPagination(m_hMenu))*GetMenuPagination(m_hMenu), 0);
}

public int MenuHandler_Store(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];
		// Confirmation was given
		if(menu == INVALID_HANDLE)
		{
			if(param2 == 0)
			{
				g_iMenuBack[client]=1;
				int m_iPrice = 0;
				if(g_iSelectedPlan[client]==-1)
					m_iPrice = g_eItems[g_iSelectedItem[client]].iPrice;
				else
					m_iPrice = g_ePlans[g_iSelectedItem[client]][g_iSelectedPlan[client]].iPrice_Plan;

				if(g_eClients[target].iCredits>=m_iPrice && !Store_HasClientItem(target, g_iSelectedItem[client]))
					Store_BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);

				if(g_eItems[g_iSelectedItem[client]].iHandler == g_iPackageHandler)
					DisplayStoreMenu(client, g_iSelectedItem[client]);
				else
					DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			else if(param2 == 1)
			{
				Store_SellItem(target, g_iSelectedItem[client]);
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			char m_szId[64];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			g_iLastSelection[client]=param2;
			
			// We are selling a package
			if(strcmp(m_szId, "sell_package")==0)
			{
				if(g_eCvars[g_cvarConfirmation].aCache)
				{
					char m_szTitle[128];
					Format(STRING(m_szTitle), "%t", "Confirm_Sell", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, RoundToFloor(g_eItems[g_iSelectedItem[client]].iPrice*view_as<float>(g_eCvars[g_cvarSellRatio].aCache)));
					Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 1);
					return 0;
				}
				else
				{
					Store_SellItem(target, g_iSelectedItem[client]);
					Store_DisplayPreviousMenu(client);
				}
			}
			// We are gifting a package
			else if(strcmp(m_szId, "gift_package")==0)
			{
				DisplayPlayerMenu(client);
			}
			// This is menu handler stuff
			else if(!(48 <= m_szId[0] <= 57))
			{
				any ret;
				for(int i=0;i<g_iMenuHandlers;++i)
				{
					Call_StartFunction(g_eMenuHandlers[i].hPlugin_Handler, g_eMenuHandlers[i].fnHandler);
					Call_PushCell(target);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
			// We are being boring
			else
			{
				int m_iId = StringToInt(m_szId);
				g_iMenuBack[client]=g_eItems[m_iId].iParent;
				g_iSelectedItem[client] = m_iId;
				g_iSelectedPlan[client] = -1;
				
				if (g_eItems[m_iId].bPreview && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId].iPrice != -1 && g_eItems[m_iId].iPlans == 0)
				{
					DisplayPreviewMenu(client, m_iId);
					return 0;
				}
				else if((g_eClients[target].iCredits>=g_eItems[m_iId].iPrice || g_eItems[m_iId].iPlans>0 && g_eClients[target].iCredits>=Store_GetLowestPrice(m_iId)) && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId].iPrice != -1)				
				{
					if(g_eItems[m_iId].iPlans > 0)
					{
						DisplayPlanMenu(client, m_iId);
						return 0;
					}
					else
						if(g_eCvars[g_cvarConfirmation].aCache)
						{
							char m_szTitle[128];
							Format(STRING(m_szTitle), "%t", "Confirm_Buy", g_eItems[m_iId].szName, g_eTypeHandlers[g_eItems[m_iId].iHandler].szType);
							Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 0);
							return 0;
						}
						else
							Store_BuyItem(target, m_iId);
				}
				
				if(g_eItems[m_iId].iHandler != g_iPackageHandler)
				{				
					if(Store_HasClientItem(target, m_iId))
					{
						if(g_eTypeHandlers[g_eItems[m_iId].iHandler].bRaw)
						{
							Call_StartFunction(g_eTypeHandlers[g_eItems[m_iId].iHandler].hPlugin, g_eTypeHandlers[g_eItems[m_iId].iHandler].fnUse);
							Call_PushCell(target);
							Call_PushCell(m_iId);
							Call_Finish();
						}
						else
							DisplayItemMenu(client, m_iId);
					}
					else
						DisplayStoreMenu(client, g_iMenuBack[client]);					
				}
				else
				{			
					if(Store_HasClientItem(target, m_iId) || g_eItems[m_iId].iPrice == -1)
						DisplayStoreMenu(client, m_iId);
					else
						DisplayStoreMenu(client, g_eItems[m_iId].iParent);
				}
			}
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
			
	return 0;
}