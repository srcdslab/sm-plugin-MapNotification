#include <sourcemod>
#include <Discord>

#pragma newdecls required

public Plugin myinfo = 
{
    name = "MapNotification",
    author = "maxime1907",
    description = "Sends a server info message to discord on map start",
    version = "1.0.0",
    url = ""
};

public void OnMapStart()
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

    char sWebhook[64];
    Format(sWebhook, sizeof(sWebhook), "mapnotification");

    char sMessage[4096];
    Format(sMessage, sizeof(sMessage), ">>> %s\n%s\n%s\n%s", sMap, sPlayerCount, sQuickJoin, sTime);

    Discord_SendMessage(sWebhook, sMessage);
}
