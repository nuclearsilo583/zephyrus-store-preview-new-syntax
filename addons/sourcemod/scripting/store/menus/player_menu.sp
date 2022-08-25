public void DisplayPlayerMenu(int client)
{
	g_iMenuNum[client] = 3;
	int target = g_iMenuClient[client];

	int m_iCount = 0;
	Handle m_hMenu = CreateMenu(MenuHandler_Gift);
	SetMenuExitBackButton(m_hMenu, true);
	SetMenuTitle(m_hMenu, "%t\n%t", "Title Gift", "Title Credits", g_eClients[client].iCredits);
	
	char m_szID[11];
	int m_iFlags;
	LoopIngamePlayers(i)
	{
		m_iFlags = GetUserFlagBits(i);
		if(!GetClientPrivilege(i, g_eItems[g_iSelectedItem[client]].iFlagBits, m_iFlags))
			continue;
		if(i != target && IsClientInGame(i) && !Store_HasClientItem(i, g_iSelectedItem[client]))
		{
			IntToString(g_eClients[i].iUserId, STRING(m_szID));
			AddMenuItem(m_hMenu, m_szID, g_eClients[i].szName_Client);
			++m_iCount;
		}
	}
	
	if(m_iCount == 0)
	{
		CloseHandle(m_hMenu);
		g_iMenuNum[client] = 1;
		DisplayItemMenu(client, g_iSelectedItem[client]);
		//Chat(client, "%t", "Gift No Players");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Gift No Players");
	}
	else
		DisplayMenu(m_hMenu, client, 0);
}