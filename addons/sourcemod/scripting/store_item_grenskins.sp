#include <sourcemod>
#include <sdktools>

#include <colors>

#include <store>
#include <zephstocks>

#include <sdkhooks>

#pragma newdecls required

bool GAME_TF2 = false;

char g_sChatPrefix[128];

enum struct GrenadeSkin
{
	char szModel_Grenade[PLATFORM_MAX_PATH];
	char szWeapon[64];
	int iLength;
	int iSlot_Grenade;
}

GrenadeSkin g_eGrenadeSkins[STORE_MAX_ITEMS];

char g_szSlots[16][64];

int g_iGrenadeSkins = 0;
int g_iSlot_Grenades = 0;

Handle g_hTimerPreview[MAXPLAYERS + 1];

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public Plugin myinfo =
{
	name = "Store Grenade Skin",
	author = "zephyrus, nuclear silo",
	description = "change grenade model",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{

	// This is not a standalone build, we don't want grenade skins to kill the whole plugin for us	
	if(GetExtensionFileStatus("sdkhooks.ext")!=1)
	{
		LogError("SDKHooks isn't installed or failed to load. Grenade Skins will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
	// TF2 is unsupported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
	LoadTranslations("store.phrases");
	
	Store_RegisterHandler("grenadeskin", "model", GrenadeSkins_OnMapStart, GrenadeSkins_Reset, GrenadeSkins_Config, GrenadeSkins_Equip, GrenadeSkins_Remove, true);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void GrenadeSkins_OnMapStart()
{
	for(int i=0;i<g_iGrenadeSkins;++i)
	{
		PrecacheModel2(g_eGrenadeSkins[i].szModel_Grenade, true);
		Downloader_AddFileToDownloadsTable(g_eGrenadeSkins[i].szModel_Grenade);
	}
}

public void GrenadeSkins_Reset()
{
	g_iGrenadeSkins = 0;
}

public bool GrenadeSkins_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iGrenadeSkins);
	KvGetString(kv, "model", g_eGrenadeSkins[g_iGrenadeSkins].szModel_Grenade, PLATFORM_MAX_PATH);
	KvGetString(kv, "grenade", g_eGrenadeSkins[g_iGrenadeSkins].szWeapon, PLATFORM_MAX_PATH);
	
	g_eGrenadeSkins[g_iGrenadeSkins].iSlot_Grenade = GrenadeSkins_GetSlot(g_eGrenadeSkins[g_iGrenadeSkins].szWeapon);
	g_eGrenadeSkins[g_iGrenadeSkins].iLength = strlen(g_eGrenadeSkins[g_iGrenadeSkins].szWeapon);
	
	if(!(FileExists(g_eGrenadeSkins[g_iGrenadeSkins].szModel_Grenade, true)))
		return false;
		
	++g_iGrenadeSkins;
	return true;
}

public int GrenadeSkins_Equip(int client,int id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)].iSlot_Grenade;
}

public int GrenadeSkins_Remove(int client,int id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)].iSlot_Grenade;
}

public int GrenadeSkins_GetSlot(char[] weapon)
{
	for(int i=0;i<g_iSlot_Grenades;++i)
		if(strcmp(weapon, g_szSlots[i])==0)
			return i;
	
	strcopy(g_szSlots[g_iSlot_Grenades], sizeof(g_szSlots[]), weapon);
	return g_iSlot_Grenades++;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(g_iGrenadeSkins == 0)
		return;
	if(StrContains(classname, "_projectile")>0)
		SDKHook(entity, SDKHook_SpawnPost, GrenadeSkins_OnEntitySpawnedPost);		
}

public void GrenadeSkins_OnEntitySpawnedPost(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(!(0<client<=MaxClients))
		return;
	
	char m_szClassname[64];
	GetEdictClassname(entity, m_szClassname, sizeof(m_szClassname));
	
	any m_iSlot_Grenade;
	
	if(GAME_TF2)
		m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname[14]);
	else
	{
		for(int i=0;i<strlen(m_szClassname);++i)
			if(m_szClassname[i]=='_')
			{
				m_szClassname[i]=0;
				break;
			}
		m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname);
	}	
	
	int m_iEquipped = Store_GetEquippedItem(client, "grenadeskin", m_iSlot_Grenade);
	
	if(m_iEquipped < 0)
		return;
		
	int m_iData = Store_GetDataIndex(m_iEquipped);
	SetEntityModel(entity, g_eGrenadeSkins[m_iData].szModel_Grenade);
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "grenadeskin"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override
	
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_eGrenadeSkins[index].szModel_Grenade);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	//int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
	//SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	//SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
	//SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);

	//Miku Green
	//SetEntData(iPreview, offset, 57, _, true);
	//SetEntData(iPreview, offset + 1, 197, _, true);
	//SetEntData(iPreview, offset + 2, 187, _, true);
	//SetEntData(iPreview, offset + 3, 155, _, true);

	float fOri[3];
	float fAng[3];
	float fRad[2];
	float fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 55;

	TeleportEntity(iPreview, fPos, fAng, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPos);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

	CPrintToChat(client, " %s%t", g_sChatPrefix, "Spawn Preview", client);
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}