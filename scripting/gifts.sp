#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <gifts>
#include <zephstocks>

#define PLUGIN_VERSION "2.3"

enum Module
{
	Handle:hPlugin_Module,
	Function:fnCallback_Module
}

enum SpawnedGift
{
	Handle:hPlugin,
	Function:fnCallback,
	Float:fPosition[3],
	String:szModel[PLATFORM_MAX_PATH],
	bool:bStay,
	iData,
	iOwner
}

new g_cvarChance = -1;
new g_cvarLifetime = -1;
new g_cvarModel = -1;

new bool:g_bEnabled = false;

new Handle:g_hPlugins = INVALID_HANDLE;
new Handle:g_hSpawned = INVALID_HANDLE;

new GiftConditions:g_eConditions[MAXPLAYERS+1];

new g_eSpawnedGiftsTemp[2048][SpawnedGift];
new g_eSpawnedGifts[2048][SpawnedGift];

public Plugin:myinfo =
{
	name = "[ANY] Gifts",
	author = "Zephyrus",
	description = "Gifts :333",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	IdentifyGame();

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
	g_cvarChance = RegisterConVar("sm_gifts_chance", "0.60", "Chance that a gift will be spawned upon player death.", TYPE_FLOAT, INVALID_FUNCTION, 0, true, 0.0, true, 1.0);
	g_cvarLifetime = RegisterConVar("sm_gifts_lifetime", "10.0", "Lifetime of the gift.", TYPE_FLOAT);

	new String:m_szGameDir[64];
	GetGameFolderName(STRING(m_szGameDir));
	
	if(strcmp(m_szGameDir, "cstrike")==0)
		g_cvarModel = RegisterConVar("sm_gifts_model", "models/items/cs_gift.mdl", "Model file for the gift", TYPE_STRING);
	else if(strcmp(m_szGameDir, "dod")==0)
		g_cvarModel = RegisterConVar("sm_gifts_model", "models/items/dod_gift.mdl", "Model file for the gift", TYPE_STRING);
	else if(strcmp(m_szGameDir, "tf")==0)
		g_cvarModel = RegisterConVar("sm_gifts_model", "models/items/tf_gift.mdl", "Model file for the gift", TYPE_STRING);
	else
		g_cvarModel = RegisterConVar("sm_gifts_model", "<you should set some gift model>", "Model file for the gift", TYPE_STRING);

	AutoExecConfig();

	g_hSpawned = CreateGlobalForward("Gifts_OnGiftSpawned", ET_Event, Param_Cell);
}

public OnMapStart()
{
	g_bEnabled = false;
	if(FileExists(g_eCvars[g_cvarModel].sCache) || FileExists(g_eCvars[g_cvarModel].sCache, true))
	{
		g_bEnabled = true;
		PrecacheModel(g_eCvars[g_cvarModel].sCache);
		Downloader_AddFileToDownloadsTable(g_eCvars[g_cvarModel].sCache);
	}

	for(new i=0;i<2048;++i)
		g_eSpawnedGifts[i][hPlugin]=INVALID_HANDLE;
}

public OnClientDisconnect(client)
{
	g_eConditions[client]=Condition_None;
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_hPlugins = CreateArray(2);

	CreateNative("Gifts_RegisterPlugin", Native_RegisterPlugin);
	CreateNative("Gifts_RemovePlugin", Native_RemovePlugin);
	CreateNative("Gifts_SetClientCondition", Native_SetClientCondition);
	CreateNative("Gifts_GetClientCondition", Native_GetClientCondition);
	CreateNative("Gifts_SpawnGift", Native_SpawnGift);

	return APLRes_Success;
}

public Native_RegisterPlugin(Handle:plugin, numParams)
{
	new m_szModule[Module];

	m_szModule[hPlugin_Module]=plugin;
	m_szModule[fnCallback_Module]=GetNativeCell(1);

	if(m_szModule[fnCallback_Module]==INVALID_FUNCTION)
		return 0;

	PushArrayArray(g_hPlugins, m_szModule[0]);
	
	return 1;
}

public Native_RemovePlugin(Handle:plugin, numParams)
{
	new m_szModule[Module];
	for(new i=0;i<GetArraySize(g_hPlugins);++i)
	{
		GetArrayArray(g_hPlugins, i, m_szModule[0]);
		if(m_szModule[hPlugin_Module]==plugin)
		{
			RemoveFromArray(g_hPlugins, i);
			return 1;
		}
	}
	return 0;
}

public Native_SetClientCondition(Handle:plugin, numParams)
{
	g_eConditions[GetNativeCell(1)]=GiftConditions:GetNativeCell(2);
	return 0;
}

