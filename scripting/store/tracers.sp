#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_TF2 = false;
#endif

new g_cvarTracerMaterial = -1;
new g_cvarTracerLife = -1;
new g_cvarTracerWidth = -1;

new g_aColors[STORE_MAX_ITEMS][4];
new bool:g_bRandom[STORE_MAX_ITEMS];

new g_iColors = 0;
new g_iBeam = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Tracers_OnPluginStart()
#endif
{	
#if defined STANDALONE_BUILD
	// TF2 is unsupported
	new String:m_szGameDir[32];
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

public Tracers_OnMapStart()
{
	g_iBeam = PrecacheModel2(g_eCvars[g_cvarTracerMaterial][sCache], true);
}

public Tracers_Reset()
{
	g_iColors = 0;
}

public Tracers_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iColors);

	KvGetColor(kv, "color", g_aColors[g_iColors][0], g_aColors[g_iColors][1], g_aColors[g_iColors][2], g_aColors[g_iColors][3]);
	if(g_aColors[g_iColors][3]==0)
		g_aColors[g_iColors][3] = 255;
	g_bRandom[g_iColors] = KvGetNum(kv, "rainbow", 0)?true:false;
	
	++g_iColors;
	
	return true;
}

public Tracers_Equip(client, id)
{
	return -1;
}

public Tracers_Remove(client, id)
{
}

public Action:Tracers_BulletImpact(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new m_iEquipped = Store_GetEquippedItem(client, "tracer");
	if(m_iEquipped >= 0)
	{
		new idx = Store_GetDataIndex(m_iEquipped);

		while(g_bRandom[idx]) idx = GetRandomInt(0, g_iColors);
	
		decl Float:m_fOrigin[3], Float:m_fImpact[3];

		GetClientEyePosition(client, m_fOrigin);
		m_fImpact[0] = GetEventFloat(event, "x");
		m_fImpact[1] = GetEventFloat(event, "y");
		m_fImpact[2] = GetEventFloat(event, "z");
		
		TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iBeam, 0, 0, 0, Float:g_eCvars[g_cvarTracerLife][aCache], Float:g_eCvars[g_cvarTracerWidth][aCache], Float:g_eCvars[g_cvarTracerWidth][aCache], 1, 0.0, g_aColors[idx], 0);
		TE_SendToAll();
	}

	return Plugin_Continue;
}