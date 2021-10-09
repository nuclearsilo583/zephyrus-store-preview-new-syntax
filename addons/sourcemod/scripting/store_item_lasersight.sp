#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#pragma newdecls required

bool GAME_TF2 = false;

int g_cvarLaserSightMaterial = -1;
int g_cvarLaserDotMaterial = -1;

int g_aLaserColors[STORE_MAX_ITEMS][4];

int g_iLaserColors = 0;
int g_iLaserBeam = -1;
int g_iLaserDot = -1;

Handle g_hSnipers = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "Store - Laser sight item module",
	author = "zephyrus, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.1", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{

	// TF2 is unsupported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;

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
	
	// Supress warnings about unused variables.....
	if(GAME_TF2){}
}

public void LaserSight_OnMapStart()
{
	g_iLaserBeam = PrecacheModel2(g_eCvars[g_cvarLaserSightMaterial].sCache, true);
	g_iLaserDot = PrecacheModel2(g_eCvars[g_cvarLaserDotMaterial].sCache, true);
}

public int LaserSight_Reset()
{
	g_iLaserColors = 0;
}

public bool LaserSight_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iLaserColors);
	
	KvGetColor(kv, "color", g_aLaserColors[g_iLaserColors][0], g_aLaserColors[g_iLaserColors][1], g_aLaserColors[g_iLaserColors][2], g_aLaserColors[g_iLaserColors][3]);
	if(g_aLaserColors[g_iLaserColors][3]==0)
		g_aLaserColors[g_iLaserColors][3] = 255;
	
	++g_iLaserColors;
	
	return true;
}

public int LaserSight_Equip(int client,int id)
{
	return -1;
}

public int LaserSight_Remove(int client,int id)
{
}


public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	int m_iEquipped = Store_GetEquippedItem(client, "lasersight");
	if(m_iEquipped < 0)
		return Plugin_Continue;


	int m_unFOV = GetEntProp(client, Prop_Data, "m_iFOV");
	if(m_unFOV == 0 || m_unFOV == 90)
		return Plugin_Continue;

	char m_szWeapon[64];
	GetClientWeapon(client, STRING(m_szWeapon));

	any m_iTmp;
	if(!GetTrieValue(g_hSnipers, m_szWeapon[7], m_iTmp))
		return Plugin_Continue;


	float m_fOrigin[3], m_fImpact[3];
	GetClientEyePosition(client, m_fOrigin);
	GetClientSightEnd(client, m_fImpact);

	int m_iData = Store_GetDataIndex(m_iEquipped);

	TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iLaserBeam, 0, 0, 0, 0.1, 0.12, 0.0, 1, 0.0, g_aLaserColors[m_iData], 0);
	TE_SendToAll();

	TE_SetupGlowSprite(m_fImpact, g_iLaserDot, 0.1, 0.25, g_aLaserColors[m_iData][3]);
	TE_SendToAll();

	return Plugin_Continue;
}