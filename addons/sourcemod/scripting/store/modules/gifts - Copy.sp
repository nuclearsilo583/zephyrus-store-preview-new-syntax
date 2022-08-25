#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <gifts>
#include <zephstocks>
#endif

int g_cvarGiftsEnabled = -1;
int g_cvarGiftsMinimum = -1;
int g_cvarGiftsMaximum = -1;
int g_cvarGiftsFlag = -1;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Gifts_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	LoadTranslations("store.phrases");
#endif

	if(FindPluginByFile("gifts.smx")==INVALID_HANDLE)
	{
		LogError("Gifts! isn't installed or failed to load. Gifts support will be disabled. Please install Gifts. (http://forums.alliedmods.net/showthread.php?t=175185)");
		return;
	}

	g_cvarGiftsEnabled = RegisterConVar("sm_store_gifts_enabled", "1", "Enable/disable gifts support", TYPE_INT);
	g_cvarGiftsMinimum = RegisterConVar("sm_store_gifts_minimum", "1", "Minimum amount of credits to be given", TYPE_INT);
	g_cvarGiftsMaximum = RegisterConVar("sm_store_gifts_maximum", "100", "Maximum amount of credits to be given", TYPE_INT);
	g_cvarGiftsFlag = RegisterConVar("sm_store_gifts_flag", "", "Flag for gifts. Leave blank to disable.", TYPE_FLAG);

	RegConsoleCmd("sm_drop", Command_Drop);

	Store_RegisterMenuHandler("gifts", Gifts_OnMenu, Gifts_OnHandler);
	Gifts_RegisterPlugin(Gifts_OnPickUp);
}

public Action Command_Drop(int client,int args)
{
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarGiftsFlag].aCache))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}

	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
	{
		Chat(client, "%t", "Credit Gift Disabled");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		Chat(client, "%t", "Must be Alive");
		return Plugin_Handled;
	}

	char m_szTmp[64];
	GetCmdArg(1, m_szTmp, sizeof(m_szTmp));
	
	int m_iCredits = StringToInt(m_szTmp);
	if(g_eClients[client][iCredits]<m_iCredits || m_iCredits<=0)
	{
		Chat(client, "%t", "Credit Invalid Amount");
		return Plugin_Handled;
	}

	float pos[3];
	GetClientAbsOrigin(client, pos);
	pos[2]+=20.0;
	Gifts_SpawnGift(Gifts_OnPickUpCredit, "", -1.0, pos, m_iCredits, client);

	Store_SetClientCredits(client, Store_GetClientCredits(client)-m_iCredits);

	Chat(client, "%t", "Credit Gift Dropped", m_iCredits);

	Store_LogMessage(client, -m_iCredits, "Dropped %d credits on the ground", m_iCredits);

	return Plugin_Handled;
}

public void Gifts_OnMenu(Menu &menu, int client,int itemid)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return;
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarGiftsFlag].aCache))
		return;

	int target = Store_GetClientTarget(client);
	char sBuffer[128];
	if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Drop Gift");
		menu.AddItem("drop_gift", sBuffer, ITEMDRAW_DEFAULT);
	}
}

public bool Gifts_OnHandler(int client, char[] info, int itemid)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return false;

	if(strcmp(info, "drop_gift")==0)
	{
		any m_eItem[Store_Item];
		any m_eHandler[Type_Handler];
		Store_GetItem(itemid, m_eItem);
		Store_GetHandler(m_eItem[iHandler], m_eHandler);
		char m_szTitle[128];
		Format(m_szTitle, sizeof(m_szTitle), "%t", "Confirm_Gift_Drop", m_eItem[szName], m_eHandler[szType]);
		Store_SetClientMenu(client, 2);
		if(Store_ShouldConfirm())
			Store_DisplayConfirmMenu(client, m_szTitle, Gifts_MenuHandler, itemid);
		else
		{
			Gifts_MenuHandler(INVALID_HANDLE, MenuAction_Select, client, itemid);
			Store_DisplayPreviousMenu(client);
		}
	}
	return false;
}

public void Gifts_MenuHandler(Handle menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			int target = Store_GetClientTarget(client);
			float pos[3];
			GetClientAbsOrigin(target, pos);
			pos[2]+=20.0;

			any output[Client_Item];
			Store_GetClientItem(client, param2, output);

			Handle data = CreateDataPack();
			WritePackCell(data, param2);
			WritePackCell(data, output[iDateOfPurchase]);
			WritePackCell(data, output[iDateOfExpiration]);
			WritePackCell(data, output[iPriceOfPurchase]);
			ResetPack(data);

			Gifts_SpawnGift(Gifts_OnPickUpItem, "", -1.0, pos, view_as<int>(data), target);
			Store_RemoveItem(target, param2);
		}
	}
}

public void Gifts_OnPickUp(int client)
{
	int m_iCredits = GetRandomInt(g_eCvars[g_cvarGiftsMinimum].aCache, g_eCvars[g_cvarGiftsMaximum].aCache);
	Store_SetClientCredits(client, Store_GetClientCredits(client)+m_iCredits);
	Chat(client, "%t", "Gift Credit Picked", m_iCredits);
}

public void Gifts_OnPickUpItem(int client, int data,int owner)
{
	Handle m_hData = view_as<Handle>(data);

	int itemid = ReadPackCell(m_hData);
	any purchase = ReadPackCell(m_hData);
	any expiration = ReadPackCell(m_hData);
	int price = ReadPackCell(m_hData);

	CloseHandle(m_hData);

	any m_eItem[Store_Item];
	any m_eHandler[Type_Handler];
	Store_GetItem(itemid, m_eItem);
	Store_GetHandler(m_eItem[iHandler], m_eHandler);

	Store_GiveItem(client, itemid, purchase, expiration, price);
	Chat(client, "%t", "Gift Item Picked", m_eItem[szName], m_eHandler[szType]);

	Store_LogMessage(client, 0, "Picked up a gift containing the following item: %s", m_eItem[szName]);
}

public void Gifts_OnPickUpCredit(int client,int data,int owner)
{
	Store_SetClientCredits(client, Store_GetClientCredits(client)+data);
	Chat(client, "%t", "Gift Credit Picked", data);

	Store_LogMessage(client, data, "Picked up a gift containing %d credits", data);
}