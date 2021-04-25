#pragma semicolon 1
#include <sourcemod> 
#include <sdktools>
#include <sdkhooks>
#include <store> 
#include <zephstocks> 
#include <fpvm_interface>
#include <colors>

#pragma newdecls required
enum struct CustomModel
{
	char szModel[PLATFORM_MAX_PATH];
	char szWorldModel[PLATFORM_MAX_PATH];
	char szDropModel[PLATFORM_MAX_PATH];
	char weaponentity[32];
	int iSlot;
	int iCacheID;
	int iCacheIDWorldModel;
}

CustomModel g_eCustomModel[STORE_MAX_ITEMS];
int g_iCustomModels = 0;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

char g_sChatPrefix[128];

public Plugin myinfo =
{
	name = "Store Custom Weapon Models",
	author = "Mr.Derp & Franc1sco franug | Zephyrus Store Module & bbs.93x.net",
	description = "Custom Knife Models",
	version = "3.0",
	url = "http://bbs.93x.net"
}

public void OnPluginStart() 
{
	Store_RegisterHandler("CustomModel", "model", CustomModelOnMapStart, CustomModelReset, CustomModelConfig, CustomModelEquip, CustomModelRemove, true); 
	LoadTranslations("store.phrases");

}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}


public void CustomModelOnMapStart() 
{
	for(int i=0;i<g_iCustomModels;++i)
	{
		g_eCustomModel[i].iCacheID = PrecacheModel2(g_eCustomModel[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szModel);
		
		if(g_eCustomModel[i].szWorldModel[0]!=0)
		{
			g_eCustomModel[i].iCacheIDWorldModel = PrecacheModel2(g_eCustomModel[i].szWorldModel, true);
			Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szWorldModel);
			
			if(g_eCustomModel[i].iCacheIDWorldModel ==0)
				g_eCustomModel[i].iCacheIDWorldModel = -1;
		}
		
		if(g_eCustomModel[i].szDropModel[0]!=0)
		{
			if(!IsModelPrecached(g_eCustomModel[i].szDropModel))
			{
				PrecacheModel2(g_eCustomModel[i].szDropModel, true);
				Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szDropModel);
			}
		}
	}
} 


public void CustomModelReset() 
{ 
	g_iCustomModels = 0; 
}

public int CustomModelConfig(Handle &kv, int itemid) 
{
	Store_SetDataIndex(itemid, g_iCustomModels);
	KvGetString(kv, "model", g_eCustomModel[g_iCustomModels].szModel, PLATFORM_MAX_PATH);
	KvGetString(kv, "worldmodel", g_eCustomModel[g_iCustomModels].szWorldModel, PLATFORM_MAX_PATH);
	KvGetString(kv, "dropmodel", g_eCustomModel[g_iCustomModels].szDropModel, PLATFORM_MAX_PATH);
	KvGetString(kv, "entity", g_eCustomModel[g_iCustomModels].weaponentity, 32);
	g_eCustomModel[g_iCustomModels].iSlot = KvGetNum(kv, "slot");
	
	if(FileExists(g_eCustomModel[g_iCustomModels].szModel, true))
	{
		++g_iCustomModels;
		
		for(int i=0;i<g_iCustomModels;++i)
		{
			if(!IsModelPrecached(g_eCustomModel[i].szModel))
			{
				g_eCustomModel[i].iCacheID = PrecacheModel2(g_eCustomModel[i].szModel, true);
				Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szModel);
				//LogMessage("Precached %i %s",g_eCustomModel[i].iCacheID,g_eCustomModel[i].szModel);
			}
			if(g_eCustomModel[i].szWorldModel[0]!=0)
			{
				if(!IsModelPrecached(g_eCustomModel[i].szWorldModel))
				{	
					g_eCustomModel[i].iCacheIDWorldModel = PrecacheModel2(g_eCustomModel[i].szWorldModel, true);
					Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szWorldModel);
					//LogMessage("Precached %i %s",g_eCustomModel[i].iCacheIDWorldModel,g_eCustomModel[i].szWorldModel);
				}
				if(g_eCustomModel[i].szDropModel[0]!=0)
				{
					if(!IsModelPrecached(g_eCustomModel[i].szDropModel))
					{
						PrecacheModel2(g_eCustomModel[i].szDropModel, true);
						Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szDropModel);
					}
				}
			}
		}
		
		return true;
	}
	return false;
}

public int CustomModelEquip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	FPVMI_SetClientModel(client, g_eCustomModel[m_iData].weaponentity, g_eCustomModel[m_iData].iCacheID, g_eCustomModel[m_iData].iCacheIDWorldModel, g_eCustomModel[m_iData].szDropModel);
	//PrintToChat(client,"%s %d %d %s",g_eCustomModel[m_iData].weaponentity, g_eCustomModel[m_iData].iCacheID, g_eCustomModel[m_iData].iCacheIDWorldModel,g_eCustomModel[m_iData].szDropModel); //DEBUG
	return g_eCustomModel[m_iData].iSlot;
}

public int CustomModelRemove(int client, int id) 
{
	int m_iData = Store_GetDataIndex(id);
	
	FPVMI_RemoveViewModelToClient(client, g_eCustomModel[m_iData].weaponentity);
	if(g_eCustomModel[m_iData].szWorldModel[0]!=0)
	{
		FPVMI_RemoveWorldModelToClient(client, g_eCustomModel[m_iData].weaponentity);
	}
	if(g_eCustomModel[m_iData].szDropModel[0]!=0)
	{
		FPVMI_RemoveDropModelToClient(client, g_eCustomModel[m_iData].weaponentity);
	}
	
	return g_eCustomModel[m_iData].iSlot;
}




public void OnMapStart() //Precache possible bug re check
{
	if(g_iCustomModels > 0)
	{
		for(int i=0;i<g_iCustomModels;++i)
		{
			if(!IsModelPrecached(g_eCustomModel[i].szModel))
			{
				g_eCustomModel[i].iCacheID = PrecacheModel2(g_eCustomModel[i].szModel, true);
				Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szModel);
			}
			
			if(g_eCustomModel[i].szWorldModel[0]!=0)
			{
				if(!IsModelPrecached(g_eCustomModel[i].szWorldModel))
				{
					g_eCustomModel[i].iCacheIDWorldModel = PrecacheModel2(g_eCustomModel[i].szWorldModel, true);
					Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szWorldModel);
					
					if(g_eCustomModel[i].iCacheIDWorldModel ==0)
						g_eCustomModel[i].iCacheIDWorldModel = -1;
				}
			}
			
			if(g_eCustomModel[i].szDropModel[0]!=0)
			{
				if(!IsModelPrecached(g_eCustomModel[i].szDropModel))
				{	
					PrecacheModel2(g_eCustomModel[i].szDropModel, true);
					Downloader_AddFileToDownloadsTable(g_eCustomModel[i].szDropModel);
				}
			}
		}
	}
} 

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "CustomModel"))
		return;
		
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_eCustomModel[index].szWorldModel);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
	//SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	//SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
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

	fPosition[2] += 55;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "friction", "0");
	DispatchKeyValue(iRotator, "dmg", "0");
	DispatchKeyValue(iRotator, "solid", "0");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(8.0, Timer_KillPreview, client);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
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


