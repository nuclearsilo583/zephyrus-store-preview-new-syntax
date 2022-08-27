#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new g_cvarFuel = -1;
new g_cvarRegen = -1;
new g_cvarMinimum = -1;
new g_cvarForce = -1;
new g_cvarCommand = -1;

new Float:g_fFuel[MAXPLAYERS+1];
new Float:g_fTime[MAXPLAYERS+1];
new Float:g_fLastHUDTime[MAXPLAYERS+1];

new bool:g_bJetpacking[MAXPLAYERS+1]={false,...};

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Jetpack_OnPluginStart()
#endif
{
	Store_RegisterHandler("jetpack", "", Jetpack_OnMapStart, Jetpack_Reset, Jetpack_Config, Jetpack_Equip, Jetpack_Remove, true);

	g_cvarFuel = RegisterConVar("sm_store_jetpack_fuel", "1.0", "A full fuel tank, in seconds.", TYPE_FLOAT);
	g_cvarRegen = RegisterConVar("sm_store_jetpack_regen", "0.1", "Fuel in seconds regenerated per second.", TYPE_FLOAT);
	g_cvarMinimum = RegisterConVar("sm_store_jetpack_minimum", "0.1", "Minimum amount of fuel in seconds needed to start the jetpack.", TYPE_FLOAT);
	g_cvarForce = RegisterConVar("sm_store_jetpack_force", "12.0", "Lifting velocity.", TYPE_FLOAT);
	g_cvarCommand = RegisterConVar("sm_store_jetpack_command", "jetpack", "Command for the jetpack. +/- will be applied to it for toggling", TYPE_STRING);
}

public Jetpack_OnMapStart()
{
}

public Jetpack_OnConfigsExecuted()
{
	new String:m_szCommand[64];
	strcopy(m_szCommand[1], sizeof(m_szCommand)-1, g_eCvars[g_cvarCommand][sCache]);
	m_szCommand[0]='+';
	RegConsoleCmd(m_szCommand, Command_JetpackOn);
	m_szCommand[0]='-';
	RegConsoleCmd(m_szCommand, Command_JetpackOff);
}

public Jetpack_Reset()
{
}

public Jetpack_OnClientConnected(client)
{
	g_bJetpacking[client]=false;
}

public Jetpack_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public Jetpack_Equip(client, id)
{
	return -1;
}

public Jetpack_Remove(client, id)
{
}

public Action:Command_JetpackOn(client, args)
{
	g_bJetpacking[client]=true;
	return Plugin_Handled;
}

public Action:Command_JetpackOff(client, args)
{
	g_bJetpacking[client]=false;
	return Plugin_Handled;
}

#if defined STANDALONE_BUILD
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
#else
public Jetpack_OnPlayerRunCmd(client, buttons)
#endif
{
	new m_iEquipped = Store_GetEquippedItem(client, "jetpack");
	if(m_iEquipped < 0)
#if defined STANDALONE_BUILD
		return Plugin_Continue;
#else
		return;
#endif

	new Float:m_fTime = GetGameTime();	 
	if (g_bJetpacking[client])
	{
		if (g_fFuel[client] > g_eCvars[g_cvarMinimum][aCache])
		{
			decl Float:m_fVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", m_fVelocity);
	 
			m_fVelocity[2] += Float:g_eCvars[g_cvarForce][aCache];
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, m_fVelocity);
	 
			g_fFuel[client] -= m_fTime - g_fTime[client];
			if (g_fFuel[client] < 0.0)
				g_fFuel[client] = 0.0;
		}
		else
			g_fFuel[client] = 0.0;
	}
		 
	if (g_fFuel[client] < g_eCvars[g_cvarFuel][aCache])
	{
		g_fFuel[client] += (m_fTime - g_fTime[client]) * Float:g_eCvars[g_cvarRegen][aCache];
		if (g_fFuel[client] > g_eCvars[g_cvarFuel][aCache])
			g_fFuel[client] = g_eCvars[g_cvarFuel][aCache];
	}
	 
	if (g_fFuel[client] != g_eCvars[g_cvarFuel][aCache] && g_fLastHUDTime[client] + 0.1 < m_fTime)
	{
		PrintHintText(client, "%t", "Jetpack Fuel", g_fFuel[client]);
		g_fLastHUDTime[client] = m_fTime;
	}
	 
	g_fTime[client] = m_fTime;

#if defined STANDALONE_BUILD
	return Plugin_Continue;
#endif
}