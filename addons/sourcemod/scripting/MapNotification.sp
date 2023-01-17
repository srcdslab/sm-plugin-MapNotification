#include <sourcemod>
#include <discordWebhookAPI>

#pragma newdecls required

ConVar g_cvWebhook;

public Plugin myinfo = 
{
	name = "MapNotification",
	author = "maxime1907",
	description = "Sends a server info message to discord on map start",
	version = "1.1.3",
	url = ""
};

public void OnPluginStart()
{
	g_cvWebhook = CreateConVar("sm_mapnotification_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);

	AutoExecConfig(true);
}

public void OnConfigsExecuted()
{
	char sTimeFormatted[64];
	char sTime[128];
	int iTime = GetTime();
	FormatTime(sTimeFormatted, sizeof(sTimeFormatted), "%m/%d/%Y @ %H:%M:%S", iTime);
	Format(sTime, sizeof(sTime), "Date: **%s**", sTimeFormatted);

	char sMapName[PLATFORM_MAX_PATH];
	char sMap[PLATFORM_MAX_PATH+64];
	GetCurrentMap(sMapName, sizeof(sMapName));
	Format(sMap, sizeof(sMap), "Map: **%s**", sMapName);

	char sPlayerCount[64];
	int iClients = GetClientCount(false);
	Format(sPlayerCount, sizeof(sPlayerCount), "Players: **%d/%d**", iClients, MaxClients);

	char sQuickJoin[255];
	char sIP[32] = "";
	char sPort[310] = "";
	ConVar cIP = FindConVar("net_public_adr");
	ConVar cHostPort = FindConVar("hostport");

	if (cIP != null && cHostPort != null)
	{
		cIP.GetString(sIP, sizeof(sIP));
		cHostPort.GetString(sPort, sizeof(sPort));
	}
	
	Format(sQuickJoin, sizeof(sQuickJoin), "Quick join: **steam://connect/%s:%s**", sIP, sPort);

	char szWebhookURL[1000];
	g_cvWebhook.GetString(szWebhookURL, sizeof szWebhookURL);
	if(!szWebhookURL[0])
	{
		LogError("[MapNotifications] No webhook found or specified.");
		return;
	}
	
	char sMessage[4096];
	Format(sMessage, sizeof(sMessage), ">>> %s\n%s\n%s\n%s", sMap, sPlayerCount, sQuickJoin, sTime);

	Webhook webhook = new Webhook(sMessage);
	
	DataPack pack = new DataPack();
	pack.WriteCell(view_as<int>(webhook));
	pack.WriteString(szWebhookURL);
	
	webhook.Execute(szWebhookURL, OnWebHookExecuted, pack);
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	static int retries;
	
	pack.Reset();
	Webhook hook = view_as<Webhook>(pack.ReadCell());
	
	if (response.Status != HTTPStatus_OK)
	{
		if(retries < 3)
			PrintToServer("[MapNotifcations] Failed to send the webhook. Resending it .. (%d/3)", retries);
			
		if(retries >= 3)
		{
			PrintToServer("[MapNotifcations] Failed to send the webhook. Aborting after %d retries.", retries);
			LogError("[MapNotifcations] Failed to send the webhook after %d retries.", retries);
			delete pack;
			delete hook;
			return;
		}
		
		char webhookURL[PLATFORM_MAX_PATH];
		pack.ReadString(webhookURL, sizeof(webhookURL));
		
		DataPack newPack;
		CreateDataTimer(0.5, ExecuteWebhook_Timer, newPack);
		newPack.WriteCell(view_as<int>(hook));
		newPack.WriteString(webhookURL);
		delete pack;
		retries++;
		return;
	}
	
	delete pack;
	delete hook;
	retries = 0;
}

Action ExecuteWebhook_Timer(Handle timer, DataPack pack)
{
	pack.Reset();
	Webhook hook = view_as<Webhook>(pack.ReadCell());
	
	char webhookURL[PLATFORM_MAX_PATH];
	pack.ReadString(webhookURL, sizeof(webhookURL));
	
	DataPack newPack = new DataPack();
	newPack.WriteCell(view_as<int>(hook));
	newPack.WriteString(webhookURL);	
	hook.Execute(webhookURL, OnWebHookExecuted, newPack);
	return Plugin_Continue;
}
