#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public Attributes_OnPluginStart()
#endif
{
	HookEvent("player_spawn", Attributes_PlayerSpawn);
}

public Action:Attributes_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	// Reset client
	SetEntityGravity(client, 1.0);

	new idx = -1;
	new item_idx = -1;
	new item[Store_Item];
	decl String:m_szValue[16];
	while((item_idx=Store_IterateEquippedItems(client, idx, true))!=-1)
	{
		Store_GetItem(item_idx, item);

		if(GetTrieString(item[hAttributes], "health", STRING(m_szValue)))
		{
			SetEntityHealth(client, GetClientHealth(client)+StringToInt(m_szValue));
		}

		if(GetTrieString(item[hAttributes], "gravity", STRING(m_szValue)))
		{
			SetEntityGravity(client, StringToFloat(m_szValue));
		}

		if(GetTrieString(item[hAttributes], "armor", STRING(m_szValue)))
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue")+StringToInt(m_szValue));
		}
	}

	return Plugin_Continue;
}