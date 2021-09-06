#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <store>
#include <zephstocks>

#include <colors> 
#include <chat-processor> 

char g_sNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_sNameColors[STORE_MAX_ITEMS][32];
char g_sMessageColors[STORE_MAX_ITEMS][32];
char g_sScoreboardTags[STORE_MAX_ITEMS][64];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;
int g_iScoreboardTags = 0;

public Plugin myinfo = 
{
	name = "Store - Chat Processor item module with Scoreboard Tag",
	author = "nuclear silo, Mesharsky, AiDN™", 
	description = "Chat Processor item module by nuclear silo, the Scoreboard Tag for Zephyrus's by Mesharksy, for nuclear silo's edited store by AiDN™",
	version = "1.5", 
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
	Store_RegisterHandler("scoreboardtag", "scoreboardtag", _, CPSupport_Reset, ScoreboardTags_Config, CPSupport_Equip, CPSupport_Remove, true);

	HookEvent("player_team", PlayerTeam_Callback);
	HookEvent("player_spawn", PlayerSpawn_Callback);
}

public void CPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
	g_iScoreboardTags = 0;
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

public bool ScoreboardTags_Config(KeyValues &kv, int itemid) 
{
	Store_SetDataIndex(itemid, g_iScoreboardTags);

	kv.GetString("scoreboardtag", g_sScoreboardTags[g_iScoreboardTags], sizeof(g_sScoreboardTags[]));
	g_iScoreboardTags++;

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

public Action PlayerSpawn_Callback(Event event, const char[] chName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int iEquippedScoreboardTag = Store_GetEquippedItem(client, "scoreboardtag");

	if(iEquippedScoreboardTag < 0)
		return Plugin_Continue;

	char sBuffer[64];
	char ScoreboardTag[64];

	if(iEquippedScoreboardTag >= 0)
	{
		int m_iScoreboardTag = Store_GetDataIndex(iEquippedScoreboardTag);
		strcopy(ScoreboardTag, sizeof(ScoreboardTag), g_sScoreboardTags[m_iScoreboardTag]);
	}

	Format(sBuffer, sizeof(sBuffer), "%s", ScoreboardTag);

	CS_SetClientClanTag(client, sBuffer);
	return Plugin_Handled;
}

public Action PlayerTeam_Callback(Event event, const char[] chName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int iEquippedScoreboardTag = Store_GetEquippedItem(client, "scoreboardtag");

	if(iEquippedScoreboardTag < 0)
		return Plugin_Continue;

	char sBuffer[64];
	char ScoreboardTag[64];

	if(iEquippedScoreboardTag >= 0)
	{
		int m_iScoreboardTag = Store_GetDataIndex(iEquippedScoreboardTag);
		strcopy(ScoreboardTag, sizeof(ScoreboardTag), g_sScoreboardTags[m_iScoreboardTag]);
	}

	Format(sBuffer, sizeof(sBuffer), "%s", ScoreboardTag);

	CS_SetClientClanTag(client, sBuffer);
	return Plugin_Handled;
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