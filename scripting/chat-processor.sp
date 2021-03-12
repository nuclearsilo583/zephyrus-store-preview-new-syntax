////////////////////
//Pragma
#pragma semicolon 1
#pragma newdecls required

////////////////////
//Defines
#define PLUGIN_NAME "Chat-Processor"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION "Replacement for Simple Chat Processor."
#define PLUGIN_VERSION "2.2.1"
#define PLUGIN_CONTACT "https://drixevel.dev/"

////////////////////
//Includes
#include <sourcemod>
#include <chat-processor>
#include <colorvariables>

////////////////////
//ConVars
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_Default_ProcessColors;
ConVar convar_Default_RemoveColors;
ConVar convar_StripColors;
ConVar convar_ColorsFlags;
ConVar convar_DeadChat;
ConVar convar_AllChat;
ConVar convar_RestrictDeadChat;
ConVar convar_AddGOTV;

////////////////////
//Forwards
Handle g_Forward_OnChatMessageSendPre;
Handle g_Forward_OnChatMessage;
Handle g_Forward_OnChatMessagePost;

Handle g_Forward_OnAddClientTagPost;
Handle g_Forward_OnRemoveClientTagPost;
Handle g_Forward_OnSwapClientTagsPost;
Handle g_Forward_OnStripClientTagsPost;
Handle g_Forward_OnSetTagColorPost;
Handle g_Forward_OnSetNameColorPost;
Handle g_Forward_OnSetChatColorPost;
Handle g_Forward_OnReloadChatData;

////////////////////
//Globals
EngineVersion engine;
bool g_Late;
StringMap g_MessageFormats;
bool g_Proto;
bool g_NewMSG[MAXPLAYERS + 1];

//Tags
ArrayList g_Tags[MAXPLAYERS + 1];
char g_NameColor[MAXPLAYERS + 1][MAXLENGTH_NAME];
char g_ChatColor[MAXPLAYERS + 1][MAXLENGTH_MESSAGE];

////////////////////
// Plugin Info
public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

