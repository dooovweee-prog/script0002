--[[


local URL = "https://raw.githubusercontent.com/dooovweee-prog/Anti-Skid-rblx-Script/main/Script.lua"

local ok, src = pcall(game.HttpGet, game, URL)
print("HTTP:", ok)

if not ok then
    warn(src)
    return
end

print("Length:", #src)

local func, err = loadstring(src)
print("Compiled:", func ~= nil)

if not func then
    warn(err)
    return
end

local ran, runtime = pcall(func)
print("Ran:", ran)

if not ran then
    warn(runtime)
end
-- load the antiskid script incase a skiddy user is here lmfao


]]
