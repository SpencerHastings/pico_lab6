ruleset manage_sensors {

    meta {
        provides sensors
        shares sensors
    }

    global {

        default_threshold = "80.0"
        default_phone_number = "8013100486"


        sensors = function(name) {//return eci
            sensor = ent:sensors.filter(
                function(s) {
                    s.get("name") == name
                }
            )
            ret = (sensor.length() == 1) => sensor[0] | null
            ret
        }

        all_temperatures = function() {
            ent:sensors.map(
                function(s) {
                    eci = s.get("eci")
                    args = {}
                    Wrangler:skyQuery(eci, "temperature_store", "last_temperature", args)
                }
            )
        }

        __testing = { "queries": [],
            "events":  [ { "domain": "sensor", "type": "new_sensor", "attrs": [ "name" ] } ] 
        }

    }
    
    rule on_new_sensor {
        select when sensor:new_sensor
        pre {
            name = event:attr("name")

            check = sensors(name)
            eci = meta:eci

            rids = "temperature_store;sensor_profile;twilio_lesson_keys;twilio_m;wovyn_base"
        }
        
        if (check != null) then
            send_directive("name already taken", {"name":name})
        notfired {
            
            raise wrangler event "child_creation"
                attributes { 
                    "name": name, 
                    "color": "0x555555",
                    "rids": rids 
                }
        }
    }

    rule delete_sensor {
        select when sensor:unneeded_sensor
        
        pre {
            name_to_delete = event:attr("name")

            check = sensors(name_to_delete)

        }
        if (check != null) then
            send_directive("deleting sensor", {"name": name_to_delete})
        fired {
            raise wrangler event "child_deletion"
                attributes {"name": name_to_delete};
            ent:sensors := ent:sensors.filter(
                function(s) {
                    function(s) {
                        s.get("name") != name_to_delete
                    }
                }
            )
        }
    }

    rule save_new_sensor {
        select when wrangler child_initialized
        pre {
            name = event:attr("name")
            eci = event:attr("eci")
            newSensor = {
                "name":name, 
                "eci":eci
            }

        }
        if name.klog("adding sensor")
        then
            event:send(
                {
                    "eci": eci,
                    "eid": "1337",
                    "domain": "sensor",
                    "type": "profile_updated",
                    "attrs": {
                        "name": name,
                        "threshold": default_threshold,
                        "phone_number": default_phone_number
                    }
                }
            )
        fired {
            ent:sensors := ent:sensors.defaultsTo([]).union([newSensor])
        }
    }

    // after pico is done being made, send a sensor:profile_updated event to prime it


}