////////////////////
// Ask Plugin Load 2
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("chat-processor");
	
	CreateNative("ChatProcessor_GetFlagFormatString", Native_GetFlagFormatString);
	
	CreateNative("ChatProcessor_AddClientTag", Native_AddClientTag);
	CreateNative("ChatProcessor_RemoveClientTag", Native_RemoveClientTag);
	CreateNative("ChatProcessor_SwapClientTags", Native_SwapClientTags);
	CreateNative("ChatProcessor_StripClientTags", Native_StripClientTags);
	CreateNative("ChatProcessor_SetTagColor", Native_SetTagColor);
	CreateNative("ChatProcessor_SetNameColor", Native_SetNameColor);
	CreateNative("ChatProcessor_SetChatColor", Native_SetChatColor);

	g_Forward_OnChatMessageSendPre = CreateGlobalForward("CP_OnChatMessageSendPre", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_Forward_OnChatMessage = CreateGlobalForward("CP_OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_String, Param_CellByRef, Param_CellByRef);
	g_Forward_OnChatMessagePost = CreateGlobalForward("CP_OnChatMessagePost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_Cell, Param_Cell);
	
	g_Forward_OnAddClientTagPost = CreateGlobalForward("CP_OnAddClientTagPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_Forward_OnRemoveClientTagPost = CreateGlobalForward("CP_OnRemoveClientTagPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	g_Forward_OnSwapClientTagsPost = CreateGlobalForward("CP_OnSwapClientTagsPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String);
	g_Forward_OnStripClientTagsPost = CreateGlobalForward("CP_OnStripClientTagsPost", ET_Ignore, Param_Cell);
	g_Forward_OnSetTagColorPost = CreateGlobalForward("CP_OnSetTagColorPost", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	g_Forward_OnSetNameColorPost = CreateGlobalForward("CP_OnSetNameColorPost", ET_Ignore, Param_Cell, Param_String);
	g_Forward_OnSetChatColorPost = CreateGlobalForward("CP_OnSetChatColorPost", ET_Ignore, Param_Cell, Param_String);
	g_Forward_OnReloadChatData = CreateGlobalForward("CP_OnReloadChatData", ET_Ignore);

	engine = GetEngineVersion();
	g_Late = late;
	
	return APLRes_Success;
}

////////////////////
// On Plugin Start
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	//LoadTranslations("chatprocessor.phrases");

	CreateConVar("sm_chatprocessor_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	convar_Status = CreateConVar("sm_chatprocessor_status", "1", "Status of the plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config = CreateConVar("sm_chatprocessor_config", "configs/chat_processor.cfg", "Name of the message formats config.", FCVAR_NOTIFY);
	convar_Default_ProcessColors = CreateConVar("sm_chatprocessor_process_colors_default", "1", "Default setting to give forwards to process colors.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Default_RemoveColors = CreateConVar("sm_chatprocessor_remove_colors_default", "0", "Default setting to give forwards to remove colors.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_StripColors = CreateConVar("sm_chatprocessor_strip_colors", "1", "Remove color tags from the name and the message before processing the output.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_ColorsFlags = CreateConVar("sm_chatprocessor_colors_flag", "b", "Flags required to use the color name and message. Needs sm_chatprocessor_strip_colors 1", FCVAR_NOTIFY);
	convar_DeadChat = CreateConVar("sm_chatprocessor_deadchat", "1", "Controls how dead communicate.\n(0 = off, 1 = on)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_AllChat = CreateConVar("sm_chatprocessor_allchat", "0", "Allows both teams to communicate with each other through team chat.\n(0 = off, 1 = on)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_RestrictDeadChat = CreateConVar("sm_chatprocessor_restrictdeadchat", "0", "Restricts all chat for the dead entirely.\n(0 = off, 1 = on)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_AddGOTV = CreateConVar("sm_chatprocessor_addgotv", "1", "Add GOTV client to recipients list. (Only effects games with GOTV or SourceTV)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig();

	g_MessageFormats = new StringMap();
}

////////////////////
// On Configs Executed
public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue)
		return;

	char sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));

	char sConfig[PLATFORM_MAX_PATH];
	convar_Config.GetString(sConfig, sizeof(sConfig));

	GenerateMessageFormats(sConfig, sGame);

	g_Proto = CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;

	UserMsg SayText2 = GetUserMessageId("SayText2");

	if (SayText2 != INVALID_MESSAGE_ID)
	{
		HookUserMessage(SayText2, OnSayText2, true);
		LogMessage("Successfully hooked a SayText2 chat hook.");
	}
	else
		SetFailState("Error loading the plugin, SayText2 is unavailable.");
	
	if (g_Late)
	{
		g_Late = false;
		
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientConnected(i))
				OnClientConnected(i);
		
		Call_StartForward(g_Forward_OnReloadChatData);
		Call_Finish();
	}
}

////////////////////
// Chat hook
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (convar_Status.BoolValue && client > 0 && StrContains(command, "say") != -1)
		g_NewMSG[client] = true;
}

////////////////////
//SayText2
public Action OnSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	//Check if the plugin is disabled.
	if (!convar_Status.BoolValue)
		return Plugin_Continue;

	//Retrieve the client sending the message to other clients.
	int iSender = g_Proto ? PbReadInt(msg, "ent_idx") : BfReadByte(msg);

	if (iSender <= 0)
		return Plugin_Continue;

	//Chat Type
	bool bChat = g_Proto ? PbReadBool(msg, "chat") : view_as<bool>(BfReadByte(msg));

	//Retrieve the name of template name to use when getting the format.
	char sFlag[MAXLENGTH_FLAG];
	switch (g_Proto)
	{
		case true: PbReadString(msg, "msg_name", sFlag, sizeof(sFlag));
		case false: BfReadString(msg, sFlag, sizeof(sFlag));
	}

	//Retrieve the format template based on the flag name above we retrieved.
	char sFormat[MAXLENGTH_BUFFER];
	if (!g_MessageFormats.GetString(sFlag, sFormat, sizeof(sFormat)))
		return Plugin_Continue;
	
	//Stops double messages in-general.
	if (g_NewMSG[iSender])
		g_NewMSG[iSender] = false;
	else if (reliable)	//Fix for other plugins that use SayText2 I guess?
		return Plugin_Stop;
	
	//Get the name string of the client.
	char sName[MAXLENGTH_NAME];
	switch (g_Proto)
	{
		case true: PbReadString(msg, "params", sName, sizeof(sName), 0);
		case false: if (BfGetNumBytesLeft(msg)) BfReadString(msg, sName, sizeof(sName));
	}

	//Get the message string that the client is wanting to send.
	char sMessage[MAXLENGTH_MESSAGE];
	switch (g_Proto)
	{
		case true: PbReadString(msg, "params", sMessage, sizeof(sMessage), 1);
		case false: if (BfGetNumBytesLeft(msg)) BfReadString(msg, sMessage, sizeof(sMessage));
	}

	//Clients have the ability to color their chat if they manually type in color tags, this allows server operators to choose if they want their players the ability to do so.
	//Example: {red}This {white}is {green}a {blue}random {yellow}message.
	//Goes for both the name and the message.
	if (convar_StripColors.BoolValue)
	{
		char sFlags[32];
		convar_ColorsFlags.GetString(sFlags, sizeof(sFlags));
		
		if (strlen(sFlags) == 0 || !CheckCommandAccess(iSender, "", ReadFlagString(sFlags), true))
		{
			CRemoveColors(sName, sizeof(sName));
			CRemoveColors(sMessage, sizeof(sMessage));
		}
	}

	//It's easier just to use a handle here for an array instead of passing 2 arguments through both forwards with static arrays.
	ArrayList hRecipients = new ArrayList();

	bool bDeadTalk = convar_DeadChat.BoolValue;
	bool bAllTalk = convar_AllChat.BoolValue;
	bool bRestrictDeadChat = convar_RestrictDeadChat.BoolValue;
	int team = GetClientTeam(iSender);

	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientInGame(i) || (!convar_AddGOTV.BoolValue && IsFakeClient(i)))
			continue;

		if (convar_AddGOTV.BoolValue && IsFakeClient(i) && IsClientSourceTV(i) && hRecipients.FindValue(GetClientUserId(i)) == -1)
			hRecipients.Push(GetClientUserId(i));

		if (bRestrictDeadChat && !IsPlayerAlive(iSender))
			continue;

		if (!IsPlayerAlive(iSender) && !bDeadTalk && IsPlayerAlive(i))
			continue;

		if (!bAllTalk && StrContains(sFlag, "_All") == -1 && team != GetClientTeam(i))
			continue;
		
		hRecipients.Push(GetClientUserId(i));
	}

	//Retrieve the default values for coloring and use these as a base for developers to change later.
	bool bProcessColors = convar_Default_ProcessColors.BoolValue;
	bool bRemoveColors = convar_Default_RemoveColors.BoolValue;

	//We need to make copy of these strings for checks after the pre-forward has fired.
	char sNameCopy[MAXLENGTH_NAME];
	strcopy(sNameCopy, sizeof(sNameCopy), sName);

	char sMessageCopy[MAXLENGTH_MESSAGE];
	strcopy(sMessageCopy, sizeof(sMessageCopy), sMessage);

	char sFlagCopy[MAXLENGTH_FLAG];
	strcopy(sFlagCopy, sizeof(sFlagCopy), sFlag);

	//Fire the pre-forward. https://i.ytimg.com/vi/A2a0Ht01qA8/maxresdefault.jpg
	Call_StartForward(g_Forward_OnChatMessage);
	Call_PushCellRef(iSender);
	Call_PushCell(hRecipients);
	Call_PushStringEx(sFlag, sizeof(sFlag), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(sName, sizeof(sName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(sMessage, sizeof(sMessage), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCellRef(bProcessColors);
	Call_PushCellRef(bRemoveColors);

	//Retrieve the results here and use manage it.
	Action iResults;
	int error = Call_Finish(iResults);

	//We ran into a native error, gotta report it.
	if (error != SP_ERROR_NONE)
	{
		delete hRecipients;
		ThrowNativeError(error, "Global Forward 'CP_OnChatMessage' has failed to fire. [Error code: %i]", error);
		return Plugin_Continue;
	}

	//Check if the flag string was changed after the pre-forward and if so, re-retrieve the format string.
	if (!StrEqual(sFlag, sFlagCopy) && !g_MessageFormats.GetString(sFlag, sFormat, sizeof(sFormat)))
	{
		delete hRecipients;
		return Plugin_Continue;
	}

	if (StrEqual(sNameCopy, sName))
		Format(sName, sizeof(sName), "\x03%s", sName);

	if (StrEqual(sMessageCopy, sMessage))
		Format(sMessage, sizeof(sMessage), "\x01%s", sMessage);

	DataPack hPack = new DataPack();
	hPack.WriteCell(iSender);
	hPack.WriteCell(hRecipients);
	hPack.WriteString(sName);
	hPack.WriteString(sMessage);
	hPack.WriteString(sFlag);
	hPack.WriteCell(bProcessColors);
	hPack.WriteCell(bRemoveColors);

	hPack.WriteString(sFormat);
	hPack.WriteCell(bChat);
	hPack.WriteCell(iResults);
	hPack.WriteCell(bRestrictDeadChat);

	RequestFrame(Frame_OnChatMessage_SayText2, hPack);

	return Plugin_Stop;
}

public void Frame_OnChatMessage_SayText2(DataPack data)
{
	//Retrieve pack contents and what not, this part is obvious.
	data.Reset();

	int iSender = data.ReadCell();
	ArrayList hRecipients = data.ReadCell();

	char sName[MAXLENGTH_NAME];
	data.ReadString(sName, sizeof(sName));

	char sMessage[MAXLENGTH_MESSAGE];
	data.ReadString(sMessage, sizeof(sMessage));

	char sFlag[MAXLENGTH_FLAG];
	data.ReadString(sFlag, sizeof(sFlag));

	bool bProcessColors = data.ReadCell();
	bool bRemoveColors = data.ReadCell();

	char sFormat[MAXLENGTH_BUFFER];
	data.ReadString(sFormat, sizeof(sFormat));

	bool bChat = data.ReadCell();
	Action iResults = data.ReadCell();

	bool bRestrictDeadChat = data.ReadCell();

	delete data;

	if (bRestrictDeadChat)
		PrintToChat(iSender, "Dead chat is currently restricted.");

	//Make a copy of the format buffer and use that as the print so the format string stays the same.
	char sBuffer[MAXLENGTH_BUFFER];
	strcopy(sBuffer, sizeof(sBuffer), sFormat);

	//Make sure that the text is default for the message if no colors are present.
	if (iResults != Plugin_Changed && !bProcessColors || bRemoveColors)
		Format(sMessage, sizeof(sMessage), "\x03%s", sMessage);

	//Replace the specific characters for the name and message strings.
	ReplaceString(sBuffer, sizeof(sBuffer), "{1}", sName);
	ReplaceString(sBuffer, sizeof(sBuffer), "{2}", sMessage);
	ReplaceString(sBuffer, sizeof(sBuffer), "{3}", "\x01");

	//Process colors based on the final results we have.
	if (iResults == Plugin_Changed && bProcessColors)
	{
		CProcessVariables(sBuffer, sizeof(sBuffer), bRemoveColors);

		//CSGO quirk where the 1st color in the line won't work..
		if (engine == Engine_CSGO)
			Format(sBuffer, sizeof(sBuffer), " %s", sBuffer);
	}

	if (iResults != Plugin_Stop)
	{
		//Send the message to clients.
		int client; char sTempBuffer[MAXLENGTH_BUFFER];
		for (int i = 0; i < hRecipients.Length; i++)
		{
			if ((client = GetClientOfUserId(hRecipients.Get(i))) > 0 && IsClientInGame(client))
			{
				strcopy(sTempBuffer, sizeof(sTempBuffer), sBuffer);		
						
				Call_StartForward(g_Forward_OnChatMessageSendPre);		
				Call_PushCell(iSender);		
				Call_PushCell(client);		
				Call_PushStringEx(sTempBuffer, sizeof(sTempBuffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);		
				Call_PushCell(sizeof(sTempBuffer));		
						
				int error = Call_Finish(iResults);		
						
				if (error != SP_ERROR_NONE)		
				{		
					delete hRecipients;		
					ThrowNativeError(error, "Global Forward 'CP_OnChatMessageSendPre' has failed to fire. [Error code: %i]", error);		
					return;		
				}		
			
				if (iResults == Plugin_Stop)		
						continue;
				
				if (g_Proto)
					CSayText2(client, sTempBuffer, iSender, bChat);
				else
				{
					CSetNextAuthor(iSender);
					CPrintToChat(client, "%s", sTempBuffer);
				}
			}
		}
	}

	//Finally... fire the post-forward after the message has been sent and processed. https://s-media-cache-ak0.pinimg.com/564x/a5/bb/3c/a5bb3c3e05089a40ef01ea082ac39e24.jpg
	Call_StartForward(g_Forward_OnChatMessagePost);
	Call_PushCell(iSender);
	Call_PushCell(hRecipients);
	Call_PushString(sFlag);
	Call_PushString(sFormat);
	Call_PushString(sName);
	Call_PushString(sMessage);
	Call_PushCell(bProcessColors);
	Call_PushCell(bRemoveColors);
	Call_Finish();

	//Close the recipients handle.
	delete hRecipients;
}

////////////////////
//Parse message formats for flags.
void GenerateMessageFormats(const char[] config, const char[] game)
{
	KeyValues kv = new KeyValues("chat-processor");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), config);

	if (kv.ImportFromFile(sPath) && kv.JumpToKey(game) && kv.GotoFirstSubKey(false))
	{
		g_MessageFormats.Clear();

		do
		{
			char sName[256];
			kv.GetSectionName(sName, sizeof(sName));

			char sValue[256];
			kv.GetString(NULL_STRING, sValue, sizeof(sValue));

			g_MessageFormats.SetString(sName, sValue);
		}
		while (kv.GotoNextKey(false));

		LogMessage("Message formats generated for game '%s'.", game);
		delete kv;

		return;
	}

	LogError("Error parsing the flag message formatting config for game '%s', please verify its integrity.", game);
	delete kv;
}

////////////////////
//Flag format string native
public int Native_GetFlagFormatString(Handle plugin, int numParams)
{
	int iSize;
	GetNativeStringLength(1, iSize);

	char[] sFlag = new char[iSize + 1];
	GetNativeString(1, sFlag, iSize + 1);

	char sFormat[MAXLENGTH_BUFFER];
	g_MessageFormats.GetString(sFlag, sFormat, sizeof(sFormat));

	SetNativeString(2, sFormat, GetNativeCell(3));
}

////////////////////
//Tags

public void OnClientConnected(int client)
{
	g_Tags[client] = new ArrayList(ByteCountToCells(MAXLENGTH_NAME));
}

public void OnClientDisconnect_Post(int client)
{
	delete g_Tags[client];
	g_NameColor[client][0] = '\0';
	g_ChatColor[client][0] = '\0';
}

bool AddClientTag(int client, const char[] tag)
{
	if (client == 0 || client > MaxClients || IsFakeClient(client))
		return false;
	
	int index = g_Tags[client].PushString(tag);
	
	Call_StartForward(g_Forward_OnAddClientTagPost);
	Call_PushCell(client);
	Call_PushCell(index);
	Call_PushString(tag);
	Call_Finish();
	
	return true;
}

public int Native_AddClientTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] sTag = new char[size];
	GetNativeString(2, sTag, size);
	
	return AddClientTag(client, sTag);
}

bool RemoveClientTag(int client, const char[] tag)
{
	if (client == 0 || client > MaxClients || IsFakeClient(client))
		return false;
	
	bool found; char sTag[MAXLENGTH_NAME];
	for (int i = 0; i < g_Tags[client].Length; i++)
	{
		g_Tags[client].GetString(i, sTag, sizeof(sTag));
		
		if (StrContains(sTag, tag, false) == -1)
			continue;
			
		g_Tags[client].Erase(i);
		
		Call_StartForward(g_Forward_OnRemoveClientTagPost);
		Call_PushCell(client);
		Call_PushCell(i);
		Call_PushString(tag);
		Call_Finish();
		
		found = true;
	}
	
	return found;
}

public int Native_RemoveClientTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] sTag = new char[size];
	GetNativeString(2, sTag, size);
	
	return RemoveClientTag(client, sTag);
}

