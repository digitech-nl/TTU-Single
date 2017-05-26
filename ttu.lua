-- TTU-Dashboard.lua

-- Locals for the application
local wbSensorName="Digitech-TTU"
local wbFuelParam = 1
local wbBattParam = 5
local wbPumpParam = 6
local wbStatusParam = 9
local wbSensorID=nil
local wbECUType = nil
local wbECUTypePrev = nil
local wbStatusText=nil
local wbStatusPrev=nil
local lStatus       = ''
local lFuel = 0
local lBatt = 0
local lPump = 0
local lPumpUnit = ""
local catalog

--------------------------------------------------------------------
-- Get the ID of the WhiteBox Sensor
function getWBSensorID()
    local tmpSensorID=nil

    for index,sensor in ipairs(system.getSensors()) do 
        -- print(string.format("Sensor ID: (%d)",sensor.id&0xFFFF), sensor.id)
        if(sensor.param == 0) then
           print("Sensor Name: ", sensor.label)
           if((sensor.id&0xFFFF)==0xA4DD) then
              tmpSensorID=sensor.id
              collectgarbage()
              return tmpSensorID
           end
        end
        
        --if(sensor.param==wbPumpParam and sensor.id==tmpSensorID and tmpSensorID~=nil) then
        --  lPumpUnit=sensor.unit
        --end
    end
    collectgarbage()
    
    return tmpSensorID
end

local config    -- complete turbine config object read from file with manufacturer name

--------------------------------------------------------------------
-- Read messages file
local function DrawFuelGauge(percentage, ox, oy) 
    
    -- gas station symbol
    lcd.drawRectangle(34+ox,31+oy,5,9)  
    lcd.drawLine(35+ox,34+oy,37+ox,34+oy)
    lcd.drawLine(33+ox,39+oy,39+ox,39+oy)
    lcd.drawLine(40+ox,31+oy,42+ox,33+oy)
    lcd.drawLine(42+ox,33+oy,42+ox,37+oy)
    lcd.drawPoint(40+ox,38+oy)  
    lcd.drawLine(40+ox,38+oy,40+ox,35+oy)  
    lcd.drawPoint(39+ox,35+oy)
    lcd.drawText(34+ox,2+oy, "F", FONT_MINI)  
    lcd.drawText(34+ox,54+oy, "E", FONT_MINI)  
  
    -- fuel bar 
    lcd.drawRectangle (5+ox,53+oy,25,11)  -- lowest bar segment
    lcd.drawRectangle (5+ox,41+oy,25,11)  
    lcd.drawRectangle (5+ox,29+oy,25,11)  
    lcd.drawRectangle (5+ox,17+oy,25,11)  
    lcd.drawRectangle (5+ox,5+oy,25,11)   -- uppermost bar segment
    
    -- calc bar chart values
    local nSolidBar = math.floor( percentage / 20 )
    local nFracBar = (percentage - nSolidBar * 20) / 20  -- 0.0 ... 1.0 for fractional bar
    local i
    -- solid bars
    for i=0, nSolidBar - 1, 1 do 
      lcd.drawFilledRectangle (5+ox,53-i*12+oy,25,11) 
    end  
    --  fractional bar
    local y = math.floor( 53-nSolidBar*12+(1-nFracBar)*11 + 0.5)
    --lcd.drawFilledRectangle (5+ox,y+oy,25,11*nFracBar) -- FIX THIS
end

local function DrawTurbineStatus(status, ox, oy) 
    lcd.drawText(4+ox,2+oy, "Turbine", FONT_MINI)  
    lcd.drawText(4+ox,15+oy, status, FONT_BOLD)  
end

local function DrawBattery(u_pump, u_ecu, ox, oy) 
  lcd.drawText(4+ox,1+oy, "PUMP", FONT_MINI)  
  lcd.drawText(45+ox,1+oy, "ECU", FONT_MINI)  
  if(lPumpUnit=="V") then
    lcd.drawText(4+ox,12+oy,  string.format("%.1f%s",u_pump,lPumpUnit), FONT_BOLD)
  else
    lcd.drawText(4+ox,12+oy,  string.format("%3d%s",u_pump,lPumpUnit), FONT_BOLD)
  end
  lcd.drawText(45+ox,12+oy, string.format("%.1f%s",u_ecu,"V"), FONT_BOLD)
end

local function wbTele()

  DrawFuelGauge(lFuel,1,0)
  DrawTurbineStatus(lStatus,50,0)
  DrawBattery(lPump,lBatt,50,37)

