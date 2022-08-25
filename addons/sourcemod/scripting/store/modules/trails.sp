#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

new bool:GAME_CSGO = false;
new bool:GAME_TF2 = false;
#endif

#if defined REQUIRE_PLUGIN
#undef REQUIRE_PLUGIN
#endif
#include <hidetrails>

enum Trail
{
	String:szMaterial[PLATFORM_MAX_PATH],
	String:szWidth[16],
	String:szColor[16],
	Float:fWidth,
	iColor[4],
	iSlot,
	iCacheID
}
new g_eTrails[STORE_MAX_ITEMS][Trail];

new g_iTrails = 0;
new g_iClientTrails[MAXPLAYERS+1][STORE_MAX_SLOTS];

new g_bSpawnTrails[MAXPLAYERS+1];

new Float:g_fClientCounters[MAXPLAYERS+1];
new Float:g_fLastPosition[MAXPLAYERS+1][3];

new g_cvarPadding = -1;
new g_cvarMaxColumns = -1;
new g_cvarTrailLife = -1;

new g_iTrailOwners[2048]={-1};

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Trails_OnPluginStart()
#endif
{
#if defined STANDALONE_BUILD
	new String:m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	
	if(strcmp(m_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	else if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
#endif
	g_cvarPadding = RegisterConVar("sm_store_trails_padding", "30.0", "Space between two trails", TYPE_FLOAT);
	g_cvarMaxColumns = RegisterConVar("sm_store_trails_columns", "3", "Number of columns before starting to increase altitude", TYPE_INT);
	g_cvarTrailLife = RegisterConVar("sm_store_trails_life", "1.0", "Life of a trail in seconds", TYPE_FLOAT);
	
	Store_RegisterHandler("trail", "material", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);
	
	HookEvent("player_spawn", Trails_PlayerSpawn);
	HookEvent("player_death", Trails_PlayerDeath);
}

public Trails_OnMapStart()
{
	for(new a=0;a<=MaxClients;++a)
		for(new b=0;b<STORE_MAX_SLOTS;++b)
			g_iClientTrails[a][b]=0;

	for(new i=0;i<g_iTrails;++i)
	{
		g_eTrails[i][iCacheID] = PrecacheModel2(g_eTrails[i][szMaterial], true);
		Downloader_AddFileToDownloadsTable(g_eTrails[i][szMaterial]);
	}
}

public Trails_Reset()
{
	g_iTrails = 0;
}

public Trails_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iTrails);
	KvGetString(kv, "material", g_eTrails[g_iTrails][szMaterial], PLATFORM_MAX_PATH);
	KvGetString(kv, "width", g_eTrails[g_iTrails][szWidth], 16, "10.0");
	g_eTrails[g_iTrails][fWidth] = KvGetFloat(kv, "width", 10.0);
	KvGetString(kv, "color", g_eTrails[g_iTrails][szColor], 16, "255 255 255");
	KvGetColor(kv, "color", g_eTrails[g_iTrails][iColor][0], g_eTrails[g_iTrails][iColor][1], g_eTrails[g_iTrails][iColor][2], g_eTrails[g_iTrails][iColor][3]);
	g_eTrails[g_iTrails][iSlot] = KvGetNum(kv, "slot");
	
	if(FileExists(g_eTrails[g_iTrails][szMaterial], true))
	{
		++g_iTrails;
		return true;
	}
	
	return false;
}

public Trails_Equip(client, id)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return -1;
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	return g_eTrails[Store_GetDataIndex(id)][iSlot];
}

public Trails_Remove(client, id)
{
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	return  g_eTrails[Store_GetDataIndex(id)][iSlot];
}

public Action:Timer_CreateTrails(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	for(new i=0;i<STORE_MAX_SLOTS;++i)
	{
		RemoveTrail(client, i);
		CreateTrail(client, -1, i);
	}
	return Plugin_Stop;
}

public Action:Trails_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
	
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	
	return Plugin_Continue;
}