bool SwapClientTags(int client, const char[] tag1, const char[] tag2)
{
	if (client == 0 || client > MaxClients || IsFakeClient(client))
		return false;
	
	int index1 = -1;
	if ((index1 = g_Tags[client].FindString(tag1)) == -1)
		return false;
	
	int index2 = -1;
	if ((index2 = g_Tags[client].FindString(tag2)) == -1)
		return false;
	
	g_Tags[client].SwapAt(index1, index2);
	
	Call_StartForward(g_Forward_OnSwapClientTagsPost);
	Call_PushCell(client);
	Call_PushCell(index1);
	Call_PushString(tag1);
	Call_PushCell(index2);
	Call_PushString(tag2);
	Call_Finish();
	
	return true;
}

public int Native_SwapClientTags(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int size;
	
	GetNativeStringLength(2, size); size++;
	char[] sTag1 = new char[size];
	GetNativeString(2, sTag1, size);
	
	GetNativeStringLength(3, size); size++;
	char[] sTag2 = new char[size];
	GetNativeString(3, sTag2, size);
	
	return SwapClientTags(client, sTag1, sTag2);
}

bool StripClientTags(int client)
{
	if (g_Tags[client].Length == 0)
		return false;
	
	g_Tags[client].Clear();
	
	Call_StartForward(g_Forward_OnStripClientTagsPost);
	Call_PushCell(client);
	Call_Finish();
	
	return true;
}

