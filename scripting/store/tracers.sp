#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

bool GAME_TF2 = false;
#endif

int g_cvarTracerMaterial = -1;
int g_cvarTracerLife = -1;
int g_cvarTracerWidth = -1;

int g_aColors[STORE_MAX_ITEMS][4];
bool g_bRandom[STORE_MAX_ITEMS];

int g_iColors = 0;
int g_iBeam = -1;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Tracers_OnPluginStart()
#endif
{	
#if defined STANDALONE_BUILD
	// TF2 is unsupported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif

	if(GAME_TF2)
		return;

	g_cvarTracerMaterial = RegisterConVar("sm_store_tracer_material", "materials/sprites/laserbeam.vmt", "Material to be used with tracers", TYPE_STRING);
	g_cvarTracerLife = RegisterConVar("sm_store_tracer_life", "0.5", "Life of a tracer in seconds", TYPE_FLOAT);
	g_cvarTracerWidth = RegisterConVar("sm_store_tracer_width", "1.0", "Life of a tracer in seconds", TYPE_FLOAT);
	
	Store_RegisterHandler("tracer", "color", Tracers_OnMapStart, Tracers_Reset, Tracers_Config, Tracers_Equip, Tracers_Remove, true);
	
	HookEvent("bullet_impact", Tracers_BulletImpact);
}

public void Tracers_OnMapStart()
{
	g_iBeam = PrecacheModel2(g_eCvars[g_cvarTracerMaterial].sCache, true);
}

public void Tracers_Reset()
{
	g_iColors = 0;
}

public bool Tracers_Config(Handle kv,int itemid)
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
	return -1;
}

public int Tracers_Remove(int client,int id)
{
}

public Action Tracers_BulletImpact(Handle event,const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int m_iEquipped = Store_GetEquippedItem(client, "tracer");
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
		TE_SendToAll();
	}

	return Plugin_Continue;
}