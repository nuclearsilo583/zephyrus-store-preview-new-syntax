#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <store>
#include <zephstocks>
#include <multicolors>

bool GAME_TF2 = false;


int g_cvarTracerMaterial = -1;
int g_cvarTracerLife = -1;
int g_cvarTracerWidth = -1;

int g_aColors[STORE_MAX_ITEMS][4];
bool g_bRandom[STORE_MAX_ITEMS];

int g_iColors = 0;
int g_iBeam = -1;

bool g_bHide[MAXPLAYERS + 1];
Cookie g_hHideCookie;

char g_sChatPrefix[128];

public Plugin myinfo = 
{
	name = "Store - Tracers Module",
	author = "nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.3", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{	

	// TF2 is unsupported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;

	if(GAME_TF2)
		return;

	g_cvarTracerMaterial = RegisterConVar("sm_store_tracer_material", "materials/sprites/laserbeam.vmt", "Material to be used with tracers", TYPE_STRING);
	g_cvarTracerLife = RegisterConVar("sm_store_tracer_life", "0.5", "Life of a tracer in seconds", TYPE_FLOAT);
	g_cvarTracerWidth = RegisterConVar("sm_store_tracer_width", "1.0", "Life of a tracer in seconds", TYPE_FLOAT);
	
	Store_RegisterHandler("tracer", "color", Tracers_OnMapStart, Tracers_Reset, Tracers_Config, Tracers_Equip, Tracers_Remove, true);
	
	AutoExecConfig(true, "plugin.store");
	
	LoadTranslations("store.phrases");
	
	HookEvent("bullet_impact", Tracers_BulletImpact);
	
	RegConsoleCmd("sm_hidetracer", Command_Hide, "Hide the Tracer");
	
	g_hHideCookie = new Cookie("Hide_Tracer", "Hide Tracer", CookieAccess_Protected);
	
	SetCookieMenuItem(PrefMenu, 0, "");
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		if (g_bHide[client])
			FormatEx(buffer, maxlen, "%T", "Show bullet tracer", client);
		else
			FormatEx(buffer, maxlen, "%T", "Hide bullet tracer", client);
	}

	if (actions == CookieMenuAction_SelectOption)
	{
		Command_Hide(client, 0);
		ShowCookieMenu(client);
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[4];
	g_hHideCookie.Get(client, sValue, sizeof(sValue));

	if (sValue[0] == '\0' || sValue[0] == '0')
		g_bHide[client] = false;
	else
		g_bHide[client] = true;
}

Action Command_Hide(int client, int args)
{
	g_bHide[client] = !g_bHide[client];
	if (g_bHide[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "tracer");
		g_hHideCookie.Set(client, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "tracer");
		g_hHideCookie.Set(client, "0");
	}

	return Plugin_Handled;
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Tracers_OnMapStart()
{
	g_iBeam = PrecacheModel2(g_eCvars[g_cvarTracerMaterial].sCache, true);
}

public void Tracers_Reset()
{
	g_iColors = 0;
}

public bool Tracers_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iColors);

	KvGetColor(kv, "color", g_aColors[g_iColors][0], g_aColors[g_iColors][1], g_aColors[g_iColors][2], g_aColors[g_iColors][3]);
	if(g_aColors[g_iColors][3]==0)
		g_aColors[g_iColors][3] = 255;
	g_bRandom[g_iColors] = KvGetNum(kv, "rainbow", 0)?true:false;
	
	++g_iColors;
	
	return true;
}

public int Tracers_Equip(int client,int id)
{
	return 0;
}

public int Tracers_Remove(int client,int id)
{
	return 0;
}

public Action Tracers_BulletImpact(Handle event,const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int m_iEquipped = Store_GetEquippedItem(client, "tracer");
	
	int[] clients = new int[MaxClients + 1];
	int numClients = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (g_bHide[i])
			continue;

		clients[numClients] = i;
		numClients++;
	}
	
	if (numClients < 1)
		return Plugin_Handled;
	
	if(m_iEquipped >= 0)
	{
		int idx = Store_GetDataIndex(m_iEquipped);

		while(g_bRandom[idx]) idx = GetRandomInt(0, g_iColors);
	
		float m_fOrigin[3], m_fImpact[3];

		GetClientEyePosition(client, m_fOrigin);
		m_fImpact[0] = GetEventFloat(event, "x");
		m_fImpact[1] = GetEventFloat(event, "y");
		m_fImpact[2] = GetEventFloat(event, "z");
		
		TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iBeam, 0, 0, 0, 
							view_as<float>(g_eCvars[g_cvarTracerLife].aCache), 
							view_as<float>(g_eCvars[g_cvarTracerWidth].aCache), 
							view_as<float>(g_eCvars[g_cvarTracerWidth].aCache), 1, 0.0, g_aColors[idx], 0);
		//TE_SendToAll();
		TE_Send(clients, numClients, 0.0);
	}

	return Plugin_Continue;
}