public int Native_StripClientTags(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return StripClientTags(client);
}

bool SetTagColor(int client, const char[] tag, const char[] color)
{
	if (client == 0 || client > MaxClients || IsFakeClient(client))
		return false;
	
	bool found; char sTag[MAXLENGTH_NAME];
	for (int i = 0; i < g_Tags[client].Length; i++)
	{
		g_Tags[client].GetString(i, sTag, sizeof(sTag));
		
		if (StrContains(sTag, tag, false) == -1)
			continue;
			
		CRemoveColors(sTag, sizeof(sTag));
		Format(sTag, sizeof(sTag), "%s%s", color, sTag);
		
		g_Tags[client].SetString(i, sTag);
		
		Call_StartForward(g_Forward_OnSetTagColorPost);
		Call_PushCell(client);
		Call_PushCell(i);
		Call_PushString(tag);
		Call_PushString(color);
		Call_Finish();
		
		found = true;
	}
	
	return found;
}

public int Native_SetTagColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int size;
	
	GetNativeStringLength(2, size); size++;
	char[] sTag = new char[size];
	GetNativeString(2, sTag, size);
	
	GetNativeStringLength(3, size); size++;
	char[] sColor = new char[size];
	GetNativeString(3, sColor, size);
	
	return SetTagColor(client, sTag, sColor);
}

