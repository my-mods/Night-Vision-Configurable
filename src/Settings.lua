local M = {}
local Upgrade = require('SettingsUpgrade')
M.schema = {
    {key='enabled',values={0,1},default=1},
    {key='nightVisionMode',values={0,1},default=1},
    {key='vignette',values={0,1},default=1},
    {key='vignetteOpacity',min=0,max=100,integer=true,default=20},
    {key='monochrome',min=0,max=100,integer=true,default=0},
    {key='redMonochrome',min=0,max=100,integer=true,default=0},
    {key='brightness',min=-2,max=4,default=-0.5},
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
