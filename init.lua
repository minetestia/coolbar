local settings = minetest.settings

-- Visible bar size (excluding inventory and hidden slots).
local bar_size = tonumber(settings:get "coolbar.bar_size" or 8) --[[@as integer]]
-- The number of visible inventory rows (excluding bar and hidden slots).
local inv_rows = tonumber(settings:get "coolbar.inv_rows" or 3) --[[@as integer]]
-- Visible inventory size (excluding bar and hidden slots).
local inv_size = bar_size * inv_rows
-- Index of the first slot on a bar.
local bar_start = tonumber(settings:get "coolbar.bar_start" or 1) --[[@as integer]]
-- Index of the first inventory slot.
local inv_start = tonumber(settings:get "coolbar.inv_start" or 9) --[[@as integer]]
-- The last slot on bar
local bar_end = bar_start + bar_size - 1
-- The last inventory slot
local inv_end = inv_start + inv_size - 1
-- Default builtin array of itemstrings preferred to keep on the bar.
local default_bar_slots = {
  "group:sword",
  "group:shovel",
  "group:pickaxe",
  "group:axe",
  "default:water_bucket",
  "group:soil",
  "group:food|group:food_apple|group:food_mushroom",
  "group:torch",
}
-- Items preferred to keep on the bar.
---@type string[][]
local preferred_bar_slots = {}
for i = 1, bar_size do
  local slot =
    tostring(settings:get("coolbar.slot_" .. i) or default_bar_slots[i] or "")
  preferred_bar_slots[i] = slot:split "|"
end

-- Check if item corresponds to itemstring, including "group:something" format.
---@param item mt.ItemStack
---@param is string|string[]
---@return boolean
local function item_is(item, is)
  if type(is) == "table" then
    for _, value in ipairs(is) do
      if item_is(item, value) then return true end
    end
    return false
  end
  if is:find "^group:" then
    local group = is:sub(7)
    if item:get_definition().groups[group] then return true end
    return false
  end
  if item:get_name() == is then return true end
  return false
end

---@param player mt.PlayerObjectRef
---@param old_item mt.ItemStack
---@param new_item mt.ItemStack
---@param index integer
local function handle_item_increase(player, old_item, new_item, index)
  ---@return boolean is_it, integer|nil should_be
  local function is_new_item_position_correct()
    if old_item:get_name() == new_item:get_name() then return true, index end
    local should_be
    for i, preferred in ipairs(preferred_bar_slots) do
      if item_is(new_item, preferred) then
        should_be = i
        break
      end
    end
    if should_be == index then return true, should_be end
    if index >= inv_start and index <= inv_end then
      if should_be then return false, should_be end
      return true, should_be
    end
    return false, should_be
  end

  local is_it, should_be = is_new_item_position_correct()
  -- log(("[%s] : [%s == %s]"):format(is_it, item_index, should_be))
  if is_it then return end

  local inv = player:get_inventory()
  local list = inv:get_list "main"
  if should_be and list[should_be]:get_free_space() == 0 then
    should_be = nil
  end
  local new_item_name = new_item:get_name()
  local slot_empty, slot_same ---@type integer, integer|nil
  for i = inv_start, inv_end do
    local name = list[i]:get_name()
    if not slot_empty and name == "" then
      slot_empty = i
    elseif
      not slot_same
      and name == new_item_name
      and list[i]:get_free_space() > 0
    then
      slot_same = i
    end
    if slot_same and slot_empty then break end
  end
  if not slot_empty then return end
  -- log(("empty: [%s], same: [%s]"):format(slot_empty, slot_same))

  local stack_from = list[index]
  local stack_to = list[should_be or slot_same or slot_empty]

  local taken = stack_from:take_item(stack_from:get_count())
  local leftover = stack_to:add_item(taken)
  list[slot_empty]:add_item(leftover)

  inv:set_list("main", list)
  minetestia.player_inventory_main_lists[player:get_player_name()] = list
end

---@param player mt.PlayerObjectRef
---@param old_item mt.ItemStack
---@param new_item mt.ItemStack
---@param item_index integer
local function handle_bar_decrease(player, old_item, new_item, item_index)
  local inv = player:get_inventory()
  local list = inv:get_list "main"
  ---@type string|string[]
  local target_item = new_item:get_name()

  if target_item == "" then
    local bar_index = item_index - bar_start + 1
    local preferred = preferred_bar_slots[bar_index]
    if not item_is(old_item, preferred) then
      target_item = old_item:get_name()
    else
      target_item = preferred
    end
  end

  for i = inv_start, inv_end do
    local inv_stack = list[i]
    if item_is(inv_stack, target_item) then
      local bar_stack = list[item_index]
      local leftover = bar_stack:add_item(inv_stack)
      list[i] = leftover
      if bar_stack:get_count() == bar_stack:get_stack_max() then break end
      if not leftover or leftover:get_name() ~= "" then break end
    end
  end
  inv:set_list("main", list)
  minetestia.player_inventory_main_lists[player:get_player_name()] = list
end

---@type mf.on_player_inventory_change
local function on_player_inv_change(player, old_item, new_item, i, action, info)
  if info and info.from_list == "main" then return end
  if new_item:get_count() >= old_item:get_count() then
    handle_item_increase(player, old_item, new_item, i)
    return
  end
  if i >= bar_start and i <= bar_end then
    handle_bar_decrease(player, old_item, new_item, i)
  end
end

minetestia.register_on_player_inventory_change(on_player_inv_change)

minetest.register_on_mods_loaded(minetestia.auto_detect_inventory_changes)

--[[ Debug
log(
  (
    "bar_size: %s, inv_rows: %s, inv_size: %s, "
    .. "bar_start: %s, bar_end: %s, "
    .. "inv_start: %s, inv_end: %s"
  ):format(
    bar_size,
    inv_rows,
    inv_size,
    bar_start,
    bar_end,
    inv_start,
    inv_end
  )
)
]]
