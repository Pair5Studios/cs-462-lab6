ruleset manage_sensors {
  meta {
    shares __testing, sensors, all_temperatures
    // provides sensors, all_temperatures
    use module io.picolabs.wrangler alias Wrangler
  }
  global {
    __testing = { "queries": [ 
        { "name": "__testing" },
        { "name": "sensors" },
        { "name": "all_temperatures" },
      ] , "events": [ 
        { "domain": "sensor", "type": "new_sensor", "attrs": ["name"] },
        { "domain": "sensor", "type": "unneeded_sensor", "attrs": ["name"] }
      ]
    }
    
    default_temperature_threshold = 100
    default_phone = "+19518582052"
    
    sensors = function(){
      ent:sensors
    }
    
    all_temperatures = function(){
      ent:sensors.map(function(v,k){
        eci = v{"eci"}
        Wrangler:skyQuery(eci, "temperature_store", "temperatures")
      })
    }
  }
  
  
  
  
  rule create_sensor {
    select when sensor new_sensor
    pre {
      name = event:attr("name")
      exists = ent:sensors >< name
    }
    
    if not exists then noop()

    fired {
      
      raise wrangler event "child_creation"
        attributes { "name": name, "color": "#ffff00", "rids": ["temperature_store", "sensor_profile", "wovyn_base", "twilio_app"] }
    }
  }
  
  
  
  
  rule sensor_already_exists {
    select when sensor new_sensor
    pre {
      name = event:attr("name")
      eci = meta:eci
      exists = ent:sensors >< name
    }
    
    if exists then
      send_directive("Sensor Already Ready", {"name": name})
  }
  
  
  
  
  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      name = event:attr("name").klog()
      sensorObj = {"eci": event:attr("eci")}
    }
    
    if sensorObj then 
    event:send({
      "eci": sensorObj{"eci"}.klog("ECI:"),
      "domain": "sensor",
      "type": "profile_updated",
      "attrs": {
        "name": name, 
        "location": "", 
        "threshold": default_temperature_threshold, 
        "phone": default_phone
      }
    })
    
    fired {
      ent:sensors := ent:sensors.defaultsTo({})
      ent:sensors{[name]} := sensorObj.klog("Saving new child info for " + name + ":")
    } else {
      name = name.klog("Child info not saved")
    }
  }
  
  
  
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
    }
    
    if name then send_directive("Deleting sensor", {"name": name})
    
    fired {
      raise wrangler event "child_deletion" attributes {"name": name}
      ent:sensors := ent:sensors.delete([name])
    }
  }
}

