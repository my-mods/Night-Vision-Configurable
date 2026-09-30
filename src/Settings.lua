local M = {}
local Store = require('SettingsStore')
M.schema = {
    {key='enabled',values={0,1},default=1},
    {key='monochrome',min=0,max=100,integer=true,default=0},
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
        local values, err = Store.load(directory, M.schema, function() return defaults end)
        if values then live.seed(values); apply(values)
        else report('Settings: '..tostring(err)..'; previous values retained.') end
    end
    reload()
    live.start(function(id, callback) return require('dmm_api').subscribe(id, callback) end)
    return reload
end
return M
