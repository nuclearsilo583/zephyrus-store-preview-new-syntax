#if defined _colorvariables_included
	#endinput
#endif
#define _colorvariables_included "1.3"

// Author: Raska aka KissLick
// Syntax update: Drixevel

// ----------------------------------------------------------------------------------------
#define _CV_MAX_MESSAGE_LENGTH 		1024
#define _CV_MAX_VARIABLE_REDIRECTS 	10
#define _CV_CONFIG_DIRECTORY 		"configs/colorvariables"

static bool g_bInit;
static StringMap g_hColors;
static char g_sConfigGlobal[PLATFORM_MAX_PATH];
static char g_sConfig[PLATFORM_MAX_PATH];
static char g_sChatPrefix[64];

static bool g_bIgnorePrefix;
static int g_author;
static bool g_bSkipPlayers[MAXPLAYERS + 1];

static GlobalForward g_hForwardedVariable;

// ----------------------------------------------------------------------------------------

forward void COnForwardedVariable(char[] sCode, char[] sData, int iDataSize, char[] sColor, int iColorSize);

stock void CSetPrefix(const char[] sPrefix, any ...)
{
	VFormat(g_sChatPrefix, sizeof(g_sChatPrefix), sPrefix, 2);
}

stock void CSavePrefix(const char[] sPrefix, any ...)
{
	char m_sPrefix[64];
	VFormat(m_sPrefix, sizeof(m_sPrefix), sPrefix, 2);

	CAddVariable("&prefix", m_sPrefix, true);
}

stock void CSkipNextPrefix()
{
	g_bIgnorePrefix = true;
}

stock void CSetNextAuthor(int client)
{
	if (client < 0 || client > MaxClients || !IsClientInGame(client)) {
		ThrowError("Invalid client index %i", client);
	}
	g_author = client;
}

stock void CSkipNextClient(int client)
{
	if (client < 0 || client > MaxClients) {
		ThrowError("Invalid client index %i", client);
	}
	g_bSkipPlayers[client] = true;
}

stock void CPrintToChat(int client, const char[] message, any ...)
{
	if (client < 0 || client > MaxClients) {
		ThrowError("Invalid client index %d", client);
	}

	if (!IsClientInGame(client)) {
		ThrowError("Client %d is not in game", client);
	}

	char sBuffer[_CV_MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	VFormat(sBuffer, sizeof(sBuffer), message, 3);

	AddPrefixAndDefaultColor(sBuffer, sizeof(sBuffer));
	g_bIgnorePrefix = false;

	CProcessVariables(sBuffer, sizeof(sBuffer));
	CAddWhiteSpace(sBuffer, sizeof(sBuffer));

	SendPlayerMessage(client, sBuffer, g_author);
	g_author = 0;
}

stock void CPrintToChatAll(const char[] message, any ...)
{
	char sBuffer[_CV_MAX_MESSAGE_LENGTH];

	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || g_bSkipPlayers[client]) {
			g_bSkipPlayers[client] = false;
			continue;
		}

		SetGlobalTransTarget(client);
		VFormat(sBuffer, sizeof(sBuffer), message, 2);

		AddPrefixAndDefaultColor(sBuffer, sizeof(sBuffer));
		g_bIgnorePrefix = false;

		CProcessVariables(sBuffer, sizeof(sBuffer));
		CAddWhiteSpace(sBuffer, sizeof(sBuffer));

		SendPlayerMessage(client, sBuffer, g_author);
	}
	g_author = 0;
}

stock void CPrintToChatTeam(int team, const char[] message, any ...)
{
	char sBuffer[_CV_MAX_MESSAGE_LENGTH];

	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || GetClientTeam(client) != team || g_bSkipPlayers[client]) {
			g_bSkipPlayers[client] = false;
			continue;
		}

		SetGlobalTransTarget(client);
		VFormat(sBuffer, sizeof(sBuffer), message, 3);

		AddPrefixAndDefaultColor(sBuffer, sizeof(sBuffer));
		g_bIgnorePrefix = false;

		CProcessVariables(sBuffer, sizeof(sBuffer));
		CAddWhiteSpace(sBuffer, sizeof(sBuffer));

		SendPlayerMessage(client, sBuffer, g_author);
	}
	g_author = 0;
}

stock void CPrintToChatAdmins(int iBitFlags, const char[] message, any ...)
{
	char sBuffer[_CV_MAX_MESSAGE_LENGTH];
	AdminId iAdminID;

	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || g_bSkipPlayers[client]) {
			g_bSkipPlayers[client] = false;
			continue;
		}

		iAdminID = GetUserAdmin(client);
		if (iAdminID == INVALID_ADMIN_ID || !(GetAdminFlags(iAdminID, Access_Effective) & iBitFlags)) {
			continue;
		}

		SetGlobalTransTarget(client);
		VFormat(sBuffer, sizeof(sBuffer), message, 3);

		AddPrefixAndDefaultColor(sBuffer, sizeof(sBuffer));
		g_bIgnorePrefix = false;

		CProcessVariables(sBuffer, sizeof(sBuffer));
		CAddWhiteSpace(sBuffer, sizeof(sBuffer));

		SendPlayerMessage(client, sBuffer, g_author);
	}
	g_author = 0;
}

