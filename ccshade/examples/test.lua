local renderer = require"ccshade/renderer/renderer"
local deepcpy = require"ccshade/renderer/libs/deepcpy"

local png = require"png"

local texture = png("nootnoot.png")

--print(serialise(deepcpy{1,{2,3,{4}}}))
local r = renderer.new()
r:resetPalette()
--print(serialise(r,true))
local t = 0
local radius = 0.3
local px = 0
local py = 0
local T = os.clock()
local colAmount = 1000
local scale = 1
parallel.waitForAll(
function()
    while true do
        r:clear()
        local x,y = r.size.x,r.size.y
        local ratio = x/y
        for i=1,x do
            for j=1,y do
                local u = i/x
                local v = j/y
                --u=ratio*(u-1/2)
                --u,v = r.zoom(u,v,px,py,scale)

                local a = ratio*(1/2-u)+math.cos(T*2)*0.1
                local b = 1/2-v+math.sin(T*2)*0.1
                local c = math.min(math.sqrt(a*a+b*b),radius)/radius
                --c = math.floor(colAmount*math.abs(1-c))/colAmount
                local p1 = {c,c,c}
                local p2 = {u,v,1}
                r:setPixel(i,j,{rgb=r.colorspace.mix(p1,p2,1)})
                --local k = (2+(math.cos(5*u)+math.sin(20*v)))/4
                --r:setPixel(i,j,{rgb={k,k,k}})
                --local txc = {texture:get_pixel(math.floor(u*texture.width)+1,math.floor(v*texture.height)+1):unpack()}
                --r:setPixel(i,j,{rgb={txc[1],txc[2],txc[3]}})
                --r:setPixel(i,j,{rgb={u,v,0}})
            end
        end
        if t%2 == 0 then
            r:optimizeColors()
        end
        r:render()
        T = os.clock()
        term.setCursorPos(1,1)
        term.setTextColor(colors.white)
        t=t+1
        sleep()
        --term.write(os.clock()-T)
    end
end,
function ()
    while true do
        local event, key, is_held = os.pullEvent("key")
        if keys.getName(key) == "right" then
            px = px + 0.1/scale
        end
        if keys.getName(key) == "left" then
            px = px - 0.1/scale
        end
        if keys.getName(key) == "up" then
            py = py - 0.1/scale
        end
        if keys.getName(key) == "down" then
            py = py + 0.1/scale
        end
        if keys.getName(key) == "s" then
            scale = scale * 0.9
        end
        if keys.getName(key) == "z" then
            scale = scale * 1.1
        end
    end
end
)
