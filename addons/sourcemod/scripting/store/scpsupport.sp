#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#include <scp>
#endif

char g_szNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_szNameColors[STORE_MAX_ITEMS][32];
char g_szMessageColors[STORE_MAX_ITEMS][32];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void SCPSupport_OnPluginStart()
#endif
{	
	if(FindPluginByFile("simple-chatprocessor.smx")==INVALID_HANDLE)
	{
		LogError("Simple Chat Processor isn't installed or failed to load. SCP support will be disabled. (http://forums.alliedmods.net/showthread.php?t=198501)");
		return;
	}

	Store_RegisterHandler("nametag", "tag", SCPSupport_OnMappStart, SCPSupport_Reset, NameTags_Config, SCPSupport_Equip, SCPSupport_Remove, true);
	Store_RegisterHandler("namecolor", "color", SCPSupport_OnMappStart, SCPSupport_Reset, NameColors_Config, SCPSupport_Equip, SCPSupport_Remove, true);
	Store_RegisterHandler("msgcolor", "color", SCPSupport_OnMappStart, SCPSupport_Reset, MsgColors_Config, SCPSupport_Equip, SCPSupport_Remove, true);
}

public void SCPSupport_OnMappStart()
{
}

public void SCPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
}

public bool NameTags_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iNameTags);
	KvGetString(kv, "tag", g_szNameTags[g_iNameTags], sizeof(g_szNameTags[]));
	g_iNameTags++;
	
	return true;
}

public bool NameColors_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iNameColors);
	KvGetString(kv, "color", g_szNameColors[g_iNameColors], sizeof(g_szNameColors[]));
	g_iNameColors++;
	
	return true;
}

public bool MsgColors_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iMessageColors);
	KvGetString(kv, "color", g_szMessageColors[g_iMessageColors], sizeof(g_szMessageColors[]));
	g_iMessageColors++;
	
	return true;
}

public int SCPSupport_Equip(int client,int id)
{
	return -1;
}

public int SCPSupport_Remove(int client,int id)
{
}

public Action OnChatMessage(any client, Handle recipients, char[] name, char[] message)
{
	any m_iEquippedNameTag = Store_GetEquippedItem(client, "nametag");
	any m_iEquippedNameColor = Store_GetEquippedItem(client, "namecolor");
	any m_iEquippedMsgColor = Store_GetEquippedItem(client, "msgcolor");
	
	if(m_iEquippedNameTag < 0 && m_iEquippedNameColor < 0 && m_iEquippedMsgColor < 0)
		return Plugin_Continue;
	
	char m_szName[MAXLENGTH_NAME*2];
	char m_szNameTag[MAXLENGTH_NAME];
	char m_szNameColor[32];
	
	if(m_iEquippedNameTag >= 0)
	{
		int m_iNameTag = Store_GetDataIndex(m_iEquippedNameTag);
		strcopy(STRING(m_szNameTag), g_szNameTags[m_iNameTag]);
	}
	if(m_iEquippedNameColor >= 0)
	{
		int m_iNameColor = Store_GetDataIndex(m_iEquippedNameColor);
		strcopy(STRING(m_szNameColor), g_szNameColors[m_iNameColor]);
	}
	Format(STRING(m_szName), "%s%s%s", m_szNameTag, m_szNameColor, name);
	ReplaceColors(STRING(m_szName), client);
	strcopy(name, MAXLENGTH_NAME, m_szName);

	if(m_iEquippedMsgColor >= 0)
	{
		char m_szMessage[MAXLENGTH_INPUT];
		strcopy(STRING(m_szMessage), message);
		Format(message, MAXLENGTH_INPUT, "%s%s", g_szMessageColors[Store_GetDataIndex(m_iEquippedMsgColor)], m_szMessage);
		ReplaceColors(message, MAXLENGTH_INPUT, client);
	}

	return Plugin_Changed;
}