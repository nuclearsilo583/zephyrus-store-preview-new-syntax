#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <cstrike>

#include <store>
#include <zephstocks>
#pragma newdecls required
#pragma tabsize 0
#pragma dynamic 131072

char gBuff[256];

enum struct ColoredSmoke
{
	char RGB[64];
	char iStart_Size[64];
	char iEnd_Size[64];
	char iBaseSpread[64];
	char iSpreadSpeed[64];
	char iTwist[64];
	char iSpeed[64];
	char iRate[64];
	char iJetLength[64];
	char iDensity[64];
	float iLife;
	char szMaterials[PLATFORM_MAX_PATH];
}

ColoredSmoke g_eColoredSmoke[STORE_MAX_ITEMS];

bool g_bEquipt[MAXPLAYERS + 1] = {false, ...};

int g_iColoredSmoke = 0;

char g_sChatPrefix[128];

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public Plugin myinfo = 
{
	name = "Store - Colored Smoke Module",
	author = "nuclear silo, AiDN™", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.3", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	
	Store_RegisterHandler("ColoredSmoke", "particle", ColoredSmoke_OnMapStart, ColoredSmoke_Reset, ColoredSmoke_Config, ColoredSmoke_Equip, ColoredSmoke_Remove, true);
	
	HookEvent("smokegrenade_detonate", Event_OnSmokegrenadeDetonatePre);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void ColoredSmoke_OnMapStart()
{
	for(int i=0;i<g_iColoredSmoke;++i)
	{
		PrecacheModel2(g_eColoredSmoke[i].szMaterials, true);
		Downloader_AddFileToDownloadsTable(g_eColoredSmoke[i].szMaterials);
	}
}

public void ColoredSmoke_Reset()
{
	g_iColoredSmoke = 0;
	
}

public bool ColoredSmoke_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iColoredSmoke);
	
	KvGetString(kv, "rgb color", g_eColoredSmoke[g_iColoredSmoke].RGB, 64);
	KvGetString(kv, "start size", g_eColoredSmoke[g_iColoredSmoke].iStart_Size, 64, "200");
	KvGetString(kv, "end size", g_eColoredSmoke[g_iColoredSmoke].iEnd_Size, 64, "2");
	KvGetString(kv, "base spread", g_eColoredSmoke[g_iColoredSmoke].iBaseSpread, 64, "100");
	KvGetString(kv, "speed spread", g_eColoredSmoke[g_iColoredSmoke].iSpreadSpeed, 64, "70");
	KvGetString(kv, "twist", g_eColoredSmoke[g_iColoredSmoke].iTwist, 64, "20");
	KvGetString(kv, "speed", g_eColoredSmoke[g_iColoredSmoke].iSpeed, 64, "80");
	KvGetString(kv, "rate", g_eColoredSmoke[g_iColoredSmoke].iRate, 64, "30");
	KvGetString(kv, "jet length", g_eColoredSmoke[g_iColoredSmoke].iJetLength, 64, "150");
	KvGetString(kv, "density", g_eColoredSmoke[g_iColoredSmoke].iDensity, 64, "200");
	g_eColoredSmoke[g_iColoredSmoke].iLife = KvGetFloat(kv, "lifetime", 10.0);
	KvGetString(kv, "material", g_eColoredSmoke[g_iColoredSmoke].szMaterials, PLATFORM_MAX_PATH, "particle/particle_smokegrenade1.vmt");

	++g_iColoredSmoke;
	
	return true;
}

public int ColoredSmoke_Equip(int client, int id)
{
	//int m_iData = Store_GetDataIndex(id);
	g_bEquipt[client] = true;
	
	return 0;
}

public int ColoredSmoke_Remove(int client, int id)
{
	g_bEquipt[client] = false;
	
	return 0;
}

