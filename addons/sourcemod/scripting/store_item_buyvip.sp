#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <store>
#include <colorvariables>
#include <vip_core>

int g_iVIP = 0;

char g_sVIPGroup[STORE_MAX_ITEMS][64];
int g_iVIPTime[STORE_MAX_ITEMS];

char g_sChatPrefix[128];

public Plugin myinfo = 
{
	name = "Store - VIP Module for R1KO's VIP Core",
	author = "AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{	
	Store_RegisterHandler("buyvip-r1ko", "", VIP_OnMapStart, VIP_Reset, VIP_Config, VIP_Equip, VIP_Remove, true);
	
	LoadTranslations("store.phrases");
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void VIP_OnMapStart()
{
}

public void VIP_Reset()
{
	g_iVIP = 0;
}

public bool VIP_Config(KeyValues &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iVIP);

	kv.GetString("group", g_sVIPGroup[g_iVIP], 64);
	g_iVIPTime[g_iVIP] = kv.GetNum("time", 0);
	
	g_iVIP++;
	
	return true;
}

public int VIP_Equip(int client, int id)
{
	if(VIP_IsClientVIP(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You already have VIP status!");
	}
	else
	{
		int m_iData = Store_GetDataIndex(id);
		
		VIP_GiveClientVIP(_, client, g_iVIPTime[m_iData], g_sVIPGroup[m_iData], true);

		Store_RemoveItem(client, id);
	}
	
	return 0;
}

public int VIP_Remove(int client,int id)
{
	return 0;
}