#include <sourcemod>
#include <sourcecolors>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Show Online Vips",
    author = "Ilusion9",
    description = "Show online vips by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

enum struct GroupInfo
{
	char groupPhrase[128];
	AdminFlag uniqueFlag;
}

GroupInfo g_Groups[32];
int g_GroupsArrayLength;
int g_GroupIndex[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("groups_online.phrases");
	LoadTranslations("groups_name.phrases");
	
	RegConsoleCmd("sm_vips", Command_Vips, "Show online vips by groups");
}

public void OnConfigsExecuted()
{
	g_GroupsArrayLength = 0;
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/groups_online.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	if (!kv.JumpToKey("VIP Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"VIP Groups\" section could not be found).");
		return;
	}
	
	char buffer[65];
	GroupInfo group;	
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.groupPhrase, sizeof(GroupInfo::groupPhrase));
			kv.GetString("flag", buffer, sizeof(buffer));
			
			if (!FindFlagByChar(buffer[0], group.uniqueFlag))
			{
				LogError("Invalid flag specified for group: %s", group.groupPhrase);
				continue;
			}
			
			g_Groups[g_GroupsArrayLength] = group;
			g_GroupsArrayLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	OnConfigsExecuted();
}

public void OnClientPostAdminCheck(int client)
{
	g_GroupIndex[client] = -1;
	
	if (IsFakeClient(client))
	{
		return;
	}
	
	AdminId admin_id = GetUserAdmin(client);
	if (admin_id == INVALID_ADMIN_ID)
	{
		return;
	}
	
	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (GetAdminFlag(admin_id, g_Groups[groupIndex].uniqueFlag, Access_Effective))
		{
			g_GroupIndex[client] = groupIndex;
			break;
		}
	}
}

public Action Command_Vips(int client, int args)
{
	if (!g_GroupsArrayLength)
	{
		return Plugin_Handled;
	}
	
	bool membersOnline = false;
	int groupIndex, memberIndex;
	int groupCount[sizeof(g_Groups)];
	int groupMembers[sizeof(g_Groups)][MAXPLAYERS + 1];
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (!IsClientInGame(player) || IsFakeClient(player))
		{
			continue;
		}
		
		groupIndex = g_GroupIndex[player];
		if (groupIndex < 0)
		{
			continue;
		}
		
		groupMembers[groupIndex][groupCount[groupIndex]] = player;
		groupCount[groupIndex]++;
		membersOnline = true;
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Vips Online");
		return Plugin_Handled;
	}
	
	int groupLength, bufferLength, nameLength;
	char clientName[32], groupName[32], buffer[256];
	
	for (groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (!groupCount[groupIndex])
		{
			continue;
		}
		
		nameLength = groupLength = bufferLength = 0;
		strcopy(buffer, sizeof(buffer), "");
		
		groupLength = Format(groupName, sizeof(groupName), "%T", g_Groups[groupIndex].groupPhrase, client);
		for (memberIndex = 0; memberIndex < groupCount[groupIndex]; memberIndex++)
		{
			nameLength = Format(clientName, sizeof(clientName), "%N", groupMembers[groupIndex][memberIndex]);
			if (groupLength + bufferLength + nameLength > 190)
			{
				CReplyToCommand(client, "%s %s", groupName, buffer);
				strcopy(buffer, sizeof(buffer), clientName);
				bufferLength = nameLength;
				continue;
			}
			
			if (buffer[0] == '\0')
			{
				strcopy(buffer, sizeof(buffer), clientName);
				bufferLength = nameLength;
			}
			else
			{
				bufferLength = Format(buffer, sizeof(buffer), "%s, %s", buffer, clientName);
			}
		}
		
		CReplyToCommand(client, "%s %s", groupName, buffer);
	}
	
	return Plugin_Handled;
}
