#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

#endif

enum AdminItem
{
	String:szFlags[32],
	GroupId:nGroup,
	nImmunity
}

new g_eAdmins[STORE_MAX_ITEMS][AdminItem];
new g_iAdmins = 0;

public AdminGroup_OnPluginStart()
{
	Store_RegisterHandler("admin", "group", AdminGroup_OnMapStart, AdminGroup_Reset, AdminGroup_Config, AdminGroup_Equip, AdminGroup_Remove, true);
}

public AdminGroup_OnMapStart()
{
}

public AdminGroup_Reset()
{
	g_iAdmins = 0;
}

public AdminGroup_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iAdmins);

	new String:group[64];
	KvGetString(kv, "flags", g_eAdmins[g_iAdmins][szFlags], 32);
	KvGetString(kv, "group", STRING(group));

	g_eAdmins[g_iAdmins][nGroup]=FindAdmGroup(group);
	g_eAdmins[g_iAdmins][nImmunity]=KvGetNum(kv, "immunity");

	++g_iAdmins;
	return true;
}

public AdminGroup_Equip(client, id)
{
	new data = Store_GetDataIndex(id);

	new AdminId:Admin = GetUserAdmin(client);
	if(Admin == INVALID_ADMIN_ID)
	{
		Admin = CreateAdmin();
		SetUserAdmin(client, Admin);
	}

	if(g_eAdmins[data][nGroup] != INVALID_GROUP_ID)
		AdminInheritGroup(Admin, g_eAdmins[data][nGroup]);

	if(GetAdminImmunityLevel(Admin) < g_eAdmins[data][nImmunity])
		SetAdminImmunityLevel(Admin,  g_eAdmins[data][nImmunity]);

	new String:tmp[32];
	strcopy(STRING(tmp), g_eAdmins[data][szFlags]);
	new len = strlen(tmp);
	new AdminFlag:flag;
	for (new i=0; i<len; i++)
	{
		if (!FindFlagByChar(tmp[i], flag))
			continue;
		SetAdminFlag(Admin, flag, true);
	}

	RunAdminCacheChecks(client);

	return -1;
}

public AdminGroup_Remove(client, id)
{
}