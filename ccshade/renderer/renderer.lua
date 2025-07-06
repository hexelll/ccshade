local deepcpy = require"libs/deepcpy"
local box = require "libs/pixelbox_lite"
local Mat = require"libs/Mat"
local utils = require"libs/utils"

local _colors = {
        colors.white,
        colors.orange,
        colors.magenta,
        colors.lightBlue,
        colors.yellow,
        colors.lime,
        colors.pink,
        colors.gray,
        colors.lightGray,
        colors.cyan,
        colors.purple,
        colors.blue,
        colors.brown,
        colors.green,
        colors.red,
        colors.black,
    }

local renderer = {
    pixelbuffer={},-- [x:int][y:int] => {rgb={float,float,float},z:float,depth:float}
    bg={0,0,0}, -- {r,g,b}
    size={x=2*({term.getSize()})[1],y=3*({term.getSize()})[2]},
    colorspace={},
    b=box.new(term.current())
}

function renderer.new(size)
    local o = deepcpy(renderer)
    o.size = size or o.size
    o:updateBuffer()
    return o
end

function renderer:updateBuffer()
    self.size.x = self.b.width
    self.size.y = self.b.height
    for i = 1,self.size.x do
        self.pixelbuffer[i] = {}
        for j = 1,self.size.y do
            local bg = self.bg
            self.pixelbuffer[i][j] = {
                rgb={bg[1],bg[2],bg[3]},
                z=math.huge,
                depth=math.huge
            }
        end
    end
    return self
end

function renderer.zoom(u,v,px,py,scale,_repeatx,_repeaty)
    px = px or 0
    py = py or 0
    scale = scale or 1
    u,v = (u+(px)*scale)/scale,(v-1/2+(py)*scale)/scale
    if _repeatx then
        u = math.fmod(u,1)
        u = u<0 and 1+u or u
    else
        u = u>=1 and -1 or u<0 and -1 or u
    end
    if _repeaty then
        v = math.fmod(v,1)
        v = v<0 and 1+v or v
    else
        v = v>=1 and -1 or v<0 and -1 or v
    end
    return u,v
end

function renderer:clear()
    self.b:clear(self.colorspace.toTermCol(self.bg))
    for i = 1,self.size.x do
        for j = 1,self.size.y do
            self.pixelbuffer[i][j] = {
                rgb=deepcpy(self.bg),
                z=math.huge,
                depth=math.huge,
                normal={x=0,y=0,z=0}
            }
        end
    end
end

function renderer:xinbound(x)
    return x>0 and x<=self.size.x
end

function renderer:yinbound(y)
    return y>0 and y<=self.size.y
end

function renderer:setPixel(x,y,pixel)
    local rgb = pixel.rgb
    local z = pixel.z or 0
    if self:xinbound(x) and self:yinbound(y) then
        self.pixelbuffer[x][y] = {
            rgb={rgb[1],rgb[2],rgb[3]},
            z=z,
            depth=x*x+y*y+z*z,
            normal=deepcpy(pixel.normal) or {x=0,y=0,z=0}
        }
    end
end

