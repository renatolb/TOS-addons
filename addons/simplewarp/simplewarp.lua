local selected_warp = -1;
local last_field_warp = -1;
local userWarps = {};

function SIMPLEWARP_ON_INIT(addon, frame) 
	_HOOK(TRY_TO_USE_WARP_ITEM_HOOKED, "TRY_TO_USE_WARP_ITEM");
	_HOOK(INTE_WARP_OPEN_FOR_QUICK_SLOT_HOOKED, "INTE_WARP_OPEN_FOR_QUICK_SLOT");
	_HOOK(SIMPLEWARP_OPEN, "INTE_WARP_OPEN_BY_NPC");
	_HOOK(SIMPLEWARP_OPEN, "INTE_WARP_OPEN_NORMAL");
	_HOOK(SIMPLEWARP_GO, "WARP_TO_AREA");
end

function SIMPLEWARP_OPEN(useitem)
	local frame = ui.GetFrame("simplewarp");
	local currentZoneName = GetZoneName(GetMyPCObject());
	local currentZoneClass = GetClass("Map", currentZoneName);

	SIMPLEWARP_LOADWARPS(frame);
	
	if useitem ~= nil and type(useitem) == 'string' then
		frame:SetUserValue('SCROLL_WARP', useitem);
	end
	
	local warplist = GET_CHILD(frame, "warplist", "ui::CDropList");
	if currentZoneClass.MapType == 'City' then
		if last_field_warp == -1 then
			local first = next(userWarps);
			selected_warp = first;
		else
			selected_warp = last_field_warp;
		end
		warplist:SelectItemByKey(selected_warp);
	else 
		local cities = filter_table(filter_warp_by_city, userWarps);
		table.sort(cities, sort_warps_by_cost);
		local best_city = '';
		for k, v in ipairs(cities) do
			best_city = v["name"];
			break;
		end

		last_field_warp = get_warp_index_by_name(WARP_INFO_ZONE(currentZoneName).Name);
		selected_warp = get_warp_index_by_name(best_city);
		warplist:SelectItemByKey(selected_warp);
	end
	SetKeyboardSelectMode(1);
	frame:ShowWindow(1);
	frame:Invalidate();
end

function SIMPLEWARP_CLOSE(frame)
	frame:SetUserValue('SCROLL_WARP', 'NO');
	UNREGISTERR_LASTUIOPEN_POS(frame);
	SetKeyboardSelectMode(0);
end

function SIMPLEWARP_LOADWARPS(frame)
	local warplist = GET_CHILD(frame, "warplist", "ui::CDropList");
	local currentZoneName = GetZoneName(GetMyPCObject());
	
	userWarps = SIMPLEWARPS_GET_WARPS();

	warplist:ClearItems();
	for i = 1, #userWarps do
		local name = userWarps[i]["name"];
		local level = userWarps[i]["lvl"];
		local zone = userWarps[i]["info"].Zone;
		local cost = userWarps[i]["cost"];

		if currentZoneName ~= zone then
			name = string.format("%s - Cost: %s", name, cost);
		end
		if level > 0 then
			name = string.format("%s - %s", level, name);
		end
		warplist:AddItem(i, name);
	end
end