stock void CReplyToCommand(int client, const char[] message, any ...)
{
	if (client < 0 || client > MaxClients) {
		ThrowError("Invalid client index %d", client);
	}

	if (client != 0 && !IsClientInGame(client)) {
		ThrowError("Client %d is not in game", client);
	}

	char sBuffer[_CV_MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	VFormat(sBuffer, sizeof(sBuffer), message, 3);

	AddPrefixAndDefaultColor(sBuffer, sizeof(sBuffer), "reply2cmd");
	g_bIgnorePrefix = false;

	if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE) {
		CRemoveColors(sBuffer, sizeof(sBuffer));
		PrintToConsole(client, "%s", sBuffer);
	} else {
		CPrintToChat(client, "%s", sBuffer);
	}
}

stock void CShowActivity(int client, const char[] message, any ...)
{
	if (client < 0 || client > MaxClients) {
		ThrowError("Invalid client index %d", client);
	}

	if (client != 0 && !IsClientInGame(client)) {
		ThrowError("Client %d is not in game", client);
	}

	char sBuffer[_CV_MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	VFormat(sBuffer, sizeof(sBuffer), message, 3);
	Format(sBuffer, sizeof(sBuffer), "{showactivity}%s", sBuffer);
	CProcessVariables(sBuffer, sizeof(sBuffer));
	CAddWhiteSpace(sBuffer, sizeof(sBuffer));

	ShowActivity(client, "%s", sBuffer);
}

stock void CShowActivityEx(int client, const char[] sTag, const char[] message, any ...)
{
	if (client < 0 || client > MaxClients) {
		ThrowError("Invalid client index %d", client);
	}

	if (client != 0 && !IsClientInGame(client)) {
		ThrowError("Client %d is not in game", client);
	}

	char sBuffer[_CV_MAX_MESSAGE_LENGTH]; char sBufferTag[_CV_MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	VFormat(sBuffer, sizeof(sBuffer), message, 4);
	Format(sBuffer, sizeof(sBuffer), "{showactivity}%s", sBuffer);
	CProcessVariables(sBuffer, sizeof(sBuffer));
	Format(sBufferTag, sizeof(sBufferTag), "{prefix}%s", sTag);
	CProcessVariables(sBufferTag, sizeof(sBufferTag));
	CAddWhiteSpace(sBuffer, sizeof(sBuffer));
	CAddWhiteSpace(sBufferTag, sizeof(sBufferTag));

	ShowActivityEx(client, sBufferTag, " %s", sBuffer);
}

stock void CShowActivity2(int client, const char[] sTag, const char[] message, any ...)
{
	if (client < 0 || client > MaxClients) {
		ThrowError("Invalid client index %d", client);
	}

	if (client != 0 && !IsClientInGame(client)) {
		ThrowError("Client %d is not in game", client);
	}

	char sBuffer[_CV_MAX_MESSAGE_LENGTH]; char sBufferTag[_CV_MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	VFormat(sBuffer, sizeof(sBuffer), message, 4);
	Format(sBuffer, sizeof(sBuffer), "{showactivity}%s", sBuffer);
	CProcessVariables(sBuffer, sizeof(sBuffer));
	Format(sBufferTag, sizeof(sBufferTag), "{prefix}%s", sTag);
	CProcessVariables(sBufferTag, sizeof(sBufferTag));
	CAddWhiteSpace(sBuffer, sizeof(sBuffer));
	CAddWhiteSpace(sBufferTag, sizeof(sBufferTag));

	ShowActivityEx(client, sBufferTag, " %s", sBuffer);
}

stock void CAddVariable(char[] sName, char[] sValue, bool bOnlySaveToConfig = false)
{
	if (!Init()) {
		return;
	}

	if (!FileExists(g_sConfig)) {
		ThrowError("Cannot add color variable to '%s' - file doesn't exist!", g_sConfig);
	}

	KeyValues hKV = new KeyValues("colorvariables");

	if (!hKV.ImportFromFile(g_sConfig)) {
		delete hKV;
		ThrowError("Cannot open file (for adding color variable) '%s' !", g_sConfig);
	}

	if (!hKV.JumpToKey(sName)) {
		StringToLower(sName);
		hKV.SetString(sName, sValue);

		if (!bOnlySaveToConfig) {
			ArrayList hRedirect = new ArrayList(64);
			hRedirect.PushString(sName);
			g_hColors.SetString(sName, sValue);
			SolveRedirects(g_hColors, hRedirect);
			delete hRedirect;
		}
	}

	hKV.Rewind();
	hKV.ExportToFile(g_sConfig);
	delete hKV;
}

stock void CLoadPluginConfig(const char[] sPluginName, bool bAllowPrefix = true)
{
	if (Init()) {
		char sConfig[PLATFORM_MAX_PATH];
		strcopy(sConfig, sizeof(sConfig), sPluginName);
		ReplaceStringEx(sConfig, sizeof(sConfig), ".smx", "");
		BuildPath(Path_SM, sConfig, sizeof(sConfig), "%s/plugin.%s.cfg", _CV_CONFIG_DIRECTORY, sConfig);

		if (!FileExists(sConfig)) {
			LogError("Cannot load color variables from file '%s' - file doesn't exist!", sConfig);
			return;
		}

		ArrayList hRedirect = new ArrayList(64);
		LoadConfigFile(g_hColors, sConfig, hRedirect, bAllowPrefix);
		SolveRedirects(g_hColors, hRedirect);
		delete hRedirect;
	}
}

stock void CLoadPluginVariables(const char[] sPluginName, const char[][] sVariables, int iVariablesCount, bool bAllowPrefix = true)
{
	if (Init() && iVariablesCount > 0) {
		char sConfig[PLATFORM_MAX_PATH];
		strcopy(sConfig, sizeof(sConfig), sPluginName);
		ReplaceStringEx(sConfig, sizeof(sConfig), ".smx", "");
		BuildPath(Path_SM, sConfig, sizeof(sConfig), "%s/plugin.%s.cfg", _CV_CONFIG_DIRECTORY, sConfig);

		if (!FileExists(sConfig)) {
			LogError("Cannot load color variables from file '%s' - file doesn't exist!", sConfig);
			return;
		}

		StringMap hVariables = new StringMap();
		ArrayList hRedirect = new ArrayList(64);
		LoadConfigFile(hVariables, sConfig, hRedirect, bAllowPrefix);
		SolveRedirects(hVariables, hRedirect);
		hRedirect.Clear();

		char sCode[64]; char sColor[64];

		for (int i = 0; i < iVariablesCount; i++) {
			strcopy(sCode, sizeof(sCode), sVariables[i]);
			StringToLower(sCode);

			if (hVariables.GetString(sCode, sColor, sizeof(sColor))) {
				g_hColors.SetString(sCode, sColor);
				hRedirect.PushString(sCode);
			}
		}

		SolveRedirects(g_hColors, hRedirect);

		delete hRedirect;
		delete hVariables;
	}
}

stock void CRemoveColors(char[] sMsg, int iSize)
{
	CProcessVariables(sMsg, iSize, true);
}

stock void CProcessVariables(char[] sMsg, int iSize, bool bRemoveColors = false)
{
	if (!Init()) {
		return;
	}

	char[] sOut = new char[iSize]; char[] sCode = new char[iSize]; char[] sColor = new char[iSize];
	int iOutPos = 0; int iCodePos = -1;
	int iMsgLen = strlen(sMsg);

	for (int i = 0; i < iMsgLen; i++) {
		if (sMsg[i] == '{') {
			iCodePos = 0;
		}

		if (iCodePos > -1) {
			sCode[iCodePos] = sMsg[i];
			sCode[iCodePos + 1] = '\0';

			if (sMsg[i] == '}' || i == iMsgLen - 1) {
				strcopy(sCode, strlen(sCode) - 1, sCode[1]);
				StringToLower(sCode);

				if (CGetColor(sCode, sColor, iSize)) {
					if (!bRemoveColors) {
						StrCat(sOut, iSize, sColor);
						iOutPos += strlen(sColor);
					}
				} else {
					Format(sOut, iSize, "%s{%s}", sOut, sCode);
					iOutPos += strlen(sCode) + 2;
				}

				iCodePos = -1;
				strcopy(sCode, iSize, "");
				strcopy(sColor, iSize, "");
			} else {
				iCodePos++;
			}

			continue;
		}

		sOut[iOutPos] = sMsg[i];
		iOutPos++;
		sOut[iOutPos] = '\0';
	}

	strcopy(sMsg, iSize, sOut);
}

stock bool CGetColor(const char[] sName, char[] sColor, int iColorSize)
{
	if (sName[0] == '\0')
		return false;

	if (sName[0] == '@') {
		int iSpace;
		char sData[64]; char m_sName[64];
		strcopy(m_sName, sizeof(m_sName), sName[1]);

		if ((iSpace = FindCharInString(m_sName, ' ')) != -1 && (iSpace + 1 < strlen(m_sName))) {
			strcopy(m_sName, iSpace + 1, m_sName);
			strcopy(sData, sizeof(sData), m_sName[iSpace + 1]);
		}

		Call_StartForward(g_hForwardedVariable);
		Call_PushString(m_sName);
		Call_PushStringEx(sData, sizeof(sData), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, 0);
		Call_PushCell(sizeof(sData));
		Call_PushStringEx(sColor, iColorSize, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCell(iColorSize);
		Call_Finish();

		if (sColor[0] != '\0') {
			return true;
		}

	} else if (sName[0] == '#') {
		if (strlen(sName) == 7) {
			Format(sColor, iColorSize, "\x07%s", sName[1]);
			return true;
		}
		if (strlen(sName) == 9) {
			Format(sColor, iColorSize, "\x08%s", sName[1]);
			return true;
		}
	} else if (StrContains(sName, "player ", false) == 0 && strlen(sName) > 7) {
		int client = StringToInt(sName[7]);

		if (client < 0 || client > MaxClients || !IsClientInGame(client)) {
			strcopy(sColor, iColorSize, "\x01");
			LogError("Invalid client index %d", client);
			return false;
		}

		strcopy(sColor, iColorSize, "\x01");
		switch (GetClientTeam(client)) {
			case 1: {
				g_hColors.GetString("team0", sColor, iColorSize);
			}
			case 2: {
				g_hColors.GetString("team1", sColor, iColorSize);
			}
			case 3: {
				g_hColors.GetString("team2", sColor, iColorSize);
			}
		}
		return true;
	} else {
		return g_hColors.GetString(sName, sColor, iColorSize);
	}

	return false;
}

stock bool CExistColor(const char[] sName)
{
	if (sName[0] == '\0' || sName[0] == '@' || sName[0] == '#')
		return false;

	char sColor[64];
	return g_hColors.GetString(sName, sColor, sizeof(sColor));
}

stock void CAddWhiteSpace(char[] sBuffer, int iSize)
{
	EngineVersion iEngineVersion = GetEngineVersion();

	if (!SupportsColorCodes() && !(iEngineVersion == Engine_Left4Dead) && !(iEngineVersion == Engine_Left4Dead2)) {
		Format(sBuffer, iSize, " %s", sBuffer);
	}
}

// ----------------------------------------------------------------------------------------
// Private stuff
// ----------------------------------------------------------------------------------------

stock bool Init()
{
	if (g_bInit) {
		LoadColors();
		return true;
	}

	char sPluginName[PLATFORM_MAX_PATH];
	char sDirectoryPath[PLATFORM_MAX_PATH];
	Handle hConfig;
	GetPluginFilename(null, sPluginName, sizeof(sPluginName));
	ReplaceStringEx(sPluginName, sizeof(sPluginName), "\\", "/");
	int iSlash = FindCharInString(sPluginName, '/', true);
	if (iSlash > -1) {
		strcopy(sPluginName, sizeof(sPluginName), sPluginName[iSlash + 1]);
	}
	ReplaceStringEx(sPluginName, sizeof(sPluginName), ".smx", "");

	BuildPath(Path_SM, sDirectoryPath, sizeof(sDirectoryPath), "%s/", _CV_CONFIG_DIRECTORY);
	if (!DirExists(sDirectoryPath))
		CreateDirectory(sDirectoryPath, 511);

	char sGlobalVariableList[15][2][64] = {
		{"prefix", 		 "{engine 2}"},
		{"default",		 "{engine 1}"},
		{"reply2cmd",  	 "{engine 1}"},
		{"showactivity", "{engine 1}"},
		{"", ""},
		{"error",		 "{engine 3}"},
		{"", ""},
		{"highlight",	 "{engine 2}"},
		{"player",		 "{engine 2}"},
		{"settings",	 "{engine 2}"},
		{"command",		 "{engine 2}"},
		{"", ""},
		{"team0",		 "{engine 8}"},
		{"team1",		 "{engine 9}"},
		{"team2",		 "{engine 11}"}
	};

	if (SupportsColorCodes()) {
		strcopy(sGlobalVariableList[12][1], 64, "{#cccccc}");
		strcopy(sGlobalVariableList[13][1], 64, "{#ff4040}");
		strcopy(sGlobalVariableList[14][1], 64, "{#4d7942}");
	}

	BuildPath(Path_SM, g_sConfigGlobal, sizeof(g_sConfigGlobal), "%s/global.cfg", _CV_CONFIG_DIRECTORY);
	if (!FileExists(g_sConfigGlobal)) {
		hConfig = OpenFile(g_sConfigGlobal, "w");
		if (hConfig == null) {
			LogError("Cannot create file '%s' !", g_sConfigGlobal);
			return false;
		}

		WriteFileLine(hConfig, "// Version: %s", _colorvariables_included);
		WriteFileLine(hConfig, "\"colorvariables\"");
		WriteFileLine(hConfig, "{");
		for (int i = 0; i < 15; i++) {
			if (sGlobalVariableList[i][0][0] == '\0') {
				WriteFileLine(hConfig, "");
			} else {
				WriteFileLine(hConfig, "\t\"%s\" \"%s\"", sGlobalVariableList[i][0], sGlobalVariableList[i][1]);
			}
		}
		WriteFileLine(hConfig, "}");

		delete hConfig;
	} else {
		hConfig = OpenFile(g_sConfigGlobal, "r");
		if (hConfig == null) {
			LogError("Cannot read from file '%s' !", g_sConfigGlobal);
			return false;
		}

		char sVersionLine[64];
		ReadFileLine(hConfig, sVersionLine, sizeof(sVersionLine));
		delete hConfig;

		TrimString(sVersionLine);
		strcopy(sVersionLine, sizeof(sVersionLine), sVersionLine[FindCharInString(sVersionLine, ':') + 2]);

		if (StringToFloat(sVersionLine) < StringToFloat(_colorvariables_included)) {
			KeyValues hKV = new KeyValues("colorvariables");

			if (!hKV.ImportFromFile(g_sConfigGlobal) || !hKV.GotoFirstSubKey(false)) {
				delete hKV;
				LogError("Cannot read variables from file '%s' !", g_sConfigGlobal);
				return false;
			}

			for (int i = 0; i < 15; i++) {
				if (sGlobalVariableList[i][0][0] == '\0')
					continue;

				if (!hKV.JumpToKey(sGlobalVariableList[i][0]))
					hKV.SetString(sGlobalVariableList[i][0], sGlobalVariableList[i][1]);
			}

			hConfig = OpenFile(g_sConfigGlobal, "w");
			if (hConfig == null) {
				LogError("Cannot write to file '%s' !", g_sConfigGlobal);
				return false;
			}

			WriteFileLine(hConfig, "// Version: %s", _colorvariables_included);
			WriteFileLine(hConfig, "\"colorvariables\"");
			WriteFileLine(hConfig, "{");

			char sCode[64]; char sColor[64];

			hKV.GotoFirstSubKey(false);
			do
			{
				hKV.GetSectionName(sCode, sizeof(sCode));
				hKV.GetString(NULL_STRING, sColor, sizeof(sColor));
				StringToLower(sCode);
				StringToLower(sColor);

				WriteFileLine(hConfig, "\t\"%s\" \"%s\"", sCode, sColor);
			} while (KvGotoNextKey(hKV, false));

			WriteFileLine(hConfig, "}");
			
			delete hConfig;
			delete hKV;
		}
	}

	BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "%s/plugin.%s.cfg", _CV_CONFIG_DIRECTORY, sPluginName);
	if (!FileExists(g_sConfig)) {
		hConfig = OpenFile(g_sConfig, "w");
		if (hConfig == null) {
			LogError("Cannot create file '%s' !", g_sConfig);
			return false;
		}

		WriteFileLine(hConfig, "\"colorvariables\"\n{\n}");
		delete hConfig;
	}

	for (int client = 1; client <= MaxClients; client++) {
		g_bSkipPlayers[client] = false;
	}

	g_hForwardedVariable = new GlobalForward("COnForwardedVariable", ET_Ignore, Param_String, Param_String, Param_Cell, Param_String, Param_Cell);

	LoadColors();
	g_bInit = true;
	return true;
}

stock void LoadColors()
{
	if (g_hColors == null) {
		g_hColors = new StringMap();
		ArrayList hRedirect = new ArrayList(64);

		AddColors(g_hColors);
		LoadConfigFile(g_hColors, g_sConfigGlobal, hRedirect);
		LoadConfigFile(g_hColors, g_sConfig, hRedirect);

		SolveRedirects(g_hColors, hRedirect);
		delete hRedirect;
	}
}

stock void LoadConfigFile(StringMap hTrie, char[] sPath, ArrayList hRedirect, bool bAllowPrefix = true)
{
	if (!FileExists(sPath)) {
		LogError("Cannot load color variables from file '%s' - file doesn't exist!", sPath);
		return;
	}

	KeyValues hKV = new KeyValues("colorvariables");

	if (!hKV.ImportFromFile(sPath)) {
		delete hKV;
		LogError("Cannot load color variables from file '%s' !", sPath);
		return;
	}

	if (!hKV.GotoFirstSubKey(false)) {
		delete hKV;
		return;
	}

	char sCode[64]; char sColor[64];

	do
	{
		hKV.GetSectionName(sCode, sizeof(sCode));
		hKV.GetString(NULL_STRING, sColor, sizeof(sColor));

		if (bAllowPrefix && StrEqual(sCode, "&prefix", false)) {
			CSetPrefix(sColor);
			continue;
		}

		StringToLower(sCode);

		if (HasBrackets(sColor) && sColor[1] == '@') {
			LogError("Variables cannot be redirected to forwarded variables! (variable '%s')", sCode);
			continue;
		}

		if (HasBrackets(sColor)) {
			if (sColor[1] == '#') {
				Format(sColor, sizeof(sColor), "\x07%s", sColor[1]);
			} else {
				hRedirect.PushString(sCode);
			}
		}

		hTrie.SetString(sCode, sColor);
	} while (KvGotoNextKey(hKV, false));

	delete hKV;
}

stock void SolveRedirects(StringMap hTrie, ArrayList hRedirect)
{
	char sCode[64]; char sRedirect[64]; char sColor[64]; char sFirstColor[64];
	int iRedirectLife; bool bHasBrackets;

	for (int i = 0; i < hRedirect.Length; i++) {
		hRedirect.GetString(i, sRedirect, sizeof(sRedirect));
		strcopy(sCode, sizeof(sCode), sRedirect);
		bHasBrackets = true;

		GetTrieString(hTrie, sRedirect, sColor, sizeof(sColor));
		strcopy(sFirstColor, sizeof(sFirstColor), sRedirect);
		iRedirectLife = _CV_MAX_VARIABLE_REDIRECTS;

		do {
			if (!HasBrackets(sColor)) {
				strcopy(sRedirect, sizeof(sRedirect), sColor);
				bHasBrackets = false;
				break;
			}

			strcopy(sColor, strlen(sColor) - 1, sColor[1]);
			if (iRedirectLife > 0) {
				strcopy(sRedirect, sizeof(sRedirect), sColor);
				iRedirectLife--;
			} else {
				strcopy(sRedirect, sizeof(sRedirect), sFirstColor);
				LogError("Too many redirects for variable '%s' !", sCode);
				break;
			}
		} while (GetTrieString(hTrie, sRedirect, sColor, sizeof(sColor)));

		if (bHasBrackets) {
			Format(sRedirect, sizeof(sRedirect), "{%s}", sRedirect);
		}

		StringToLower(sCode);
		StringToLower(sRedirect);
		hTrie.SetString(sCode, sRedirect);
	}
}

stock bool HasBrackets(const char[] sSource)
{
	return (sSource[0] == '{' && sSource[strlen(sSource) - 1] == '}');
}

stock void StringToLower(char[] sSource)
{
	for (int i = 0; i < strlen(sSource); i++) {
		if (sSource[i] == '\0')
			break;

		sSource[i] = CharToLower(sSource[i]);
	}
}

stock void AddColors(StringMap hTrie)
{
	hTrie.SetString("default", "\x01");       // "\x01" "{default}"
	hTrie.SetString("teamcolor", "\x03");     // "\x03" "{lightgreen}" "\x03" "{orange}" "\x03" "{blue}" "\x03" "{purple}"

	if (SupportsColorCodes()) {
		hTrie.SetString("aliceblue", "\x07F0F8FF");
		hTrie.SetString("allies", "\x074D7942");
		hTrie.SetString("ancient", "\x07EB4B4B");
		hTrie.SetString("antiquewhite", "\x07FAEBD7");
		hTrie.SetString("aqua", "\x0700FFFF");
		hTrie.SetString("aquamarine", "\x077FFFD4");
		hTrie.SetString("arcana", "\x07ADE55C");
		hTrie.SetString("axis", "\x07FF4040");
		hTrie.SetString("azure", "\x07007FFF");
		hTrie.SetString("beige", "\x07F5F5DC");
		hTrie.SetString("bisque", "\x07FFE4C4");
		hTrie.SetString("black", "\x07000000");
		hTrie.SetString("blanchedalmond", "\x07FFEBCD");
		hTrie.SetString("blue", "\x0799CCFF");
		hTrie.SetString("blueviolet", "\x078A2BE2");
		hTrie.SetString("brown", "\x07A52A2A");
		hTrie.SetString("burlywood", "\x07DEB887");
		hTrie.SetString("cadetblue", "\x075F9EA0");
		hTrie.SetString("chartreuse", "\x077FFF00");
		hTrie.SetString("chocolate", "\x07D2691E");
		hTrie.SetString("collectors", "\x07AA0000");
		hTrie.SetString("common", "\x07B0C3D9");
		hTrie.SetString("community", "\x0770B04A");
		hTrie.SetString("coral", "\x07FF7F50");
		hTrie.SetString("cornflowerblue", "\x076495ED");
		hTrie.SetString("cornsilk", "\x07FFF8DC");
		hTrie.SetString("corrupted", "\x07A32C2E");
		hTrie.SetString("crimson", "\x07DC143C");
		hTrie.SetString("cyan", "\x0700FFFF");
		hTrie.SetString("darkblue", "\x0700008B");
		hTrie.SetString("darkcyan", "\x07008B8B");
		hTrie.SetString("darkgoldenrod", "\x07B8860B");
		hTrie.SetString("darkgray", "\x07A9A9A9");
		hTrie.SetString("darkgrey", "\x07A9A9A9");
		hTrie.SetString("darkgreen", "\x07006400");
		hTrie.SetString("darkkhaki", "\x07BDB76B");
		hTrie.SetString("darkmagenta", "\x078B008B");
		hTrie.SetString("darkolivegreen", "\x07556B2F");
		hTrie.SetString("darkorange", "\x07FF8C00");
		hTrie.SetString("darkorchid", "\x079932CC");
		hTrie.SetString("darkred", "\x078B0000");
		hTrie.SetString("darksalmon", "\x07E9967A");
		hTrie.SetString("darkseagreen", "\x078FBC8F");
		hTrie.SetString("darkslateblue", "\x07483D8B");
		hTrie.SetString("darkslategray", "\x072F4F4F");
		hTrie.SetString("darkslategrey", "\x072F4F4F");
		hTrie.SetString("darkturquoise", "\x0700CED1");
		hTrie.SetString("darkviolet", "\x079400D3");
		hTrie.SetString("deeppink", "\x07FF1493");
		hTrie.SetString("deepskyblue", "\x0700BFFF");
		hTrie.SetString("dimgray", "\x07696969");
		hTrie.SetString("dimgrey", "\x07696969");
		hTrie.SetString("dodgerblue", "\x071E90FF");
		hTrie.SetString("exalted", "\x07CCCCCD");
		hTrie.SetString("firebrick", "\x07B22222");
		hTrie.SetString("floralwhite", "\x07FFFAF0");
		hTrie.SetString("forestgreen", "\x07228B22");
		hTrie.SetString("frozen", "\x074983B3");
		hTrie.SetString("fuchsia", "\x07FF00FF");
		hTrie.SetString("fullblue", "\x070000FF");
		hTrie.SetString("fullred", "\x07FF0000");
		hTrie.SetString("gainsboro", "\x07DCDCDC");
		hTrie.SetString("genuine", "\x074D7455");
		hTrie.SetString("ghostwhite", "\x07F8F8FF");
		hTrie.SetString("gold", "\x07FFD700");
		hTrie.SetString("goldenrod", "\x07DAA520");
		hTrie.SetString("gray", "\x07CCCCCC");
		hTrie.SetString("grey", "\x07CCCCCC");
		hTrie.SetString("green", "\x073EFF3E");
		hTrie.SetString("greenyellow", "\x07ADFF2F");
		hTrie.SetString("haunted", "\x0738F3AB");
		hTrie.SetString("honeydew", "\x07F0FFF0");
		hTrie.SetString("hotpink", "\x07FF69B4");
		hTrie.SetString("immortal", "\x07E4AE33");
		hTrie.SetString("indianred", "\x07CD5C5C");
		hTrie.SetString("indigo", "\x074B0082");
		hTrie.SetString("ivory", "\x07FFFFF0");
		hTrie.SetString("khaki", "\x07F0E68C");
		hTrie.SetString("lavender", "\x07E6E6FA");
		hTrie.SetString("lavenderblush", "\x07FFF0F5");
		hTrie.SetString("lawngreen", "\x077CFC00");
		hTrie.SetString("legendary", "\x07D32CE6");
		hTrie.SetString("lemonchiffon", "\x07FFFACD");
		hTrie.SetString("lightblue", "\x07ADD8E6");
		hTrie.SetString("lightcoral", "\x07F08080");
		hTrie.SetString("lightcyan", "\x07E0FFFF");
		hTrie.SetString("lightgoldenrodyellow", "\x07FAFAD2");
		hTrie.SetString("lightgray", "\x07D3D3D3");
		hTrie.SetString("lightgrey", "\x07D3D3D3");
		hTrie.SetString("lightgreen", "\x0799FF99");
		hTrie.SetString("lightpink", "\x07FFB6C1");
		hTrie.SetString("lightsalmon", "\x07FFA07A");
		hTrie.SetString("lightseagreen", "\x0720B2AA");
		hTrie.SetString("lightskyblue", "\x0787CEFA");
		hTrie.SetString("lightslategray", "\x07778899");
		hTrie.SetString("lightslategrey", "\x07778899");
		hTrie.SetString("lightsteelblue", "\x07B0C4DE");
		hTrie.SetString("lightyellow", "\x07FFFFE0");
		hTrie.SetString("lime", "\x0700FF00");
		hTrie.SetString("limegreen", "\x0732CD32");
		hTrie.SetString("linen", "\x07FAF0E6");
		hTrie.SetString("magenta", "\x07FF00FF");
		hTrie.SetString("maroon", "\x07800000");
		hTrie.SetString("mediumaquamarine", "\x0766CDAA");
		hTrie.SetString("mediumblue", "\x070000CD");
		hTrie.SetString("mediumorchid", "\x07BA55D3");
		hTrie.SetString("mediumpurple", "\x079370D8");
		hTrie.SetString("mediumseagreen", "\x073CB371");
		hTrie.SetString("mediumslateblue", "\x077B68EE");
		hTrie.SetString("mediumspringgreen", "\x0700FA9A");
		hTrie.SetString("mediumturquoise", "\x0748D1CC");
		hTrie.SetString("mediumvioletred", "\x07C71585");
		hTrie.SetString("midnightblue", "\x07191970");
		hTrie.SetString("mintcream", "\x07F5FFFA");
		hTrie.SetString("mistyrose", "\x07FFE4E1");
		hTrie.SetString("moccasin", "\x07FFE4B5");
		hTrie.SetString("mythical", "\x078847FF");
		hTrie.SetString("navajowhite", "\x07FFDEAD");
		hTrie.SetString("navy", "\x07000080");
		hTrie.SetString("normal", "\x07B2B2B2");
		hTrie.SetString("oldlace", "\x07FDF5E6");
		hTrie.SetString("olive", "\x079EC34F");
		hTrie.SetString("olivedrab", "\x076B8E23");
		hTrie.SetString("orange", "\x07FFA500");
		hTrie.SetString("orangered", "\x07FF4500");
		hTrie.SetString("orchid", "\x07DA70D6");
		hTrie.SetString("palegoldenrod", "\x07EEE8AA");
		hTrie.SetString("palegreen", "\x0798FB98");
		hTrie.SetString("paleturquoise", "\x07AFEEEE");
		hTrie.SetString("palevioletred", "\x07D87093");
		hTrie.SetString("papayawhip", "\x07FFEFD5");
		hTrie.SetString("peachpuff", "\x07FFDAB9");
		hTrie.SetString("peru", "\x07CD853F");
		hTrie.SetString("pink", "\x07FFC0CB");
		hTrie.SetString("plum", "\x07DDA0DD");
		hTrie.SetString("powderblue", "\x07B0E0E6");
		hTrie.SetString("purple", "\x07800080");
		hTrie.SetString("rare", "\x074B69FF");
		hTrie.SetString("red", "\x07FF4040");
		hTrie.SetString("rosybrown", "\x07BC8F8F");
		hTrie.SetString("royalblue", "\x074169E1");
		hTrie.SetString("saddlebrown", "\x078B4513");
		hTrie.SetString("salmon", "\x07FA8072");
		hTrie.SetString("sandybrown", "\x07F4A460");
		hTrie.SetString("seagreen", "\x072E8B57");
		hTrie.SetString("seashell", "\x07FFF5EE");
		hTrie.SetString("selfmade", "\x0770B04A");
		hTrie.SetString("sienna", "\x07A0522D");
		hTrie.SetString("silver", "\x07C0C0C0");
		hTrie.SetString("skyblue", "\x0787CEEB");
		hTrie.SetString("slateblue", "\x076A5ACD");
		hTrie.SetString("slategray", "\x07708090");
		hTrie.SetString("slategrey", "\x07708090");
		hTrie.SetString("snow", "\x07FFFAFA");
		hTrie.SetString("springgreen", "\x0700FF7F");
		hTrie.SetString("steelblue", "\x074682B4");
		hTrie.SetString("strange", "\x07CF6A32");
		hTrie.SetString("tan", "\x07D2B48C");
		hTrie.SetString("teal", "\x07008080");
		hTrie.SetString("thistle", "\x07D8BFD8");
		hTrie.SetString("tomato", "\x07FF6347");
		hTrie.SetString("turquoise", "\x0740E0D0");
		hTrie.SetString("uncommon", "\x07B0C3D9");
		hTrie.SetString("unique", "\x07FFD700");
		hTrie.SetString("unusual", "\x078650AC");
		hTrie.SetString("valve", "\x07A50F79");
		hTrie.SetString("vintage", "\x07476291");
		hTrie.SetString("violet", "\x07EE82EE");
		hTrie.SetString("wheat", "\x07F5DEB3");
		hTrie.SetString("white", "\x07FFFFFF");
		hTrie.SetString("whitesmoke", "\x07F5F5F5");
		hTrie.SetString("yellow", "\x07FFFF00");
		hTrie.SetString("yellowgreen", "\x079ACD32");
	} else {
		hTrie.SetString("red", "\x07");           // "\x07" "{red}"
		hTrie.SetString("lightred", "\x0F");      // "\x0F" "{lightred}"
		hTrie.SetString("darkred", "\x02");       // "\x02" "{darkred}"
		hTrie.SetString("bluegrey", "\x0A");      // "\x0A" "{lightblue}"
		hTrie.SetString("blue", "\x0B");          // "\x0B" "{steelblue}"
		hTrie.SetString("darkblue", "\x0C");      // "\x0C" "{darkblue}"
		hTrie.SetString("purple", "\x03");
		hTrie.SetString("orchid", "\x0E");        // "\x0E" "{pink}"
		hTrie.SetString("yellow", "\x09");        // "\x09" "{yellow}"
		hTrie.SetString("gold", "\x10");
		hTrie.SetString("lightgreen", "\x05");    // "\x05" "{olive}"
		hTrie.SetString("green", "\x04");         // "\x04" "{green}"
		hTrie.SetString("lime", "\x06");          // "\x06" "{lime}"
		hTrie.SetString("grey", "\x08");          // "\x08" "{grey}"
		hTrie.SetString("grey2", "\x0D");

		// Additional color names for ckSurf backwards compatibility
		hTrie.SetString("bluegray", "\x0A"); // using bluegrey
		hTrie.SetString("gray", "\x08"); // using gray
		hTrie.SetString("gray2", "\x0D"); // using gray2
		hTrie.SetString("orange", "\x10"); // using gold
		hTrie.SetString("steelblue", "\x0D"); // using grey2
		hTrie.SetString("pink", "\x0E"); // using orchid
		hTrie.SetString("lightblue", "\x0A"); // using bluegrey
		hTrie.SetString("olive", "\x05"); // using lightgreen
	}

	hTrie.SetString("engine 1", "\x01");
	hTrie.SetString("engine 2", "\x02");
	hTrie.SetString("engine 3", "\x03");
	hTrie.SetString("engine 4", "\x04");
	hTrie.SetString("engine 5", "\x05");
	hTrie.SetString("engine 6", "\x06");
	hTrie.SetString("engine 7", "\x07");
	hTrie.SetString("engine 8", "\x08");
	hTrie.SetString("engine 9", "\x09");
	hTrie.SetString("engine 10", "\x0A");
	hTrie.SetString("engine 11", "\x0B");
	hTrie.SetString("engine 12", "\x0C");
	hTrie.SetString("engine 13", "\x0D");
	hTrie.SetString("engine 14", "\x0E");
	hTrie.SetString("engine 15", "\x0F");
	hTrie.SetString("engine 16", "\x10");
}

stock bool SupportsColorCodes()
{
	EngineVersion iEngineVersion = GetEngineVersion();
	bool g_SupportsColorCodes = (iEngineVersion == Engine_CSS || iEngineVersion == Engine_TF2 || iEngineVersion == Engine_HL2DM || iEngineVersion == Engine_DODS) ? true : false;
	return g_SupportsColorCodes;
}

stock void AddPrefixAndDefaultColor(char[] message, int iSize, char[] sDefaultColor = "default", char[] sPrefixColor = "prefix")
{
	if (g_sChatPrefix[0] != '\0' && !g_bIgnorePrefix) {
		Format(message, iSize, "{%s}[%s]{%s} %s", sPrefixColor, g_sChatPrefix, sDefaultColor, message);
	} else {
		Format(message, iSize, "{%s}%s", sDefaultColor, message);
	}
}

stock void SendPlayerMessage(int client, char[] message, int author  = 0)
{
	if (author < 1 || author > MaxClients || !IsClientInGame(author)) {
		PrintToChat(client, message);
	} else {
		CSayText2(client, message, author);
	}
}

stock void CSayText2(int client, char[] message, int author, bool bChat = true)
{
	Handle hMsg = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) {
		PbSetInt(hMsg, "ent_idx", author);
		PbSetBool(hMsg, "chat", bChat);
		PbSetString(hMsg, "msg_name", message);
		PbAddString(hMsg, "params", "");
		PbAddString(hMsg, "params", "");
		PbAddString(hMsg, "params", "");
		PbAddString(hMsg, "params", "");
	} else {
		BfWriteByte(hMsg, author);
		BfWriteByte(hMsg, true);
		BfWriteString(hMsg, message);
	}
	EndMessage();
}