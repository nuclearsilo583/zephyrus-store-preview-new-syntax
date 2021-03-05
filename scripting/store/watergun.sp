#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Watergun_OnPluginStart()
#endif
{
	if(GAME_TF2)
		return;

	Store_RegisterHandler("watergun", "", Watergun_OnMapStart, Watergun_Reset, Watergun_Config, Watergun_Equip, Watergun_Remove, true);
	
	HookEvent("player_hurt", Watergun_PlayerHurt);
}

public Watergun_OnMapStart()
{
}

public Watergun_Reset()
{
}

public Watergun_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public Watergun_Equip(client, id)
{
	return -1;
}

public Watergun_Remove(client, id)
{
}

public Action:Watergun_PlayerHurt(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(client == attacker || !attacker)
		return Plugin_Continue;

	new m_iEquipped = Store_GetEquippedItem(attacker, "watergun");
	if(m_iEquipped >= 0)
	{
		SetVariantString("WaterSurfaceExplosion");
		AcceptEntityInput(client, "DispatchEffect");
	}
	
	return Plugin_Continue;
}