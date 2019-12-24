#include <sourcemod>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Display groups",
    author = "Ilusion9",
    description = "Display admins and vips by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

#define MAX_GROUPS		65
enum struct GroupInfo
{
	char name[32];
	int flag;
}

GroupInfo g_Groups[MAX_GROUPS];
int g_GroupsLength;
int g_VipGroupIndex;

public void OnPluginStart()
{
	RegConsoleCmd("sm_groups", Command_Groups);
}

public void OnConfigsExecuted()
{
	g_GroupsLength = 0;
	g_VipGroupIndex = 0;
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/displaygroups.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (!kv.JumpToKey("Admin Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"Admin Groups\" section could not be found).");
		return;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			char value[2];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			if (!FindFlagByChar(value[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			g_Groups[g_GroupsLength] = group;
			g_GroupsLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	g_VipGroupIndex = g_GroupsLength;
	kv.Rewind();
	
	if (!kv.JumpToKey("VIP Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"VIP Groups\" section could not be found).");
		return;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			char value[2];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			if (!FindFlagByChar(value[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			g_Groups[g_GroupsLength] = group;
			g_GroupsLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public Action Command_Groups(int client, int args)
{
	int members[MAX_GROUPS][MAXPLAYERS + 1];
	int length[MAX_GROUPS];
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientInGame(player))
		{
			bool assigned = false;
			for (int groupIndex = 0; groupIndex < g_GroupsLength; groupIndex++)
			{
				if (groupIndex == g_VipGroupIndex)
				{
					assigned = false;
				}
				
				if (!assigned)
				{
					if (CheckCommandAccess(player, "", g_Groups[groupIndex].flag, true))
					{
						assigned = true;
						members[groupIndex][length[groupIndex]] = player;
						length[groupIndex]++;
					}
				}
			}
		}
	}
	
	for (int groupIndex = 0; groupIndex < g_GroupsLength; groupIndex++)
	{
		if (length[groupIndex])
		{
			int msgLength;
			char name[32], buffer[256];
			
			Format(buffer, sizeof(buffer), "%s:", g_Groups[groupIndex].name);
			msgLength = strlen(buffer);
			
			for (int i = 0; i < length[groupIndex]; i++)
			{
				GetClientName(members[groupIndex][i], name, sizeof(name));
				msgLength += strlen(name) + 2;
				
				if (msgLength > 192)
				{
					ReplyToCommand(client, "[SM] %s", buffer);
					Format(buffer, sizeof(buffer), "%s:", g_Groups[groupIndex].name);
					msgLength += strlen(buffer);
				}
				
				Format(buffer, sizeof(buffer), "%s %s%s", buffer, name, (i < length[groupIndex] - 1) ? "," : "");
			}
			
			ReplyToCommand(client, "[SM] %s", buffer);
		}
	}
	
	return Plugin_Handled;
}