public Native_GetClientCondition(Handle:plugin, numParams)
{
	return _:g_eConditions[GetNativeCell(1)];
}

public Native_SpawnGift(Handle:plugin, numParams)
{
	new Float:m_fLifetime = GetNativeCell(3);
	if(m_fLifetime == -2.0)
		m_fLifetime = g_eCvars[g_cvarLifetime].aCache;
	new Float:m_fPosition[3];
	new String:m_szModel[PLATFORM_MAX_PATH];
	GetNativeArray(4, m_fPosition, 3);
	GetNativeString(2, STRING(m_szModel));

	if(m_szModel[0] == 0)
		strcopy(STRING(m_szModel), g_eCvars[g_cvarModel].sCache);

	new m_iIndex = Stock_SpawnGift(m_fPosition, m_szModel, m_fLifetime);
	if(m_iIndex != -1)
	{
		g_eSpawnedGifts[m_iIndex][hPlugin] = plugin;
		g_eSpawnedGifts[m_iIndex][fnCallback] = GetNativeCell(1);
		g_eSpawnedGifts[m_iIndex][iData] = GetNativeCell(5);
		g_eSpawnedGifts[m_iIndex][iOwner] = GetNativeCell(6);
		g_eSpawnedGifts[m_iIndex][fPosition] = m_fPosition;
		g_eSpawnedGifts[m_iIndex][bStay] = (m_fLifetime == -1.0?true:false);
		strcopy(g_eSpawnedGifts[m_iIndex][szModel], PLATFORM_MAX_PATH, m_szModel);
	}
	return m_iIndex;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!g_bEnabled)
		return Plugin_Continue;

	if(Float:g_eCvars[g_cvarChance].aCache>0.0)
	{
		new random = GetRandomInt(1, RoundToNearest(100/(Float:g_eCvars[g_cvarChance].aCache*100)));
		if(random==1)
		{
			decl Float:pos[3];
			GetClientAbsOrigin(client, pos);

			if(g_bTF)
				pos[2]+=15.0;
			else
				pos[2]-=50.0;
			Stock_SpawnGift(pos, g_eCvars[g_cvarModel].sCache, Float:g_eCvars[g_cvarLifetime].aCache);
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=0;i<2048;++i)
		if(g_eSpawnedGifts[i][hPlugin])
		{
			// ugh......
			decl Float:m_fPosition[3];
			m_fPosition[0] = g_eSpawnedGifts[i][fPosition][0];
			m_fPosition[1] = g_eSpawnedGifts[i][fPosition][1];
			m_fPosition[2] = g_eSpawnedGifts[i][fPosition][2];
			new m_iIndex = Stock_SpawnGift(m_fPosition, g_eSpawnedGifts[i][szModel], 0.0);

			if(m_iIndex != -1)
			{
				g_eSpawnedGiftsTemp[m_iIndex][hPlugin] = g_eSpawnedGifts[i][hPlugin];
				g_eSpawnedGiftsTemp[m_iIndex][fnCallback] = g_eSpawnedGifts[i][fnCallback];
				g_eSpawnedGiftsTemp[m_iIndex][iData] = g_eSpawnedGifts[i][iData];
				g_eSpawnedGiftsTemp[m_iIndex][iOwner] = g_eSpawnedGifts[i][iOwner];
				g_eSpawnedGiftsTemp[m_iIndex][fPosition] = g_eSpawnedGifts[i][fPosition]
				g_eSpawnedGiftsTemp[m_iIndex][bStay] = g_eSpawnedGifts[i][bStay];
				strcopy(g_eSpawnedGiftsTemp[m_iIndex][szModel], PLATFORM_MAX_PATH, g_eSpawnedGifts[i][szModel]);
			}
		}
	for(new i=0;i<2048;++i)
	{
		if(g_eSpawnedGiftsTemp[i][hPlugin])
		{
			g_eSpawnedGifts[i][hPlugin] = g_eSpawnedGiftsTemp[i][hPlugin];
			g_eSpawnedGifts[i][fnCallback] = g_eSpawnedGiftsTemp[i][fnCallback];
			g_eSpawnedGifts[i][iData] = g_eSpawnedGiftsTemp[i][iData];
			g_eSpawnedGifts[i][iOwner] = g_eSpawnedGiftsTemp[i][iOwner];
			g_eSpawnedGifts[i][fPosition] = g_eSpawnedGiftsTemp[i][fPosition]
			g_eSpawnedGifts[i][bStay] = g_eSpawnedGiftsTemp[i][bStay];
			strcopy(g_eSpawnedGifts[i][szModel], PLATFORM_MAX_PATH, g_eSpawnedGiftsTemp[i][szModel]);
		}
		else
		{
			g_eSpawnedGifts[i][hPlugin] = INVALID_HANDLE;
			g_eSpawnedGifts[i][fnCallback] = INVALID_FUNCTION;
		}
	}

	return Plugin_Continue;
}