bool SetNameColor(int client, const char[] color)
{
	if (client == 0 || client > MaxClients || IsFakeClient(client))
		return false;
	
	strcopy(g_NameColor[client], MAXLENGTH_NAME, color);
	
	Call_StartForward(g_Forward_OnSetNameColorPost);
	Call_PushCell(client);
	Call_PushString(color);
	Call_Finish();
	
	return true;
}

public int Native_SetNameColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] sColor = new char[size];
	GetNativeString(2, sColor, size);
	
	return SetNameColor(client, sColor);
}

bool SetChatColor(int client, const char[] color)
{
	if (client == 0 || client > MaxClients || IsFakeClient(client))
		return false;
	
	strcopy(g_ChatColor[client], MAXLENGTH_NAME, color);
	
	Call_StartForward(g_Forward_OnSetChatColorPost);
	Call_PushCell(client);
	Call_PushString(color);
	Call_Finish();
	
	return true;
}

public int Native_SetChatColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] sColor = new char[size];
	GetNativeString(2, sColor, size);
	
	return SetChatColor(client, sColor);
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	bool changed;
	int size = g_Tags[author].Length;
	
	if (size > 0)
	{
		Format(name, MAXLENGTH_NAME, "%s%s", strlen(g_NameColor[author]) > 0 ? g_NameColor[author] : "{teamcolor}", name);
		
		char sTag[MAXLENGTH_NAME];
		for (int i = 0; i < size; i++)
		{
			g_Tags[author].GetString(i, sTag, sizeof(sTag));
			Format(name, MAXLENGTH_NAME, "%s%s", sTag, name);
		}
		
		changed = true;
	}
	else if (strlen(g_NameColor[author]) > 0)
	{
		Format(name, MAXLENGTH_NAME, "%s%s", g_NameColor[author], name);
		changed = true;
	}
	
	if (strlen(g_ChatColor[author]) > 0)
	{
		Format(message, MAXLENGTH_MESSAGE, "%s%s", g_ChatColor[author], message);
		changed = true;
	}
	
	return changed ? Plugin_Changed : Plugin_Continue;
}
