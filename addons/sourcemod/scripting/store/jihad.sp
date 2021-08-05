#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

enum Jihad
{
	Float:flRadius,
	Float:flDamage,
	bool:bSilent,
	Float:flDelay,
	Float:flFailrate,
}

new g_eJihads[STORE_MAX_ITEMS][Jihad];

new g_iJihads = 0;
new g_iExplosion = -1;

new g_cvarJihadTK = -1;
new g_cvarJihadTeam = -1;
new g_cvarJihadExplosionSound = -1;
new g_cvarJihadBeforeSound = -1;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Jihad_OnPluginStart()
#endif
{
	Store_RegisterHandler("jihad", "", Jihad_OnMapStart, Jihad_Reset, Jihad_Config, Jihad_Equip, Jihad_Remove, false);

	g_cvarJihadTK = RegisterConVar("sm_store_jihad_teamkill", "0", "Defines whether the bombs kill teammates or not.", TYPE_INT);
	g_cvarJihadTeam = RegisterConVar("sm_store_jihad_team", "0", "Team that can use the bomb. 0=Any 2=Terrorist 3=Counter-Terrorist", TYPE_INT);
	g_cvarJihadExplosionSound = RegisterConVar("sm_store_jihad_explosion_sound", "ambient/explosions/explode_1.wav", "Path to the explosion sound", TYPE_STRING);
	g_cvarJihadBeforeSound = RegisterConVar("sm_store_jihad_activation_sound", "npc/roller/mine/combine_mine_active_loop1.wav", "Path to the activation sound", TYPE_STRING);
}

public Jihad_OnConfigsExecuted()
{
	new String:m_szSound[PLATFORM_MAX_PATH];
	if(g_eCvars[g_cvarJihadExplosionSound][sCache][0]!=0 && FileExists(g_eCvars[g_cvarJihadExplosionSound][sCache], true))
	{
		PrecacheSound(g_eCvars[g_cvarJihadExplosionSound][sCache]);
		Format(STRING(m_szSound), "sound/%s", g_eCvars[g_cvarJihadExplosionSound][sCache]);
		AddFileToDownloadsTable(m_szSound);
	}
	
	if(g_eCvars[g_cvarJihadBeforeSound][sCache][0]!=0 && FileExists(g_eCvars[g_cvarJihadBeforeSound][sCache], true))
	{
		PrecacheSound(g_eCvars[g_cvarJihadBeforeSound][sCache]);
		Format(STRING(m_szSound), "sound/%s", g_eCvars[g_cvarJihadBeforeSound][sCache]);
		AddFileToDownloadsTable(m_szSound);
	}
}

public Jihad_OnMapStart()
{
	g_iExplosion = PrecacheModel2("materials/effects/fire_cloud1.vmt",false);
}

public Jihad_Reset()
{
	g_iJihads = 0;
}

public Jihad_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iJihads);
	
	g_eJihads[g_iJihads][flRadius] = KvGetFloat(kv, "radius");
	g_eJihads[g_iJihads][flDamage] = KvGetFloat(kv, "damage");
	g_eJihads[g_iJihads][bSilent] = (KvGetNum(kv, "silent")?true:false);
	g_eJihads[g_iJihads][flDelay] = KvGetFloat(kv, "delay");
	g_eJihads[g_iJihads][flFailrate] = KvGetFloat(kv, "failrate");

	++g_iJihads;
	return true;
}

public Jihad_Equip(client, id)
{
	new m_iData = Store_GetDataIndex(id);
	
	if(g_eCvars[g_cvarJihadTeam][aCache] != 0 && g_eCvars[g_cvarJihadTeam][aCache]!=GetClientTeam(client))
	{
		Chat(client, "%t", "Jihad Wrong Team");
		return 1;
	}

	if(!g_eJihads[m_iData][bSilent])
		if(g_eCvars[g_cvarJihadBeforeSound][sCache][0]!=0)
			EmitAmbientSound(g_eCvars[g_cvarJihadBeforeSound][sCache], NULL_VECTOR, client);
	
	new Handle:data = CreateDataPack();
	WritePackCell(data, GetClientUserId(client));
	WritePackCell(data, m_iData);
	ResetPack(data);

	CreateTimer(g_eJihads[m_iData][flDelay], Jihad_TriggerBomb, data);

	return 0;
}

public Jihad_Remove(client)
{
	return 0;
}

public Action:Jihad_TriggerBomb(Handle:timer, any:data)
{
	new userid = ReadPackCell(data);
	new m_iData = ReadPackCell(data);
	CloseHandle(data);

	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	

	if(GetRandomFloat() <= g_eJihads[m_iData][flFailrate])
	{
		Chat(client, "%t", "Jihad Failed");
		return Plugin_Stop;
	}
	
	if(g_eCvars[g_cvarJihadBeforeSound][sCache][0]!=0)
		EmitAmbientSound(g_eCvars[g_cvarJihadExplosionSound][sCache], NULL_VECTOR, client);
	
	new Float:m_flPos[3];
	new Float:m_flPos2[3];
	new Float:m_flPush[3];

	GetClientAbsOrigin(client, m_flPos);

	TE_SetupSmoke(m_flPos, g_iExplosion, 10.0, 10);
	TE_SendToAll();
	

	new Handle:m_hData = CreateDataPack();
	WritePackCell(m_hData, 0);
	WritePackCell(m_hData, client);
	WritePackFloat(m_hData, float(GetClientHealth(client))*10);
	WritePackFloat(m_hData, 0.0);
	WritePackFloat(m_hData, 0.0);
	WritePackFloat(m_hData, 100.0);
	ResetPack(m_hData);

	CreateTimer(0.0, ExplodePlayer, m_hData);
	
	new Float:m_flDistance;
	LoopAlivePlayers(i)
	{
		if(!g_eCvars[g_cvarJihadTK][aCache] && GetClientTeam(i)==GetClientTeam(client))
			continue;
		
		GetClientAbsOrigin(i, m_flPos2);
		m_flDistance = GetVectorDistance(m_flPos, m_flPos2);
		
		if(m_flDistance <= g_eJihads[m_iData][flRadius])
		{
			MakeVectorFromPoints(m_flPos, m_flPos2, m_flPush);
			ScaleVector(m_flPush, 50.0);
			m_flPush[2]+=50.0;

			m_hData = CreateDataPack();
			WritePackCell(m_hData, client);
			WritePackCell(m_hData, i);
			WritePackFloat(m_hData, g_eJihads[m_iData][flDamage]*((g_eJihads[m_iData][flRadius]-m_flDistance)/g_eJihads[m_iData][flRadius]));
			WritePackFloat(m_hData, m_flPush[0]);
			WritePackFloat(m_hData, m_flPush[1]);
			WritePackFloat(m_hData, m_flPush[2]);
			ResetPack(m_hData);

			CreateTimer(0.0, ExplodePlayer, m_hData);
		}
	}

	return Plugin_Stop;
}

public Action:ExplodePlayer(Handle:timer, any:data)
{
	new attacker = ReadPackCell(data);
	new victim = ReadPackCell(data);
	new Float:damage = ReadPackFloat(data);
	new Float:vec[3];
	vec[0] = ReadPackFloat(data);
	vec[1] = ReadPackFloat(data);
	vec[2] = ReadPackFloat(data);
	CloseHandle(data);

	SDKHooks_TakeDamage(victim, attacker, attacker, damage, DMG_BLAST, -1, vec);
	return Plugin_Stop;
}