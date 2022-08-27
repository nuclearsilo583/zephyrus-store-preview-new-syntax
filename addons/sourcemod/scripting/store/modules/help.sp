#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_CSGO = false;
#endif

new String:g_szHelpTitle[STORE_MAX_ITEMS][256];
new String:g_szHelp[STORE_MAX_ITEMS][256];

new g_iHelp = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Help_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "csgo")==0)
		GAME_CSGO = true;
#endif
	Store_RegisterHandler("help", "", Help_OnMapStart, Help_Reset, Help_Config, Help_Equip, Help_Remove, false, true);
}

public Help_OnMapStart()
{
}

public Help_Reset()
{
	g_iHelp = 0;
}

public Help_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iHelp);
	
	KvGetSectionName(kv, g_szHelpTitle[g_iHelp], sizeof(g_szHelpTitle[]));
	KvGetString(kv, "text", g_szHelp[g_iHelp], sizeof(g_szHelp[]));

	ReplaceString(g_szHelp[g_iHelp], sizeof(g_szHelp[]), "\\n", "\n");
	
	++g_iHelp;
	return true;
}

public Help_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);

	new Handle:m_hPanel = CreatePanel();
	SetPanelTitle(m_hPanel, g_szHelpTitle[m_iData]);

	DrawPanelText(m_hPanel, g_szHelp[m_iData]);

	SetPanelCurrentKey(m_hPanel, 8);
	DrawPanelItemEx(m_hPanel, ITEMDRAW_DEFAULT, "%t", "Help_Back");
	if(GAME_CSGO)
		SetPanelCurrentKey(m_hPanel, 9);
	else
		SetPanelCurrentKey(m_hPanel, 10);
	DrawPanelItemEx(m_hPanel, ITEMDRAW_DEFAULT, "%t", "Help_Exit");
 
	SendPanelToClient(m_hPanel, client, PanelHandler_Help, 0);
	CloseHandle(m_hPanel);

	return 0;
}

public PanelHandler_Help(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
		if(param2 == 8)
			Store_DisplayPreviousMenu(client);
}


public Help_Remove(client)
{
	return 0;
}