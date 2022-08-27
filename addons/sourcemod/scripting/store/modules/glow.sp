#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

enum Glow
{
	String:GlowColor[16],
	String:GlowBrightness[8],
	String:GlowStyle[4],
	Float:GlowflRadius,
	Float:GlowflDistance
}

new g_eGlow[STORE_MAX_ITEMS][Glow];
new g_iGlow = 0;
new g_unClientGlow[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
new g_unSelectedGlow[MAXPLAYERS+1]={-1,...};

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Glow_OnPluginStart()
#endif
{
	Store_RegisterHandler("glow", "color", Glow_OnMapStart, Glow_Reset, Glow_Config, Glow_Equip, Glow_Remove, true);

	HookEvent("player_spawn", Glow_PlayerSpawn);
	HookEvent("player_death", Glow_PlayerDeath);
	HookEvent("player_team", Glow_PlayerTeam);
}

public Glow_OnMapStart()
{
}

public Glow_Reset()
{
	g_iGlow = 0;
}

public Glow_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iGlow);
	
	KvGetString(kv, "color", g_eGlow[g_iGlow][GlowColor], 16);
	KvGetString(kv, "brightness", g_eGlow[g_iGlow][GlowBrightness], 8, "5");
	KvGetString(kv, "style", g_eGlow[g_iGlow][GlowStyle], 4, "0");
	g_eGlow[g_iGlow][GlowflDistance]=KvGetFloat(kv, "distance", 200.0);
	g_eGlow[g_iGlow][GlowflRadius]=KvGetFloat(kv, "distance", 100.0);
	
	++g_iGlow;
	return true;
}

public Glow_Equip(client, id)
{
	g_unSelectedGlow[client]=Store_GetDataIndex(id);
	ResetGlow(client);
	CreateGlow(client);
	return 0;
}

public Glow_Remove(client)
{
	ResetGlow(client);
	g_unSelectedGlow[client]=-1;
	return 0;
}

public Glow_OnClientConnected(client)
{
	g_unSelectedGlow[client]=-1;
}

public Glow_OnClientDisconnect(client)
{
	g_unSelectedGlow[client]=-1;
}

public Action:Glow_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;

	CreateTimer(0.1, Glow_PlayerSpawn_Post, GetClientUserId(client));

	return Plugin_Continue;
}

public Action:Glow_PlayerSpawn_Post(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Stop;

	ResetGlow(client);
	CreateGlow(client);
	return Plugin_Stop;
}

public Action:Glow_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	ResetGlow(client);

	return Plugin_Continue;
}

public Action:Glow_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	ResetGlow(client);

	return Plugin_Continue;
}

public CreateGlow(client)
{
	if(g_unClientGlow[client] != INVALID_ENT_REFERENCE)
		return;

	if(g_unSelectedGlow[client] == -1)
		return;

	new m_iData = g_unSelectedGlow[client];


	new m_unEnt = CreateEntityByName("light_dynamic");
	if (IsValidEntity(m_unEnt))
	{
		new Float:m_flClientOrigin[3];
		GetClientAbsOrigin(client, m_flClientOrigin);
		m_flClientOrigin[2]+=5.0;

		DispatchKeyValue(m_unEnt, "_light", g_eGlow[m_iData][GlowColor]); 
		DispatchKeyValue(m_unEnt, "brightness", g_eGlow[m_iData][GlowBrightness]); 
		DispatchKeyValueFloat(m_unEnt, "spotlight_radius", g_eGlow[m_iData][GlowflRadius]); 
		DispatchKeyValueFloat(m_unEnt, "distance", g_eGlow[m_iData][GlowflDistance]); 
		DispatchKeyValue(m_unEnt, "style", g_eGlow[m_iData][GlowStyle]);  

		DispatchSpawn(m_unEnt); 
		TeleportEntity(m_unEnt, m_flClientOrigin, NULL_VECTOR, NULL_VECTOR); 
		
		// Teleport the pet to the right fPosition and attach it
		TeleportEntity(m_unEnt, m_flClientOrigin, NULL_VECTOR, NULL_VECTOR); 
		
		SetVariantString("!activator");
		AcceptEntityInput(m_unEnt, "SetParent", client, m_unEnt, 0);
		
		SetVariantString("letthehungergamesbegin");
		AcceptEntityInput(m_unEnt, "SetParentAttachmentMaintainOffset", m_unEnt, m_unEnt, 0);
	  
		g_unClientGlow[client] = EntIndexToEntRef(m_unEnt);
		g_unLastAnimation[client] = -1;
	}
}

public ResetGlow(client)
{
	if(g_unClientGlow[client] == INVALID_ENT_REFERENCE)
		return;

	new m_unEnt = EntRefToEntIndex(g_unClientGlow[client]);
	g_unClientGlow[client] = INVALID_ENT_REFERENCE;
	if(m_unEnt == INVALID_ENT_REFERENCE)
		return;

	AcceptEntityInput(m_unEnt, "Kill");
}