end
--------------------------------------------------------------------
-- Read messages file
local function readCatalog()
    -- print("Mem before config: ", collectgarbage("count"))
    local file = io.readall("/Apps/digitech/catalog.jsn") -- read the catalog config file
    if(file) then
        catalog  = json.decode(file)
    end
    collectgarbage()
    -- print("Mem after config: ", collectgarbage("count"))
end
--------------------------------------------------------------------
-- Read messages file
local function readConfig(wECUType)
    -- print("Mem before config: ", collectgarbage("count"))
    -- print(string.format("ECU Type %s _ %s",wECUType,catalog.ecu[tostring(wECUType)].file))
    local file = io.readall(string.format("/Apps/digitech/%s",catalog.ecu[tostring(wECUType)].file)) -- read the correct config file
    if(file) then
        config  = json.decode(file)
    end
    collectgarbage()
    -- print("Mem after config: ", collectgarbage("count"))
end

------------------------------------------------------------------------ 
local function getStatusText(statusSensorID)
    local lStatus    = ''
    local value         = 0 -- sensor value
    local ecuStatus = 0
    local switch
    local lSpeech    
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbStatusParam))

    if(sensor and sensor.valid) then
        value = string.format("%s", math.floor(sensor.value))
        wbECUTypePrev=value>>8
        ecuStatus=value&0xFF        
        -- print(string.format("Status  %s",tostring(ecuStatus)))
        if(ecuStatus~=wbStatusPrev) then
          if(config.message[tostring(ecuStatus)] ~= nil) then 
            lStatus = config.message[tostring(ecuStatus)].text
            if(lStatus==nil) then
              lStatus="[unknown]"
            end
            lSpeech= config.message[tostring(ecuStatus)].speech
            if(lSpeech~=nil) then
                print(string.format("Status  %s",tostring(lSpeech)))
                system.playFile(string.format("/Apps/digitech/audio/%s",lSpeech),AUDIO_IMMEDIATE)
            end
          end
          wbStatusText=lStatus
          wbStatusPrev=ecuStatus
        else
          lStatus=wbStatusText
        end

    else
        lStatus = "          -- "
    end

    -- print(string.format("statusSensorID: %s, text: %s ", statusSensorID, lStatus))

    return lStatus 
end
------------------------------------------------------------------------ 
local function getWBECUType(statusSensorID)

    local value         = 0 -- sensor value
    local ecuType = nil
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbStatusParam))

    if(sensor and sensor.valid) then
        value=sensor.value
        ecuType=value>>8
        -- print(string.format("ecutype orig: %s, shifted: %s ", value, ecuType))
        readConfig(ecuType);
    else
        ecuType=nil
    end
    return ecuType 
end
------------------------------------------------------------------------ 
local function getFuel(statusSensorID)

    local value         = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbFuelParam))

    if(sensor and sensor.valid) then
        value = sensor.value
    else
        value = 0
    end
    return value 
end
------------------------------------------------------------------------ 
local function getPump(statusSensorID)

    local value         = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbPumpParam))

    if(sensor and sensor.valid) then
        value = sensor.value
        lPumpUnit=sensor.unit
    else
        value = 0
    end
    return value 
end
------------------------------------------------------------------------ 
local function getBatt(statusSensorID)

    local value         = 0 -- sensor value
    local sensor = system.getSensorByID(statusSensorID, tonumber(wbBattParam))

    if(sensor and sensor.valid) then
        value = sensor.value
    else
        value = 0
    end
    return value 
end
-- Application initialization.


local function init(code)
    -- wbSensorID   = system.pLoad("wbSensorID", nil)
    system.registerTelemetry(1,"TTU - Dashboard",2,wbTele); 
    readCatalog()
    wbSensorID=getWBSensorID()
end

-- Loop function is called in regular intervals
local function loop()
  if(wbSensorID ~= nil and wbSensorID ~= 0 and wbECUType ~= nil) then
    -- print("Sensor Name: ", wbSensorID.name)
    if(wbECUType~=wbECUTypePrev) then
      wbECUType=getWBECUType(wbSensorID)
    end
    lStatus=getStatusText(wbSensorID)
    lFuel=getFuel(wbSensorID)
    lPump=getPump(wbSensorID)
    lBatt=getBatt(wbSensorID)
  else
    if(wbSensorID == nil) then
      wbSensorID=getWBSensorID()
    end
    if(wbECUType==nil and wbSensorID ~= nil) then
      wbECUType=getWBECUType(wbSensorID)
    end
  end
end
-- Application interface

return {init = init, loop = loop, author = "Digitech", version = "1.0", name = "TTU Dashboard"}