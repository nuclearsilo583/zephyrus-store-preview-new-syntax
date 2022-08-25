#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

enum Pet
{
	String:model[PLATFORM_MAX_PATH],
	String:run[64],
	String:idle[64],
	Float:fPosition[3],
	Float:fAngles[3]
}

new g_ePets[STORE_MAX_ITEMS][Pet];
new g_iPets = 0;
new g_unClientPet[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
new g_unSelectedPet[MAXPLAYERS+1]={-1,...};
new g_unLastAnimation[MAXPLAYERS+1]={-1,...};

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Pets_OnPluginStart()
#endif
{
	Store_RegisterHandler("pet", "model", Pets_OnMapStart, Pets_Reset, Pets_Config, Pets_Equip, Pets_Remove, true);

	HookEvent("player_spawn", Pets_PlayerSpawn);
	HookEvent("player_death", Pets_PlayerDeath);
	HookEvent("player_team", Pets_PlayerTeam);
}

public Pets_OnMapStart()
{
	for(new i=0;i<g_iPets;++i)
	{
		PrecacheModel2(g_ePets[i][model], true);
		Downloader_AddFileToDownloadsTable(g_ePets[i][model]);
	}
}

public Pets_Reset()
{
	g_iPets = 0;
}

public Pets_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iPets);
	
	decl Float:m_fTemp[3];
	KvGetString(kv, "model", g_ePets[g_iPets][model], PLATFORM_MAX_PATH);
	KvGetString(kv, "idle", g_ePets[g_iPets][idle], 64);
	KvGetString(kv, "run", g_ePets[g_iPets][run], 64);
	KvGetVector(kv, "position", m_fTemp);
	g_ePets[g_iPets][fPosition]=m_fTemp;
	KvGetVector(kv, "angles", m_fTemp);
	g_ePets[g_iPets][fAngles]=m_fTemp;

	if(!(FileExists(g_ePets[g_iPets][model], true)))
		return false;
	
	++g_iPets;
	return true;
}

public Pets_Equip(client, id)
{
	g_unSelectedPet[client]=Store_GetDataIndex(id);
	ResetPet(client);
	CreatePet(client);
	return 0;
}

public Pets_Remove(client)
{
	ResetPet(client);
	g_unSelectedPet[client]=-1;
	return 0;
}

public Pets_OnClientConnected(client)
{
	g_unSelectedPet[client]=-1;
}

public Pets_OnClientDisconnect(client)
{
	g_unSelectedPet[client]=-1;
}

public Action:Pets_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;

	ResetPet(client);
	CreatePet(client);

	return Plugin_Continue;
}

public Action:Pets_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	ResetPet(client);

	return Plugin_Continue;
}

public Action:Pets_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	ResetPet(client);

	return Plugin_Continue;
}

public Pets_OnPlayerRunCmd(client, tickcount)
{
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || g_unClientPet[client]==INVALID_ENT_REFERENCE)
		return;

	if(tickcount % 5 == 0 && EntRefToEntIndex(g_unClientPet[client]) != -1)
	{
		new Float:vec[3];
		decl Float:dist;
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vec);
		dist = GetVectorLength(vec);
		if(g_unLastAnimation[client] != 1 && dist > 0.0)
		{
			SetVariantString(g_ePets[g_unSelectedPet[client]][run]);
			AcceptEntityInput(EntRefToEntIndex(g_unClientPet[client]), "SetAnimation");

			g_unLastAnimation[client]=1;
		}
		else if(g_unLastAnimation[client] != 2 && dist == 0.0)
		{
			SetVariantString(g_ePets[g_unSelectedPet[client]][idle]);
			AcceptEntityInput(EntRefToEntIndex(g_unClientPet[client]), "SetAnimation");
			g_unLastAnimation[client]=2;
		}
	}
}

public CreatePet(client)
{
	if(g_unClientPet[client] != INVALID_ENT_REFERENCE)
		return;

	if(g_unSelectedPet[client] == -1)
		return;

	new m_iData = g_unSelectedPet[client];


	new m_unEnt = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(m_unEnt))
	{
		new Float:m_flPosition[3];
		new Float:m_flAngles[3];
		new Float:m_flClientOrigin[3];
		new Float:m_flClientAngles[3];
		GetClientAbsOrigin(client, m_flClientOrigin);
		GetClientAbsAngles(client, m_flClientAngles);
	
		m_flPosition[0]=g_ePets[m_iData][fPosition][0];
		m_flPosition[1]=g_ePets[m_iData][fPosition][1];
		m_flPosition[2]=g_ePets[m_iData][fPosition][2];
		m_flAngles[0]=g_ePets[m_iData][fAngles][0];
		m_flAngles[1]=g_ePets[m_iData][fAngles][1];
		m_flAngles[2]=g_ePets[m_iData][fAngles][2];

		decl Float:m_fForward[3];
		decl Float:m_fRight[3];
		decl Float:m_fUp[3];
		GetAngleVectors(m_flClientAngles, m_fForward, m_fRight, m_fUp);

		m_flClientOrigin[0] += m_fRight[0]*m_flPosition[0]+m_fForward[0]*m_flPosition[1]+m_fUp[0]*m_flPosition[2];
		m_flClientOrigin[1] += m_fRight[1]*m_flPosition[0]+m_fForward[1]*m_flPosition[1]+m_fUp[1]*m_flPosition[2];
		m_flClientOrigin[2] += m_fRight[2]*m_flPosition[0]+m_fForward[2]*m_flPosition[1]+m_fUp[2]*m_flPosition[2];
		m_flAngles[1] += m_flClientAngles[1];

		DispatchKeyValue(m_unEnt, "model", g_ePets[m_iData][model]);
		DispatchKeyValue(m_unEnt, "spawnflags", "256");
		DispatchKeyValue(m_unEnt, "solid", "0");
		SetEntPropEnt(m_unEnt, Prop_Send, "m_hOwnerEntity", client);
		
		DispatchSpawn(m_unEnt);	
		AcceptEntityInput(m_unEnt, "TurnOn", m_unEnt, m_unEnt, 0);
		
		// Teleport the pet to the right fPosition and attach it
		TeleportEntity(m_unEnt, m_flClientOrigin, m_flAngles, NULL_VECTOR); 
		
		SetVariantString("!activator");
		AcceptEntityInput(m_unEnt, "SetParent", client, m_unEnt, 0);
		
		SetVariantString("letthehungergamesbegin");
		AcceptEntityInput(m_unEnt, "SetParentAttachmentMaintainOffset", m_unEnt, m_unEnt, 0);
	  
		g_unClientPet[client] = EntIndexToEntRef(m_unEnt);
		g_unLastAnimation[client] = -1;
	}
}

public ResetPet(client)
{
	if(g_unClientPet[client] == INVALID_ENT_REFERENCE)
		return;

	new m_unEnt = EntRefToEntIndex(g_unClientPet[client]);
	g_unClientPet[client] = INVALID_ENT_REFERENCE;
	if(m_unEnt == INVALID_ENT_REFERENCE)
		return;

	AcceptEntityInput(m_unEnt, "Kill");
}