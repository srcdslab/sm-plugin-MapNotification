#include <sourcemod>
#include <discordWebhookAPI>

#pragma newdecls required

#define WEBHOOK_URL_MAX_SIZE	1000

ConVar g_cvWebhook, g_cvWebhookRetry;

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
	g_cvWebhookRetry = CreateConVar("sm_mapnotification_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);

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

	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if(!sWebhookURL[0])
	{
		LogError("[MapNotifications] No webhook found or specified.");
		return;
	}
	
	char sMessage[4096];
	Format(sMessage, sizeof(sMessage), ">>> %s\n%s\n%s\n%s", sMap, sPlayerCount, sQuickJoin, sTime);

	SendWebHook(sMessage, sWebhookURL);
}

stock void SendWebHook(char sMessage[4096], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
	Webhook webhook = new Webhook(sMessage);

	DataPack pack = new DataPack();
	pack.WriteString(sMessage);
	pack.WriteString(sWebhookURL);

	webhook.Execute(sWebhookURL, OnWebHookExecuted, pack);

	delete webhook;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	static int retries = 0;

	pack.Reset();

	char sMessage[4096];
	pack.ReadString(sMessage, sizeof(sMessage));

	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

	delete pack;

	if (response.Status != HTTPStatus_OK)
	{
		if (retries < g_cvWebhookRetry.IntValue)
		{
			PrintToServer("[MapNotifcations] Failed to send the webhook. Resending it .. (%d/%d)", retries, g_cvWebhookRetry.IntValue);

			SendWebHook(sMessage, sWebhookURL);
			retries++;
			return;
		}
		else
		{
			LogError("[MapNotifcations] Failed to send the webhook after %d retries, aborting.", retries);
		}
	}

	retries = 0;
}