public Action Event_OnSmokegrenadeDetonatePre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int m_iEquipped = Store_GetEquippedItem(client, "ColoredSmoke");
	
	if(m_iEquipped<0)
		return Plugin_Continue;
	
	int m_iData = Store_GetDataIndex(m_iEquipped);

	if (!g_bEquipt[client])
		return Plugin_Continue;

	float pos[3];
	pos[0] = event.GetFloat("x");
	pos[1] = event.GetFloat("y");
	pos[2] = event.GetFloat("z");

	int entity;
	

	if((entity = event.GetInt("entityid")))											
		AcceptEntityInput(entity, "kill");

	if ((entity = CreateEntityByName("env_smokestack")) != -1)
	{
		
		DispatchKeyValueVector(entity, "origin", pos); 

		DispatchKeyValue(entity, "BaseSpread", g_eColoredSmoke[m_iData].iBaseSpread);
		
		Format(gBuff, sizeof(gBuff), "smokestack_%i", entity);
		DispatchKeyValue(entity, "targetname", gBuff);
		
		DispatchKeyValue(entity, "SpreadSpeed", g_eColoredSmoke[m_iData].iSpreadSpeed);
		
		DispatchKeyValue(entity, "Speed", g_eColoredSmoke[m_iData].iSpeed);
		
		DispatchKeyValue(entity, "StartSize", g_eColoredSmoke[m_iData].iStart_Size);
		
		DispatchKeyValue(entity, "EndSize", g_eColoredSmoke[m_iData].iEnd_Size);

		DispatchKeyValue(entity, "Rate", g_eColoredSmoke[m_iData].iRate);

		DispatchKeyValue(entity, "JetLength", g_eColoredSmoke[m_iData].iJetLength);

		DispatchKeyValue(entity, "Twist", g_eColoredSmoke[m_iData].iTwist);

		DispatchKeyValue(entity, "RenderColor", g_eColoredSmoke[m_iData].RGB);

		DispatchKeyValue(entity, "RenderAmt", g_eColoredSmoke[m_iData].iDensity);	
		
		DispatchKeyValue(entity, "SmokeMaterial", g_eColoredSmoke[m_iData].szMaterials);
		
		//Debug
		/*
		CPrintToChat(client, "targetname %s", gBuff);
		CPrintToChat(client, "BaseSpread %s", g_eColoredSmoke[m_iData].iBaseSpread);
		CPrintToChat(client, "SpreadSpeed %s", g_eColoredSmoke[m_iData].iSpreadSpeed);
		CPrintToChat(client, "Speed %s", g_eColoredSmoke[m_iData].iSpeed);
		CPrintToChat(client, "StartSize %s", g_eColoredSmoke[m_iData].iStart_Size);
		CPrintToChat(client, "EndSize %s", g_eColoredSmoke[m_iData].iEnd_Size);
		CPrintToChat(client, "Rate %s", g_eColoredSmoke[m_iData].iRate);
		CPrintToChat(client, "JetLength %s", g_eColoredSmoke[m_iData].iJetLength);
		CPrintToChat(client, "Twist %s", g_eColoredSmoke[m_iData].iTwist);
		CPrintToChat(client, "RenderColor %s", g_eColoredSmoke[m_iData].RGB);
		CPrintToChat(client, "RenderAmt %s", g_eColoredSmoke[m_iData].iDensity);	
		CPrintToChat(client, "SmokeMaterial %s", g_eColoredSmoke[m_iData].szMaterials);
		*/

		DispatchSpawn(entity);
		AcceptEntityInput(entity, "TurnOn");

		float lifetime = g_eColoredSmoke[m_iData].iLife;
		if(lifetime)
		{
			FormatEx(gBuff, sizeof(gBuff), "OnUser2 !self:TurnOff::%f:1", lifetime);
			SetVariantString(gBuff);

			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser2");
			
			CreateTimer(lifetime, Timer_SmokeRemove, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		}
		
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_SmokeRemove(Handle timer, int entity)
{
	entity = EntRefToEntIndex(entity);

	AcceptEntityInput(entity, "TurnOff");

	Format(gBuff, sizeof(gBuff), "OnUser1 !self:kill::3.0:1");
	SetVariantString(gBuff);

	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	
	return Plugin_Stop;
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hTimerPreview[i];
	}
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client])
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "ColoredSmoke"))
		return;

		int SmokeEnt = CreateEntityByName("env_smokestack");

		float location[3];
		GetClientAbsOrigin(client, location);

		char originData[PLATFORM_MAX_PATH];
		Format(originData, sizeof(originData), "%f %f %f", location[0], location[1], location[2]);

		if(SmokeEnt)
		{
			// Create the Smoke
			DispatchKeyValue(SmokeEnt, "origin", originData); 

			DispatchKeyValue(SmokeEnt, "BaseSpread", g_eColoredSmoke[index].iBaseSpread);

			Format(gBuff, sizeof(gBuff), "smokestack_%i", SmokeEnt);
			DispatchKeyValue(SmokeEnt, "targetname", gBuff);

			DispatchKeyValue(SmokeEnt, "SpreadSpeed", g_eColoredSmoke[index].iSpreadSpeed);

			DispatchKeyValue(SmokeEnt, "Speed", g_eColoredSmoke[index].iSpeed);

			DispatchKeyValue(SmokeEnt, "StartSize", g_eColoredSmoke[index].iStart_Size);

			DispatchKeyValue(SmokeEnt, "EndSize", g_eColoredSmoke[index].iEnd_Size);

			DispatchKeyValue(SmokeEnt, "Rate", g_eColoredSmoke[index].iRate);

			DispatchKeyValue(SmokeEnt, "JetLength", g_eColoredSmoke[index].iJetLength);

			DispatchKeyValue(SmokeEnt, "Twist", g_eColoredSmoke[index].iTwist);

			DispatchKeyValue(SmokeEnt, "RenderColor", g_eColoredSmoke[index].RGB);

			DispatchKeyValue(SmokeEnt, "RenderAmt", g_eColoredSmoke[index].iDensity);	

			DispatchKeyValue(SmokeEnt, "SmokeMaterial", g_eColoredSmoke[index].szMaterials);

			DispatchSpawn(SmokeEnt);
			AcceptEntityInput(SmokeEnt, "TurnOn");
		}

	g_iPreviewEntity[client] = EntIndexToEntRef(SmokeEnt);

	SDKHook(SmokeEnt, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	float lifetime = g_eColoredSmoke[index].iLife;
	if(lifetime)
	{
		FormatEx(gBuff, sizeof(gBuff), "OnUser2 !self:TurnOff::%f:1", lifetime);
		SetVariantString(gBuff);

		AcceptEntityInput(SmokeEnt, "AddOutput");
		AcceptEntityInput(SmokeEnt, "FireUser2");

		g_hTimerPreview[client] = CreateTimer(lifetime, Timer_KillPreview, client);
	}

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview - Colored smoke", lifetime);
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
	// No need for a disconnection check because it doesn't do anything to the client, and this timer must be ran even if the client DCs.
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "TurnOff");

			CreateTimer(5.0, Timer_StopSmoke, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		}
		g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;
	}
	
	return Plugin_Stop;
}

public Action Timer_StopSmoke(Handle timer, int SmokeEnt)
{
	if (IsValidEntity(SmokeEnt))
	{
		RemoveEntity(SmokeEnt);
	}
	return Plugin_Stop;
}