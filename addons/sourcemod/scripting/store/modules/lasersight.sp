#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_TF2 = false;
#endif

new g_cvarLaserSightMaterial = -1;
new g_cvarLaserDotMaterial = -1;

new g_aLaserColors[STORE_MAX_ITEMS][4];

new g_iLaserColors = 0;
new g_iLaserBeam = -1;
new g_iLaserDot = -1;

new Handle:g_hSnipers = INVALID_HANDLE;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public LaserSight_OnPluginStart()
#endif
{
	#if defined STANDALONE_BUILD
	// TF2 is unsupported
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif

	g_cvarLaserSightMaterial = RegisterConVar("sm_store_lasersight_material", "materials/sprites/laserbeam.vmt", "Material to be used with laser sights", TYPE_STRING);
	g_cvarLaserDotMaterial = RegisterConVar("sm_store_lasersight_dot_material", "materials/sprites/redglow1.vmt", "Material to be used with the dot of the laser sights", TYPE_STRING);
	
	Store_RegisterHandler("lasersight", "color", LaserSight_OnMapStart, LaserSight_Reset, LaserSight_Config, LaserSight_Equip, LaserSight_Remove, true);

	g_hSnipers = CreateTrie();
	SetTrieValue(g_hSnipers, "awp", 1);
	SetTrieValue(g_hSnipers, "scout", 1);
	SetTrieValue(g_hSnipers, "sg550", 1);
	SetTrieValue(g_hSnipers, "sg552", 1);
	SetTrieValue(g_hSnipers, "sg556", 1);
	SetTrieValue(g_hSnipers, "g3sg1", 1);
	SetTrieValue(g_hSnipers, "aug", 1);
	SetTrieValue(g_hSnipers, "scar17", 1);
	SetTrieValue(g_hSnipers, "scar20", 1);
	SetTrieValue(g_hSnipers, "ssg08", 1);
	SetTrieValue(g_hSnipers, "spring", 1);
	SetTrieValue(g_hSnipers, "k98s", 1);
}

public LaserSight_OnMapStart()
{
	g_iLaserBeam = PrecacheModel2(g_eCvars[g_cvarLaserSightMaterial][sCache], true);
	g_iLaserDot = PrecacheModel2(g_eCvars[g_cvarLaserDotMaterial][sCache], true);
}

public LaserSight_Reset()
{
	g_iLaserColors = 0;
}

public LaserSight_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iLaserColors);
	
	KvGetColor(kv, "color", g_aLaserColors[g_iLaserColors][0], g_aLaserColors[g_iLaserColors][1], g_aLaserColors[g_iLaserColors][2], g_aLaserColors[g_iLaserColors][3]);
	if(g_aLaserColors[g_iLaserColors][3]==0)
		g_aLaserColors[g_iLaserColors][3] = 255;
	
	++g_iLaserColors;
	
	return true;
}

public LaserSight_Equip(client, id)
{
	return -1;
}

public LaserSight_Remove(client, id)
{
}

#if defined STANDALONE_BUILD
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
#else
public LaserSight_OnPlayerRunCmd(client)
#endif
{
	new m_iEquipped = Store_GetEquippedItem(client, "lasersight");
	if(m_iEquipped < 0)
#if defined STANDALONE_BUILD
		return Plugin_Continue;
#else
		return;
#endif

	new m_unFOV = GetEntProp(client, Prop_Data, "m_iFOV");
	if(m_unFOV == 0 || m_unFOV == 90)
#if defined STANDALONE_BUILD
		return Plugin_Continue;
#else
		return;
#endif

	decl String:m_szWeapon[64];
	GetClientWeapon(client, STRING(m_szWeapon));

	new m_iTmp;
	if(!GetTrieValue(g_hSnipers, m_szWeapon[7], m_iTmp))
#if defined STANDALONE_BUILD
		return Plugin_Continue;
#else
		return;
#endif

	decl Float:m_fOrigin[3], Float:m_fImpact[3];
	GetClientEyePosition(client, m_fOrigin);
	GetClientSightEnd(client, m_fImpact);

	new m_iData = Store_GetDataIndex(m_iEquipped);

	TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iLaserBeam, 0, 0, 0, 0.1, 0.12, 0.0, 1, 0.0, g_aLaserColors[m_iData], 0);
	TE_SendToAll();

	TE_SetupGlowSprite(m_fImpact, g_iLaserDot, 0.1, 0.25, g_aLaserColors[m_iData][3]);
	TE_SendToAll();

#if defined STANDALONE_BUILD
	return Plugin_Continue;
#endif
}