public Action:Trails_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsPlayerAlive(client))
		for(new i=0;i<STORE_MAX_SLOTS;++i)
			RemoveTrail(client, i);
	return Plugin_Continue;
}

CreateTrail(client, itemid=-1, slot=0)
{
	new m_iEquipped = (itemid==-1?Store_GetEquippedItem(client, "trail", slot):itemid);
	if(m_iEquipped >= 0)
	{
		new m_iData = Store_GetDataIndex(m_iEquipped);
		
		new m_aEquipped[STORE_MAX_SLOTS] = {-1,...};
		new m_iNumEquipped = 0;
		decl m_iCurrent;
		for(new i=0;i<STORE_MAX_SLOTS;++i)
			if((m_aEquipped[m_iNumEquipped] = Store_GetEquippedItem(client, "trail", i))>=0)
			{
				if(i == g_eTrails[m_iData][iSlot])
					m_iCurrent = m_iNumEquipped;
				++m_iNumEquipped;
			}
		
		if(GAME_CSGO)
		{
			if(g_iClientTrails[client][slot] == 0 || !IsValidEdict(g_iClientTrails[client][slot]))
			{
				g_iClientTrails[client][slot] = CreateEntityByName("env_sprite");
				DispatchKeyValue(g_iClientTrails[client][slot], "classname", "env_sprite");
				DispatchKeyValue(g_iClientTrails[client][slot], "spawnflags", "1");
				DispatchKeyValue(g_iClientTrails[client][slot], "scale", "0.0");
				DispatchKeyValue(g_iClientTrails[client][slot], "rendermode", "10");
				DispatchKeyValue(g_iClientTrails[client][slot], "rendercolor", "255 255 255 0");
				DispatchKeyValue(g_iClientTrails[client][slot], "model", g_eTrails[m_iData][szMaterial]);
				DispatchSpawn(g_iClientTrails[client][slot]);
				AttachTrail(g_iClientTrails[client][slot], client, m_iCurrent, m_iNumEquipped);	
				SDKHook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
			}
			
			//Ugh...
			decl m_iColor[4];
			m_iColor[0] = g_eTrails[m_iData][iColor][0];
			m_iColor[1] = g_eTrails[m_iData][iColor][1];
			m_iColor[2] = g_eTrails[m_iData][iColor][2];
			m_iColor[3] = g_eTrails[m_iData][iColor][3];
			TE_SetupBeamFollow(g_iClientTrails[client][slot], g_eTrails[m_iData][iCacheID], 0, Float:g_eCvars[g_cvarTrailLife][aCache], g_eTrails[m_iData][fWidth], g_eTrails[m_iData][fWidth], 10, m_iColor);
			TE_SendToAll();
		}
		else
		{
			new m_iEnt = CreateEntityByName("env_spritetrail");
			SetEntPropFloat(m_iEnt, Prop_Send, "m_flTextureRes", 0.05);

			DispatchKeyValue(m_iEnt, "renderamt", "255");
			DispatchKeyValue(m_iEnt, "rendercolor", g_eTrails[m_iData][szColor]);
			DispatchKeyValue(m_iEnt, "lifetime", g_eCvars[g_cvarTrailLife][sCache]);
			DispatchKeyValue(m_iEnt, "rendermode", "5");
			DispatchKeyValue(m_iEnt, "spritename", g_eTrails[m_iData][szMaterial]);
			DispatchKeyValue(m_iEnt, "startwidth", g_eTrails[m_iData][szWidth]);
			DispatchKeyValue(m_iEnt, "endwidth", g_eTrails[m_iData][szWidth]);
			DispatchSpawn(m_iEnt);
			
			AttachTrail(m_iEnt, client, m_iCurrent, m_iNumEquipped);
				
			g_iClientTrails[client][g_eTrails[m_iData][iSlot]]=m_iEnt;
			SDKHook(m_iEnt, SDKHook_SetTransmit, Hook_TrailSetTransmit);	

			g_iTrailOwners[m_iEnt]=client;		
		}
	}
}