function SIMPLEWARPS_GET_WARPS()
	local currentZoneName = GetZoneName(GetMyPCObject());
	local my_warp_info = GET_INTE_WARP_LIST();
	local my_warps = {};

	for i = 1, #my_warp_info do
		local info = my_warp_info[i];
		local mapCls = GetClass("Map", info.Zone);
		
		my_warps[i] = {};
		my_warps[i]["name"] = GET_WARP_NAME_TEXT(mapCls, info, currentZoneName);
		my_warps[i]["info"] = info;
		my_warps[i]["ClassName"] = info.ClassName;
		my_warps[i]["lvl"] = mapCls.QuestLevel;
		my_warps[i]["type"] = 0;
		my_warps[i]["cost"] = geMapTable.CalcWarpCostBind(currentZoneName, info.Zone);
	end
	
	local previous_map = SIMPLEWARPS_GET_LAST_SCROLL_WARP();
	if previous_map ~= nil then	my_warps[#my_warp_info + 1] = previous_map end

	table.sort(my_warps, sort_warps);
	return my_warps;
end

function SIMPLEWARPS_GET_LAST_SCROLL_WARP()
	local etc = GetMyEtcObject();
	local mapCls = GetClassByType("Map", etc.ItemWarpMapID);

	if mapCls ~= nil and mapCls.WorldMap ~= "None" then
		local currentZoneName = GetZoneName(GetMyPCObject());
		local info = WARP_INFO_ZONE(mapCls.ClassName);
		local my_warp = {};
		my_warp["name"] = "{#ffff00}"..info.Name.." - Previous Warp";
		my_warp["info"] = info;
		if info ~= nil then
			my_warp["ClassName"] = info.ClassName;
		else
			my_warp["ClassName"] = mapCls.ClassName;
		end
		my_warp["lvl"] = mapCls.QuestLevel;
		my_warp["type"] = 1;
		my_warp["cost"] = 0;
		return my_warp;
	end
	return nil;
end

function WARP_POINT_CHANGE(frame, ctrl)
	local warplist = tolua.cast(ctrl, "ui::CDropList");
	selected_warp = tonumber(warplist:GetSelItemKey());
end

function SIMPLEWARP_GO(frame)
	local warpFrame = ui.GetFrame('simplewarp');
	local warpCls = GetClass('camp_warp', userWarps[selected_warp]["ClassName"]); 
	local nowZoneName = GetZoneName(GetMyPCObject());
	local myMoney = GET_TOTAL_MONEY();

	local targetMapName;
    local mapClassId;
	if warpCls ~= nil then
		targetMapName = warpCls.Zone;
		mapClassId = warpCls.ClassID;
    elseif selected_warp ~= -1 then
		targetMapName = userWarps[selected_warp]["ClassName"];
	    mapClassId = GetClass('Map', targetMapName).ClassID;
    end
    warpcost = geMapTable.CalcWarpCostBind(nowZoneName, targetMapName);

	if targetMapName == nowZoneName then
		ui.SysMsg(ScpArgMsg("ThatCurrentPosition"));
		return;
	end	

	if warpcost < 0 then
		warpcost = 0;
	end

	local warpitemname = warpFrame:GetUserValue('SCROLL_WARP');

	if (warpitemname == 'NO' or warpitemname == 'None') and myMoney < warpcost then
		ui.SysMsg(ScpArgMsg('Auto_SilBeoKa_BuJogHapNiDa.'));
		return;
	end
    
	local cheat = string.format("/intewarp %d %d", mapClassId, userWarps[selected_warp]["type"]);
	if warpitemname ~= 'NO' and warpitemname ~= 'None' then
		cheat = string.format("/intewarpByItem %d %d %s", mapClassId, userWarps[selected_warp]["type"], warpitemname);
	end
    
	movie.InteWarp(session.GetMyHandle(), cheat);
	packet.ClientDirect("InteWarp");
    if warpFrame:IsVisible() == 1 then
		ui.CloseFrame('simplewarp');
	end
end

function INTE_WARP_OPEN_FOR_QUICK_SLOT_HOOKED()
   	local frame = ui.GetFrame('simplewarp');
	frame:SetUserValue('SCROLL_WARP', 'YES');
	SIMPLEWARP_OPEN();
end

function TRY_TO_USE_WARP_ITEM_HOOKED(invitem, itemobj)
	if itemobj.ClassName == 'Scroll_WarpKlaipe' or itemobj.ClassName == 'Scroll_Warp_quest' or itemobj.ClassName == 'Premium_WarpScroll'  then
		if invitem.isLockState then
			ui.SysMsg(ClMsg("MaterialItemIsLock"));
			return 1;
		end
		local frame = ui.GetFrame('simplewarp');
		frame:SetUserValue('SCROLL_WARP', itemobj.ClassName);
		SIMPLEWARP_OPEN();
		return 1;
	end
	return 0;
end

function get_warp_index_by_name(name)
	for k,v in pairs(userWarps) do
		if v["name"] == name then return k end
	end
	return -1;
end

function sort_warps(x, y)
	if x["lvl"] == 0 and y["lvl"] > 0 then return true end
	if y["lvl"] == 0 and x["lvl"] > 0 then return false end
	if x["lvl"] == y["lvl"] then return x["name"] < y["name"] end
	return x["lvl"] > y["lvl"];
end

function sort_warps_by_cost(x, y)
	return x["cost"] < y["cost"];
end

function filter_warp_by_city(warp)
	local mapCls = GetClass("Map", warp["info"].Zone);
	return mapCls.MapType == 'City';
end

function filter_table(fn, table)
	local filtered_table= {};
	local index = 1;
	for key,value in pairs(table) do
		if fn(value) then
			filtered_table[index] = value;
			index = index + 1;
		end
	end
	return filtered_table
end

function _HOOK(fn, oldFnStr)
	_G[oldFnStr .. "_OLD"] = _G[oldFnStr];
	_G[oldFnStr] = fn;
end
