#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

new g_eWeaponColors[STORE_MAX_ITEMS][4];

new g_iWeaponColors = 0;

new bool:g_bColored[2048];

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public WeaponColors_OnPluginStart()
#endif
{
#if !defined STANDALONE_BUILD
	// This is not a standalone build, we don't want hats to kill the whole plugin for us	
	if(GetExtensionFileStatus("sdkhooks.ext")!=1)
	{
		LogError("SDKHooks isn't installed or failed to load. Hats will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
#endif
	Store_RegisterHandler("weaponcolor", "color", WeaponColors_OnMapStart, WeaponColors_Reset, WeaponColors_Config, WeaponColors_Equip, WeaponColors_Remove, true);
}

#if defined STANDALONE_BUILD
public OnClientPutInServer(client)
#else
public WeaponColors_OnClientPutInServer(client)
#endif
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponColors_WeaponCanUse);
}

public WeaponColors_OnMapStart()
{
}

public WeaponColors_Reset()
{
	g_iWeaponColors = 0;
}

public WeaponColors_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iWeaponColors);
	
	KvGetColor(kv, "color", g_eWeaponColors[g_iWeaponColors][0], g_eWeaponColors[g_iWeaponColors][1], g_eWeaponColors[g_iWeaponColors][2], g_eWeaponColors[g_iWeaponColors][3]);
	
	++g_iWeaponColors;
	return true;
}

public WeaponColors_Equip(client, id)
{
	if(!IsValidEdict(client))
		return 0;
	for(new i=0;i<48;++i)
	{
		new m_iEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if(m_iEntity == -1)
			continue;
		g_bColored[m_iEntity] = false;
	}
	return 0;
}

public WeaponColors_Remove(client)
{
	for(new i=0;i<48;++i)
	{
		new m_iEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if(m_iEntity == -1)
			continue;
		CS_OnCSWeaponDrop(client, m_iEntity);
	}
	return 0;
}

public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
	if(g_iWeaponColors==0)
		return Plugin_Continue;

	SetEntityRenderColor(weaponIndex, 255, 255, 255, 255);
	g_bColored[weaponIndex] = false;
	return Plugin_Continue;
}

public Action:WeaponColors_WeaponCanUse(client, weapon)
{
	if(g_iWeaponColors==0)
		return Plugin_Continue;
		
	if(g_bColored[weapon])
		return Plugin_Continue;
	
	new Handle:data = CreateDataPack();
	WritePackCell(data, GetClientUserId(client));
	WritePackCell(data, weapon);
	ResetPack(data);
	
	CreateTimer(0.0, Timer_ColorWeapon, data);
	
	return Plugin_Continue;
}

public Action:Timer_ColorWeapon(Handle:timer, any:data)
{
	new userid = ReadPackCell(data);
	new weapon = ReadPackCell(data);
	CloseHandle(data);

	new client = GetClientOfUserId(userid);
	
	if(!client || !IsValidEdict(weapon))
		return Plugin_Stop;
	
	new m_iEquipped = Store_GetEquippedItem(client, "weaponcolor", 0);
	if(m_iEquipped<0)
		return Plugin_Stop;
	new m_iData = Store_GetDataIndex(m_iEquipped);

	SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
	SetEntityRenderColor(weapon, g_eWeaponColors[m_iData][0], g_eWeaponColors[m_iData][1], g_eWeaponColors[m_iData][2], g_eWeaponColors[m_iData][3]);
	g_bColored[weapon]=true;

	return Plugin_Stop;
}