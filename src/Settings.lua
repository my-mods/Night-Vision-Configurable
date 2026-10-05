local M = {}
local Upgrade = require('SettingsUpgrade')
local redBrightnessValues={}
for value=100,500,10 do redBrightnessValues[#redBrightnessValues+1]=value end
local naturalSizes,naturalSoftnesses={},{}
for value=40,100,5 do naturalSizes[#naturalSizes+1]=value end
for value=20,100,5 do naturalSoftnesses[#naturalSoftnesses+1]=value end
M.schema = {
    {key='enabled',values={0,1},default=1},
    {key='nightVisionMode',values={0,1,2},default=1},
    {key='radiusMeters',min=5,max=50,integer=true,default=6},
    {key='naturalFocusSize',values=naturalSizes,default=90},
    {key='naturalSoftness',values=naturalSoftnesses,default=70},
    {key='vignette',values={0,1},default=1},
    {key='vignetteOpacity',min=0,max=100,integer=true,default=20},
    {key='monochrome',min=0,max=100,integer=true,default=0},
    {key='keepBloodRed',values={0,1},default=0},
    {key='redBrightnessPercent',values=redBrightnessValues,default=100},
    {key='redMonochrome',min=0,max=100,integer=true,default=0},
    {key='brightnessPercent',min=25,max=300,integer=true,default=200},
    {key='controllerInput',values={0,1},default=1},
    {key='debugLogging',values={0,1},default=0},
}
function M.start(directory, apply, report)
    local ids, defaults = {}, {}
    for _, field in ipairs(M.schema) do
        ids[field.key], defaults[field.key] = field.key, field.default
    end
    local live = require('UE4SSDawnwalkerSettings').new({
        modId='NightVisionConfigurable', schema=M.schema, ids=ids, report=report,
    })
    live.attach(apply)
    local function reload()
        local values,err=Upgrade.load(directory,M.schema,defaults)
        if values then live.seed(values); apply(values)
        else report('Settings: '..tostring(err)..'; previous values retained.') end
    end
    reload()
    live.start(function(id, callback) return require('dmm_api').subscribe(id, callback) end)
    return reload
end
return M