public RemoveTrail(client, slot)
{
	if(g_iClientTrails[client][slot] != 0 && IsValidEdict(g_iClientTrails[client][slot]))
	{
		g_iTrailOwners[g_iClientTrails[client][slot]]=-1;

		new String:m_szClassname[64];
		GetEdictClassname(g_iClientTrails[client][slot], STRING(m_szClassname));
		if(strcmp("env_spritetrail", m_szClassname)==0)
		{
			SDKUnhook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
			AcceptEntityInput(g_iClientTrails[client][slot], "Kill");
		}
	}
	g_iClientTrails[client][slot]=0;
}

public AttachTrail(ent, client, current, num)
{
	decl Float:m_fOrigin[3], Float:m_fAngle[3];
	new Float:m_fTemp[3] = {0.0, 90.0, 0.0};
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fTemp);
	new Float:m_fX = (Float:g_eCvars[g_cvarPadding][aCache]*((num-1)%g_eCvars[g_cvarMaxColumns][aCache]))/2-(Float:g_eCvars[g_cvarPadding][aCache]*(current%g_eCvars[g_cvarMaxColumns][aCache]));
	decl Float:m_fPosition[3];
	m_fPosition[0] = m_fX;
	m_fPosition[1] = 0.0;
	m_fPosition[2]= 5.0+(current/g_eCvars[g_cvarMaxColumns][aCache])*Float:g_eCvars[g_cvarPadding][aCache];
	GetClientAbsOrigin(client, m_fOrigin);
	AddVectors(m_fOrigin, m_fPosition, m_fOrigin);
	TeleportEntity(ent, m_fOrigin, m_fTemp, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
}

#if defined STANDALONE_BUILD
public OnGameFrame()
#else
public Trails_OnGameFrame()
#endif
{
	if(!GAME_CSGO)
		return;

	if(GetGameTickCount()%6 != 0)
		return;	

	new Float:m_fTime = GetEngineTime();
	decl Float:m_fPosition[3];
	LoopAlivePlayers(i)
	{
		GetClientAbsOrigin(i, m_fPosition);
		if(GetVectorDistance(g_fLastPosition[i], m_fPosition)<=5.0)
		{
			if(!g_bSpawnTrails[i])
				if(m_fTime-g_fClientCounters[i]>=Float:g_eCvars[g_cvarTrailLife][aCache]/2)
					g_bSpawnTrails[i] = true;
		}
		else
		{
			if(g_bSpawnTrails[i])
			{
				g_bSpawnTrails[i] = false;
				TE_Start("KillPlayerAttachments");
				TE_WriteNum("m_nPlayer",i);
				TE_SendToAll();
				for(new a=0;a<STORE_MAX_SLOTS;++a)
					CreateTrail(i, -1, a);
			}
			else
				g_fClientCounters[i] = m_fTime;
			g_fLastPosition[i] = m_fPosition;
		}
	}
}

public Action:Hook_TrailSetTransmit(ent, client)
{
	new Hide = ShouldHideTrail(client, ent);
	if(Hide)
	{
		if(Hide == 2)
			return Plugin_Handled;
		else if(Hide == 1)
		{
			for(new i=0;i<STORE_MAX_SLOTS;++i)
				if(g_iClientTrails[client][i]==ent)
					return Plugin_Continue;
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

stock ShouldHideTrail(client, ent)
{
	if(GAME_TF2)
	{
		if(1<=g_iTrailOwners[ent]<=MaxClients)
		{
			if(TF2_IsPlayerInCondition(g_iTrailOwners[ent], TFCond_Cloaked))
			{
				return 2;
			}
		}
	}

	static Available = -1;
	if(Available==-1)
		Available = GetFeatureStatus(FeatureType_Native, "HideTrails_ShouldHide")==FeatureStatus_Available?1:0;

	if(Available == 1)
	{
		return HideTrails_ShouldHide(client);
	}
	return 0;
}