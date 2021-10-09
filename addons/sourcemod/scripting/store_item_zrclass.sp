#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <store>
#include <zephstocks>
#include <colors>
#include <zombiereloaded>

#pragma newdecls required

char g_sChatPrefix[128];
//native bool ZR_IsClientZombie(client);
//bool g_bZombieMode = false;


//native bool ZR_IsClientHuman(client);
//native ZR_GetClassByName(const char[] className,int cacheType = 0);
//native ZR_SelectClientClass(int client,int classIndex, bool applyIfPossible = true, bool saveIfEnabled = true);

//forward ZR_OnClientInfected(int client,int attacker, bool motherInfect, bool respawnOverride, bool respawn);
//forward ZR_OnClientHumanPost(int client, bool respawn, bool protect);

static int g_iClientClasses[MAXPLAYERS+1][2];

int g_cvarDefaultHumanClass = -1;
int g_cvarDefaultZombieClass = -1;

char g_sModel[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

enum struct ZRClass
{
	char szClass[64];
	bool bZombie;
	int skin;
	int body;
	any unIndex;
}

ZRClass g_eZRClasses[STORE_MAX_ITEMS];

int g_iZRClasses = 0;
//int g_iCount = 0;

//char g_sChatPrefix[128];

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_bSkinEnable;

public Plugin myinfo = 
{
	name = "Store - Zombie:Reloaded Player Classes Module",
	author = "nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{
	Store_RegisterHandler("zrclass", "class", ZRClass_OnMapStart, ZRClass_Reset, ZRClass_Config, ZRClass_Equip, ZRClass_Remove, true);
		
	g_cvarDefaultHumanClass = RegisterConVar("sm_store_zrclass_default_human", "Normal Human", "Name of the default human class.", TYPE_STRING);
	g_cvarDefaultZombieClass = RegisterConVar("sm_store_zrclass_default_zombie", "Classic", "Name of the default zombie class.", TYPE_STRING);
	g_bSkinEnable = RegisterConVar("sm_store_zrclass_enable", "1", "Enable the player skin module", TYPE_INT);
	LoadTranslations("store.phrases");
	
	//g_bZombieMode = (FindPluginByFile("zombiereloaded")==INVALID_HANDLE?false:true);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

/*
public APLRes AskPluginLoad2(Handle myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("ZR_IsClientZombie");
	MarkNativeAsOptional("ZR_IsClientHuman");
	MarkNativeAsOptional("ZR_GetClassByName");
	MarkNativeAsOptional("ZR_SelectClientClass");
	return APLRes_Success;
} */

public void ZRClass_OnMapStart()
{
}

/*
public void ZRClass_OnLibraryAdded(const String:name[])
{
	if(strcmp(name, "zombiereloaded")==0)
		g_bZombieMode = true;
}*/

public void OnClientConnected(int client)
{
	g_iClientClasses[client][0] = -1;
	g_iClientClasses[client][1] = -1;
}

public void ZRClass_Reset()
{
	g_iZRClasses = 0;
}

public bool ZRClass_Config(KeyValues &kv, int itemid)
{
	//if(!IsPluginLoaded("zombiereloaded"))
	//	return false;
	//int g_iCount = 0;
	Store_SetDataIndex(itemid, g_iZRClasses);
	//MyStore_SetDataIndex(itemid, g_iCount);
	
	kv.GetString("model", g_sModel[g_iZRClasses], PLATFORM_MAX_PATH);

	//if (!FileExists(g_sModel[g_iZRClasses], true))
	
	KvGetString(kv, "class", g_eZRClasses[g_iZRClasses].szClass, 64);
	g_eZRClasses[g_iZRClasses].skin = kv.GetNum("skin");
	g_eZRClasses[g_iZRClasses].body = kv.GetNum("body");
	g_eZRClasses[g_iZRClasses].bZombie = (KvGetNum(kv, "zombie")?true:false);
	
	if((g_eZRClasses[g_iZRClasses].unIndex = ZR_GetClassByName(g_eZRClasses[g_iZRClasses].szClass))!=-1)
	{
		++g_iZRClasses;
		return true;
	}
	
	return false;
}

public int ZRClass_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	g_iClientClasses[client][view_as<int>(g_eZRClasses[m_iData].bZombie)] = g_eZRClasses[m_iData].unIndex;
	
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		ZR_SelectClientClass(client, g_eZRClasses[m_iData].unIndex, false, false);
	}
	return g_eZRClasses[m_iData].bZombie;
}

public int ZRClass_Remove(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	g_iClientClasses[client][view_as<int>(g_eZRClasses[m_iData].bZombie)] = -1;
	
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if(g_eZRClasses[m_iData].bZombie)
			ZR_SelectClientClass(client, ZR_GetClassByName(g_eCvars[g_cvarDefaultZombieClass].sCache), false, false);
		else
			ZR_SelectClientClass(client, ZR_GetClassByName(g_eCvars[g_cvarDefaultHumanClass].sCache), false, false);
	}
	return g_eZRClasses[Store_GetDataIndex(id)].bZombie;
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{	
	if(motherInfect)
		return;

	if(g_iClientClasses[client][1] == -1)
	{
		if(GetClientHealth(client) < 300)
		{
			ZR_SelectClientClass(client, g_cvarDefaultZombieClass, false, false);

		}
		return;
	}
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		ZR_SelectClientClass(client, g_iClientClasses[client][1], false, false);
	}
}

public int ZR_OnClientHumanPost(int client, bool respawn, bool protect)
{
	if(g_iClientClasses[client][0] == -1)
		return;
	
	ZR_SelectClientClass(client, g_iClientClasses[client][0], false, false);
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	/*
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}*/
	if (!StrEqual(type, "zrclass"))
		return;
		
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 
	
	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer
	//int iIndex = MyStore_GetDataIndex(itemid);
	
	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_sModel[index]);
	//DispatchKeyValue(iPreview, "m_nSkin", g_iSkin[index]);
	//DispatchKeyValue(iPreview, "m_nSkin", "2");

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
	//SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	//SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
	SetEntProp(iPreview, Prop_Send, "m_nSkin", g_eZRClasses[index].skin);
	SetEntProp(iPreview, Prop_Send, "m_nBody", g_eZRClasses[index].body);
	//SetEntProp(iPreview, Prop_Send, "m_nSkin", 2);
	//SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);


	SetEntData(iPreview, offset, 57, _, true);
	SetEntData(iPreview, offset + 1, 197, _, true);
	SetEntData(iPreview, offset + 2, 187, _, true);
	SetEntData(iPreview, offset + 3, 155, _, true);

	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fAngles[0] *= -1.0;
	fAngles[1] *= -1.0;

	fPosition[2] += 5;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

	CPrintToChat(client, " %s%t",g_sChatPrefix, "Spawn Preview", client);
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