function renderer:getUniqueColors()
    local rgbArr = {}
    for i=1,self.size.x do
        for j=1,self.size.y do
            local c = self:getPixel(i,j).rgb
            local contains = false
            for k=1,#rgbArr do
                local equal = true
                for l=1,3 do
                    if rgbArr[k][l] ~= c[l] then
                        equal = false
                        break
                    end
                end
                if equal then
                    contains = true
                    break
                end
            end
            if not contains then
                rgbArr[#rgbArr+1] = c
            end
        end
    end
    return rgbArr
end

function renderer:getPixel(x,y)
    if self:xinbound(x) and self:yinbound(y) then
        return self.pixelbuffer[x][y]
    end
    return false
end

function renderer:getLineBuffer(p1,p2,fn)
    local dx = p2.x-p1.x
    local dy = p2.y-p1.y
    local dz = p2.z-p1.z
    local pixels = {}
    if dx==0 and dy==0 then
        if not (self:xinbound(p1.x) and self:yinbound(p1.y)) then
            return pixels
        end
        pixels[#pixels+1]={
            rgb=fn(p1.x,p1.y,p1.z),
            z=p1.z,
            depth=p1.x*p1.x+p1.y*p1.y+p1.z*p1.z
        }
    elseif dy == 0 then
        local s = dx>0 and 1 or -1
        for x=p1.x,p2.x,s do
            if not (self:xinbound(x) and self:yinbound(p1.y)) then
                return pixels
            end
            local z = p1.z+dz*(x-p1.x)/dx
            pixels[#pixels+1]={
                rgb=fn(p1.x,p1.y,p1.z),
                z=z,
                depth=p1.x*p1.x+p1.y*p1.y+p1.z*p1.z
            }
        end
    elseif dx == 0 then
        local s = dy>0 and 1 or -1
        for y=p1.y,p2.y,s do
            if not (self:xinbound(p1.x) and self:yinbound(y)) then
                return pixels
            end
            local z = p1.z-dz*(y-p1.y)/dy
            pixels[#pixels+1]={
                rgb=fn(p1.x,p1.y,p1.z),
                z=z,
                depth=p1.x*p1.x+p1.y*p1.y+p1.z*p1.z
            }
        end
    else
        local a = dy/dx
        local b = p1.y-a*p1.x
        local s = dx>0 and 1 or -1
        local step = math.abs(1/a)<1 and s/math.abs(a) or s
        for x=p1.x,p2.x,step do
            local y = a*x+b
            if not (self:xinbound(x) and self:yinbound(y)) then
                return pixels
            end
            local z = p1.z+dz*((x-p1.x)/dx-(y-p1.y)/dy)
            pixels[#pixels+1]={
                rgb=fn(p1.x,p1.y,p1.z),
                z=z,
                depth=p1.x*p1.x+p1.y*p1.y+p1.z*p1.z
            }
        end
    end
    return pixels
end

function renderer.colorspace.distance(col1,col2)
    return (col1[1]-col2[1])^2+(col1[2]-col2[2])^2+(col1[3]-col2[3])^2
end

function renderer.colorspace.toTermCol(col)
    local mind = math.huge
    local bestmatch = colors.black
    for i=1,#_colors do
        local v = {term.getPaletteColor(_colors[i])}
        --print(textutils.serialize(v))
        local d = renderer.colorspace.distance(v,col)
        if d < mind then
            mind = d
            bestmatch = _colors[i]
        end
    end
    return bestmatch
end

local function argmin(t)
    local minv = t[1]
    local mini = 1
    for i=1,#t do
        local v = t[i]
        if v < minv then
            minv = v
            mini = i
        end
    end
    return mini
end

local function normalize(t)
    local n = {}
    for i=1,3 do
        n[i] = math.max(0,math.min(t[i],0.99))
    end
    return n
end

function renderer.colorspace.mix(col1,col2,k)
    local col = {}
    for i=1,3 do
        col[i] = (col1[i]*k+col2[i]*(1-k))
    end
    return col
end

function renderer.colorspace.randomize(col,k)
    return normalize{col[1]+math.random()*k,col[2]+math.random()*k,col[3]+math.random()*k}
end

function renderer.colorspace.kmeans(k,points,centroids,n)
    -- Initialization: choose k centroids (Forgy, Random Partition, etc.)

    -- Initialize clusters list
    local clusters = {}
    for i=1,k do
        clusters[i] = {}
    end
    --[ [] for _ in range(k)]
    
    -- Loop until convergence
    local maxt = n
    local t = 0
    local converged = false
    while not converged and t < maxt do
        -- Clear previous clusters
        for i=1,k do
            clusters[i] = {}
        end --[ [] for _ in range(k)]
    
        -- Assign each point to the "closest" centroid 
        for _,point in pairs(points) do
            local distances =  {} --[distance(point, centroid) for centroid in centroids]
            for j=1,k do
                distances[j] = renderer.colorspace.distance(point,centroids[j])
            end
            local ci = argmin(distances)
            clusters[ci][#(clusters[ci])+1] = deepcpy(point)
        end
        -- Calculate new centroids
        --   (the standard implementation uses the mean of all points in a
        --     cluster to determine the new centroid)
        local function calculate_centroid(cluster)
            local centroid = {0,0,0}
            for _,point in pairs(cluster) do
                for i=1,3 do
                    centroid[i] = centroid[i]+point[i]
                end
            end
            for i=1,3 do
                centroid[i] = centroid[i]/#cluster
            end
            return centroid
        end
        
        local new_centroids = {}
        for i,cluster in pairs(clusters) do
            if #cluster == 0 then
                new_centroids[i] = centroids[i]
            else
                new_centroids[i] = calculate_centroid(cluster)
            end
        end
        
        converged = true
        for i=1,k do
            for j=1,3 do
                if centroids[i][j] ~= new_centroids[i][j] then
                    converged = false
                    break
                end
            end
            if not converged then break end
        end
        centroids = deepcpy(new_centroids)
        --print(textutils.serialize(centroids))
        if converged then
            return centroids,clusters
        end
        t=t+1
    end
    return centroids
end

function renderer:resetPalette()
    for i=1,16 do
        term.setPaletteColor(_colors[i],term.nativePaletteColor(_colors[i]))
    end
end

function renderer:optimizeColors(n)
    local centroids = {} --[c1, c2, ..., ck]
    for i=1,16 do
        centroids[i] = {}
        local col1 = {term.nativePaletteColor(_colors[i])}
        local col2 = {term.getPaletteColor(_colors[i])}
        for j=1,3 do
            centroids[i][j] = (col1[j]+col2[j])/2
        end
    end
    local newcolors = self.colorspace.kmeans(16,self:getUniqueColors(),centroids,n)
    local dblack = {}
    for i=1,16 do
        dblack[i] = self.colorspace.distance(newcolors[i],{0,0,0})
    end
    local bi = argmin(dblack)
    newcolors[#newcolors],newcolors[bi] = newcolors[bi],newcolors[#newcolors]
    local dwhite = {}
    for i=1,16 do
        dwhite[i] = self.colorspace.distance(newcolors[i],{1,1,1})
    end
    local wi = argmin(dwhite)
    newcolors[1],newcolors[wi] = newcolors[wi],newcolors[1]
    for i=1,16 do
        term.setPaletteColor(_colors[i],table.unpack(newcolors[i]))
    end
end

function renderer:render()
    for i = 1,self.size.x do
        for j = 1,self.size.y do
            local p = self.pixelbuffer[i][j]
            local col = self.colorspace.toTermCol(p.rgb)
            self.b:set_pixel(i,j,col)
        end
    end
    self.b:render()
end

return renderer
