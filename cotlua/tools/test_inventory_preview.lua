-- Real pure model: no Warcraft handles, frames, timers or inventory services.
local env = setmetatable({}, {__index = _G})
local _ENV = env
OnInit = {global = function(_, init) init() end}
CreateTimer, CreateItem, GetLocalPlayer = function() error('Preview allocated a timer') end,
    function() error('Preview allocated an item') end, function() error('Model read client state') end
assert(loadfile('cotlua/src/ui/inventory/preview.lua', 't', env))()
local M = InventoryPreview
local function item(id, charges) return {alive = true, sync_id = id, charges = charges or 1} end
local a, b, c = item(10), item(20), item(30)
local state, items, stash = M.create(), {[1] = a, [9] = b}, {[1] = c}
local function view() return M.project(state, items, stash, 26, 36) end
local op1 = assert(M.push(state, view(), 1, 9))
local projected = view()
assert(projected[1].item == b and projected[9].item == a)
assert(items[1] == a and items[9] == b and a.charges == 1)
-- Continue dragging predicted items before any sync acknowledgement.
local op2 = assert(M.push(state, projected, 9, 10))
local op3 = assert(M.push(state, view(), 27, 1))
projected = view()
assert(projected[10].item == a and projected[1].item == c and projected[27].item == b)
assert(items[1] == a and stash[1] == c, 'Preview mutated authoritative arrays')
-- Acknowledge before the real commit: notifications during commit must not
-- replay the just-applied operation a second time.
assert(M.ack(state, op1.serial)); items[1], items[9] = b, a
projected = view()
assert(projected[10].item == a and projected[1].item == c and projected[27].item == b)
assert(M.ack(state, op2.serial)); items[9], items[10] = nil, a
assert(M.ack(state, op3.serial)); items[1], stash[1] = c, b
assert(not M.pending(state) and view()[10].item == a)
-- Rejection invalidates dependent projections, while independent queued moves
-- still render; no queued request is allowed to move a replacement target.
state, items, stash = M.create(), {[1] = a, [9] = b}, {[1] = c}
op1 = assert(M.push(state, view(), 1, 9))
op2 = assert(M.push(state, view(), 9, 10))
assert(M.push(state, view(), 27, 11))
M.ack(state, op1.serial) -- Rejected; authoritative arrays did not change.
projected = view()
assert(projected[1].item == a and projected[9].item == b and projected[10] == nil)
assert(projected[11].item == c and projected[27] == nil)
local replacement = item(21)
items[9] = replacement
assert(view()[9].item == replacement, 'Stale prediction moved the wrong target')
-- Partial/complete stack previews change view counts, never Item charges.
state, items, stash = M.create(), {[9] = item(40, 8), [10] = item(50, 6)}, {}
op1 = assert(M.push(state, view(), 9, 10, 10))
projected = view()
assert(projected[9].charges == 4 and projected[10].charges == 10)
assert(items[9].charges == 8 and items[10].charges == 6)
op2 = assert(M.push(state, projected, 9, 11))
M.ack(state, op1.serial); items[9].charges, items[10].charges = 4, 10
assert(view()[11].charges == 4 and view()[9] == nil, 'Stack was predicted twice after commit')
M.ack(state, op2.serial); items[11], items[9] = items[9], nil
assert(view()[11].charges == 4)
state, items = M.create(), {[9] = item(60, 3), [10] = item(70, 6)}
assert(M.push(state, view(), 9, 10, 10))
assert(view()[9] == nil and view()[10].charges == 9 and items[9].charges == 3)
-- Bounded queue and monotonic request IDs survive clear/close/cleanup.
state, items = M.create(), {[9] = a}
for i = 1, 16 do
    assert(M.push(state, view(), i % 2 == 1 and 9 or 10, i % 2 == 1 and 10 or 9))
end
assert(not M.push(state, view(), 9, 10))
local serial = state.serial
M.clear(state)
assert(not M.pending(state) and M.next(state) == serial + 1)
a.alive = false; assert(view()[9] == nil); a.alive = true
print('PASS: immediate swaps, chained drags, stash projection, rejection/rebase, replacement identities, stack counts, bounded queue, no authoritative writes or native allocations.')
