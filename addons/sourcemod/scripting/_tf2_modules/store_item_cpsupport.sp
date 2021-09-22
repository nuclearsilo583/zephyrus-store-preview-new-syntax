#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
//#include <cstrike>

#include <store>
#include <zephstocks>

#include <chat-processor> 

char g_sNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_sNameColors[STORE_MAX_ITEMS][32];
char g_sMessageColors[STORE_MAX_ITEMS][32];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;

public Plugin myinfo = 
{
	name = "Store - Chat Processor item module with Scoreboard Tag [TF2:Modules]",
	author = "nuclear silo", 
	description = "Chat Processor item module by nuclear silo",
	version = "1.0", 
	url = ""
};

public void OnPluginStart()
{
	//Store_SetDataIndex("nametag", _, SCPSupport_Reset, NameTags_Config, SCPSupport_Equip, CPSupport_Remove, true);
	//Store_SetDataIndex("namecolor", _, SCPSupport_Reset, NameColors_Config, SCPSupport_Equip, CPSupport_Remove, true);
	//Store_SetDataIndex("msgcolor", _, SCPSupport_Reset, MsgColors_Config, SCPSupport_Equip, CPSupport_Remove, true);
	//Store_SetDataIndex("scoreboardtag", _, SCPSupport_Reset, ScoreboardTags_Config, SCPSupport_Equip, CPSupport_Remove, true);
	
	Store_RegisterHandler("nametag", "tag", _, CPSupport_Reset, NameTags_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("namecolor", "color", _, CPSupport_Reset, NameColors_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("msgcolor", "color", _, CPSupport_Reset, MsgColors_Config, CPSupport_Equip, CPSupport_Remove, true);
}

public void CPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
	//g_iScoreboardTags = 0;
}

public bool NameTags_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameTags);
	kv.GetString("tag", g_sNameTags[g_iNameTags], sizeof(g_sNameTags[]));
	g_iNameTags++;

	return true;
}

public bool NameColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameColors);
	kv.GetString("color", g_sNameColors[g_iNameColors], sizeof(g_sNameColors[]));
	g_iNameColors++;

	return true;
}

public bool MsgColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iMessageColors);
	kv.GetString("color", g_sMessageColors[g_iMessageColors], sizeof(g_sMessageColors[]));
	g_iMessageColors++;

	return true;
}

public int CPSupport_Equip(int client, int itemid)
{
	return -1;
}

public int CPSupport_Remove(int client, int itemid)
{
	return 0;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	int iEquippedNameTag = Store_GetEquippedItem(author, "nametag");
	int iEquippedNameColor = Store_GetEquippedItem(author, "namecolor");
	int iEquippedMsgColor = Store_GetEquippedItem(author, "msgcolor");

	if (iEquippedNameTag < 0 && iEquippedNameColor < 0 && iEquippedMsgColor < 0)
		return Plugin_Continue;

	char sName[MAXLENGTH_NAME*2];
	char sNameTag[MAXLENGTH_NAME];
	char sNameColor[32];

	if (iEquippedNameTag >= 0)
	{
		int iNameTag = Store_GetDataIndex(iEquippedNameTag);
		strcopy(sNameTag, sizeof(sNameTag), g_sNameTags[iNameTag]);
	}

	if (iEquippedNameColor >= 0)
	{
		int iNameColor = Store_GetDataIndex(iEquippedNameColor);
		strcopy(sNameColor, sizeof(sNameColor), g_sNameColors[iNameColor]);
	}

	Format(sName, sizeof(sName), "%s{teamcolor}%s%s", sNameTag, sNameColor, name);
	
	ReplaceColors(sName, sizeof(sName), author);

	strcopy(name, MAXLENGTH_NAME, sName);

	if (iEquippedMsgColor >= 0)
	{
		char sMessage[MAXLENGTH_BUFFER];
		strcopy(sMessage, sizeof(sMessage), message);
		Format(message, MAXLENGTH_BUFFER, "%s%s", g_sMessageColors[Store_GetDataIndex(iEquippedMsgColor)], sMessage);
		ReplaceColors(message, MAXLENGTH_BUFFER, author);
	}

	return Plugin_Changed;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	if (IsClientReplay(client))return false;
	if (IsFakeClient(client))return false;
	if (IsClientSourceTV(client))return false;
	return IsClientInGame(client);
}