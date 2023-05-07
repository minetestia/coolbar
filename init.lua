local ms = minetest.settings
local function log(...)
  for _, any in ipairs { ... } do
    minetest.log(dump(any))
  end
end

-- Name of the main player's inventory list.
local inv_name = tostring(ms:get "coolbar.inv_name" or "main")
-- Visible panel size (excluding inventory and hidden slots).
local panel_size = tonumber(ms:get "coolbar.panel_size" or 8)
-- Visible inventory size (excluding panel and hidden slots).
local inv_size = tonumber(ms:get "coolbar.inv_size" or 24)
-- Index of the first slot on a panel.
local panel_start = tonumber(ms:get "coolbar.panel_start" or 1)
-- Index of the first inventory slot.
local inv_start = tonumber(ms:get "coolbar.inv_start" or 9)
-- The last slot on panel
local panel_end = panel_start + panel_size - 1
-- The last inventory slot
local inv_end = inv_start + inv_size - 1
-- Default builtin array of itemstrings preferred to keep on the panel.
local builtin_panel_slots = {
  "group:sword",
  "group:axe",
  "group:pickaxe",
  "group:shovel",
  "default:water_bucket",
  "group:dirt",
  "default:apple",
  "group:torch",
}
-- Array of itemstrings preferred to keep on the panel.
---@type mt.ItemString[]
local preferred_panel_slots = {}
for i = 1, panel_size do
  local slot =
    tostring(ms:get("coolbar.slot_" .. i) or builtin_panel_slots[i] or "")
  preferred_panel_slots[i] = slot
end

-- All players inventory lists, indexed by player name.
---@type table<string, mt.ItemStack[]>
local inv_lists = {}

-- Check if item corresponds to itemstring, including groups.
---@param item mt.ItemStack
---@param is mt.ItemString
---@return boolean
local function item_is(item, is)
  if is:find "^group:" then
    local group = is:sub(7)
    if item:get_definition().groups[group] then return true end
    return false
  end
  if item:get_name() == is then return true end
  return false
end

local function put_item_in_empty_slot(player_name, item_index)
  local preferred_item_name = preferred_panel_slots[item_index]
  local player = minetest.get_player_by_name(player_name)
  local inv = player:get_inventory()
  if not inv then return end
  local inv_list = inv:get_list(inv_name)
  for i = inv_start, inv_end do
    if item_is(inv_list[i], preferred_item_name) then
      inv:set_stack(inv_name, item_index, inv_list[i])
      inv:set_stack(inv_name, i, ItemStack "")
      return
    end
  end
end

local function on_player_inv_change(player_name, item, item_index)
  local item_name = item:get_name()
  if
    item_name == ""
    and item_index >= panel_start
    and item_index <= panel_end
    and preferred_panel_slots[item_index - panel_start + 1] ~= ""
  then
    put_item_in_empty_slot(player_name, item_index)
    return
  end
end

---@param player_name string
local function detect_player_inv_changes(player_name)
  local inv = minetest.get_inventory { type = "player", name = player_name }
  local old_list = inv_lists[player_name]
  local new_list = inv:get_list(inv_name)

  for i, new_item in ipairs(new_list) do
    local old_item = old_list[i]
    if new_item ~= old_item then
      inv_lists[player_name][i] = new_item
      on_player_inv_change(player_name, new_item, i)
    end
  end
end

---------------------
-- REGISTER EVENTS --
---------------------

minetest.register_on_player_inventory_action(
  function(player, action, inventory, inventory_info)
    detect_player_inv_changes(player:get_player_name())
  end
)

minetest.register_on_dignode(
  function(pos, oldnode, player)
    detect_player_inv_changes(player:get_player_name())
  end
)

minetest.register_on_item_pickup(
  function(itemstack, player, pointed_thing, time_from_last_punch)
    minetest.after(0.1, detect_player_inv_changes, player:get_player_name())
  end
)

minetest.register_on_joinplayer(
  function(player)
    inv_lists[player:get_player_name()] =
      player:get_inventory():get_list(inv_name)
  end
)
