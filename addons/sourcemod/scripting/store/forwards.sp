Handle gf_hPreviewItem;
Handle gf_hOnConfigExecuted;
//Handle gf_hOnBuyItem;

void Store_Forward_OnForwardInit()
{
	gf_hPreviewItem = CreateGlobalForward("Store_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	gf_hOnConfigExecuted = CreateGlobalForward("Store_OnConfigExecuted", ET_Ignore, Param_String);
	//gf_hOnBuyItem = CreateGlobalForward("Store_OnBuyItem", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
}

void Store_Forward_PreviewForward(int client, char[] Type, int iData)
{
	Call_StartForward(gf_hPreviewItem);
	Call_PushCell(client);
	Call_PushString(Type);
	Call_PushCell(iData);
	Call_Finish();
}

void Store_Forward_OnConfigsExecuted()
{
	Call_StartForward(gf_hOnConfigExecuted);
	Call_PushString(g_sChatPrefix);
	Call_Finish();
}