stock Stock_SpawnGift(Float:position[3], const String:model[], Float:lifetime)
{
	decl m_iGift;

	if((m_iGift = CreateEntityByName("prop_physics_override")) != -1)
	{
		new String:targetname[100], String:m_szModule[256];

		Format(STRING(targetname), "gift_%i", m_iGift);

		DispatchKeyValue(m_iGift, "model", model);
		DispatchKeyValue(m_iGift, "physicsmode", "2");
		DispatchKeyValue(m_iGift, "massScale", "1.0");
		DispatchKeyValue(m_iGift, "targetname", targetname);
		DispatchSpawn(m_iGift);
		
		SetEntProp(m_iGift, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(m_iGift, Prop_Send, "m_CollisionGroup", 1);
		
		if(lifetime > 0.0)
		{
			Format(m_szModule, sizeof(m_szModule), "OnUser1 !self:kill::%0.2f:-1", lifetime);
			SetVariantString(m_szModule);
			AcceptEntityInput(m_iGift, "AddOutput");
			AcceptEntityInput(m_iGift, "FireUser1");
		}
	
		TeleportEntity(m_iGift, position, NULL_VECTOR, NULL_VECTOR);
		
		if(!g_bTF)
		{
			new m_iRotator = CreateEntityByName("func_rotating");
			DispatchKeyValueVector(m_iRotator, "origin", position);
			DispatchKeyValue(m_iRotator, "targetname", targetname);
			DispatchKeyValue(m_iRotator, "maxspeed", "200");
			DispatchKeyValue(m_iRotator, "friction", "0");
			DispatchKeyValue(m_iRotator, "dmg", "0");
			DispatchKeyValue(m_iRotator, "solid", "0");
			DispatchKeyValue(m_iRotator, "spawnflags", "64");
			DispatchSpawn(m_iRotator);
			
			SetVariantString("!activator");
			AcceptEntityInput(m_iGift, "SetParent", m_iRotator, m_iRotator);
			AcceptEntityInput(m_iRotator, "Start");

			if(lifetime > 0.0)
			{
				SetVariantString(m_szModule);
				AcceptEntityInput(m_iRotator, "AddOutput");
				AcceptEntityInput(m_iRotator, "FireUser1");
			}
			
			SetEntPropEnt(m_iGift, Prop_Send, "m_hEffectEntity", m_iRotator);
		}

		SDKHook(m_iGift, SDKHook_StartTouch, OnStartTouch);
	}

	Call_StartForward(g_hSpawned);
	Call_PushCell(m_iGift);
	Call_Finish();

	return m_iGift;
}

public OnStartTouch(m_iGift, client)
{
	if(!(0<client<=MaxClients))
		return;

	if(g_eConditions[client]==Condition_InCondition)
		return;

	if(g_eSpawnedGifts[m_iGift][hPlugin] != INVALID_HANDLE)
		if(g_eSpawnedGifts[m_iGift][iOwner] == client)
			return;

	new m_iRotator = GetEntPropEnt(m_iGift, Prop_Send, "m_hEffectEntity");
	if(m_iRotator && IsValidEdict(m_iRotator))
		AcceptEntityInput(m_iRotator, "Kill");
	CreateTimer(0.0, RemoveEntityGift, m_iGift);

	if(g_eSpawnedGifts[m_iGift][hPlugin] != INVALID_HANDLE)
	{
		Call_StartFunction(g_eSpawnedGifts[m_iGift][hPlugin], g_eSpawnedGifts[m_iGift][fnCallback]);
		Call_PushCell(client);
		Call_PushCell(g_eSpawnedGifts[m_iGift][iData]);
		Call_PushCell(g_eSpawnedGifts[m_iGift][iOwner]);
		Call_Finish();
		g_eSpawnedGifts[m_iGift][hPlugin] = INVALID_HANDLE;
	}
	else if(GetArraySize(g_hPlugins)!=0)
	{
		new id = GetRandomInt(0, GetArraySize(g_hPlugins)-1);
		
		new m_szModule[Module];
		GetArrayArray(g_hPlugins, id, m_szModule[0]);
		
		Call_StartFunction(m_szModule[hPlugin_Module], m_szModule[fnCallback_Module]);
		Call_PushCell(client);
		Call_PushCell(m_iGift);
		Call_Finish();
	}
}

public Action:RemoveEntityGift(Handle:timer, any:m_iGift)
{
	if(IsValidEntity(m_iGift))
		AcceptEntityInput(m_iGift, "Kill");
	return Plugin_Stop;
}