"""
Applet: Clock Weather
Summary: Display current weather
Description: Display current weather from HomeAssistant.
Author: Nick Penree
"""

load("render.star", "render")
load("time.star", "time")
load("http.star", "http")
load("cache.star", "cache")
load("schema.star", "schema")
load("encoding/json.star", "json")
load("encoding/base64.star", "base64")

SNOWY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAWlBMVEXe3t7d3d3e3t7IyMj////////e
3t5HcEzMzMzf39/b29vc3Nzb29uqqqrd3d3e3t7V1dXe3t7d3d3e3t7////b29vd3d3e3t7e3t7c3Nze
3t7d3d3c3Nze3t4aoU/4AAAAHXRSTlP+++wOAgH4AAUIldNAA83pBvr69wP42f3otu3g1qgjW0AAAABo
SURBVBiVXc7ZEoAgCAVQKk3b9z3+/zcjCrXuC8yBYQDzCzxFmzYEq0qEQnkYASlNIqB75NS5ukGbFSVQ
EWQDOMCTYMYgE8ERwkZgO5Asu3vs+2mWWu653hCbiIErvGtuKjdkyx+V5gLvfQvvBzLmeQAAAABJRU5E
rkJggg==
"""

CLOUDY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAbFBMVEVHcEza2trY2NjX19fV1dX////Z
2dne3t7////e3t7Z2dn////c3Nze3t7d3d3d3d3Z2dna2trd3d3c3Nzb29vd3d2/v7/////d3d3b29va
2trb29vc3Nzb29vc3Nza2trb29vW1tbd3d3e3t5buUjUAAAAI3RSTlMAmY8TBgJr7wH+SgPk8tPPWG/x
kAf7BAfY5XbQ95TOg4Zq57A342oAAABZSURBVBiVY2CgGuBiYmNG4nLwcyorCwlywPgsfMogwCkgAhVQ
VIYAUV5GMSBXXEpCGQ7kgQKyykhAEigggyygBBSQRhZQANkhxw4DPMKsyI7hYOXmYCACAADbyQryzeEY
ZQAAAABJRU5ErkJggg==
"""

PARTLY_CLOUD = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAn1BMVEVHcEwAAAD/4gHd3d3//////wD/
4gLe3t7/4gD//wD////e3t7b29vc3NzV1dXa2trc3NzExMTr6+vMzMzd3d3U1NTe3t7b29ve3t7c3Nzc
3Nze3t7b29vc3Nzc3Nzr2ADo3Gf+4QXx1Q7MzLP/2wD+4gL/4QH/4gL/4QH+4gHy1wf/4gHV1QD/4QD/
/wDy1w3/4gD/gAD/5ALe3t7/4gCZGR61AAAAM3RSTlMAAf38AQT9lf0BBsaGvBJuuA0NBds1/Yf+v0Hs
m/K+DVfiEgoH/ff3+fkm+wb0AhP8AvTSpjXRAAAAbUlEQVQYlWNgIBKwovE5UHjqDIwGKGKcbHoMhkh8
Rk4dI10mTmUpUWGIgKqGlqYJE4O0hJiIEERERZ9DW1HWGAi4eVjAVqoxKMgYQ4CAIFCAjVNJDso3ZgYr
kWeQhAnwckGtEmcHA34+Yr2GDAAHBgr5dChOaQAAAABJRU5ErkJggg==
"""

SUNNY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAA+VBMVEVHcEz/4gL+4wL+4gL/gAC/vwDV
1QD//wCqqgD//wD/4gH+4gL/4gD43gP/4gD+4gH/4QH/4gD/4wH/4QD94QH/qgD+4QL/4gH/4gH/4wL/
4QL/vwDw4QD+4gL/4gL/4gL+4gL/4wL+4gH94QH/4ADl0wn94QL43wT/4wD+4gL+4gH+4QH/4gH/4wH+
4gD+4gHm1gj/4gL43gP/4wL84AL/4gH/4gH/4gH+4QHv1wj/4gL/4wL+4QH+4wH33QX84QL/4gL//wD3
3gj/4gH84AP+4wL/4QL+4QL+4QH+4gL94QLw0g/94QKAgAD/4gD/4gL/4gH54AT/4gDwnl1+AAAAUnRS
TlMA+fLvAgQGAQMC9P3umv7h9+v09PQD9/Hk8voEEePx2vn87N7RHfC15+ro0vz39fQf65X3ld/9+O0g
5/XN4pfl+AMf7ZX19Nj49eMR9gLa4fazcoKbSAAAAKdJREFUGJV1T9UCwkAM6wbjbsZwd3d3d9f7/4/h
Jgx4IE9NmqYtwB9YWOuHZGjdG3DAB5DG0/PTFabKEo9zfk1A+8OOttBWHNn0EXw/y8fLbLVA7xD8tBNC
NgYrFtbwoJxMQKg2qRCXSnBTBQW6Ujmsmfi8OtIx78BMRK7XWsO+EYrYRAhlG6hdielrHT4GQVTkcNDj
0i1uHiAlcOB1mofQ55Jfz/3gBXRWElejCYEuAAAAAElFTkSuQmCC
"""

RAINY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAk1BMVEVHcEyAgP/MzMyqqqr///////8A
///e3t7////R0dGAgIC/v7/d3d3d3d3c3Nzc3Nzd3d3e3t7c3Nzc3Nzd3d3T09PY2Njc3NzV1dXd3d3e
3t7c3Nzb29vb29vc3Nzb29vd3d3Y2Njc3Nze3t7d3d3d3d1FsP3d3d1Vqv9Er/5AgL9Fr/1Drv1Erv0A
gP9Fr/3e3t48D4TKAAAAMHRSTlMAAgUDAgMB/AELAgTp26fE2v7drtgXDc4Y3O6vB2rCYtIhZ/b3+vT7
A/ME+vr9Av0UY5lHAAAAgUlEQVQYlW2PBw6DMAxFfyBJE+hedNO9oMX3P10TCpEr9UmW9b5kWwb+s1nM
Iu5yPR72mc+75OgFj6ZUM9h+XR1O1DDybndnCmQxkBNjZYEjDybGzexvnYbL0tZbjUmkSlMVJ+FwBV0A
11b93NOVaIOHQAm8+C9GC2j5++8buPv+AYRxDsZP5gFRAAAAAElFTkSuQmCC
"""

CONDITIONS = {
    "snowy": base64.decode(SNOWY),
    "cloudy": base64.decode(CLOUDY),
    "partlycloudy": base64.decode(PARTLY_CLOUD),
    "sunny": base64.decode(SUNNY),
    "rainy": base64.decode(RAINY),
}

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "homeassistant_server",
                name = "Home Assistant Server",
                desc = "URL of Home Assistant server",
                icon = "gear"
            ),
            schema.Text(
                id = "entity_id",
                name = "Entity ID",
                icon = "user",
                desc = "Entity ID of the weather entity in Home Assistant",
            ),
            schema.Text(
                id = "auth",
                name = "Bearer Token",
                icon = "key",
                desc = "Long-lived access token for Home Assistant",
            ),
        ],
    )

def get_conditions(config):
    weather = None
    cache_key = "%s.%s" % (config.get("homeassistant_server"), config.get("entity_id"))
    cached_weather = cache.get(cache_key)
    if cached_weather != None:
        weather = json.decode(cached_weather)
    else:
        ha_server = config.get("homeassistant_server")
        entity_id = config.get("entity_id")
        token = config.get("auth")
        rep = http.get("%s/api/states/%s" % (ha_server, entity_id), headers = {
            "Authorization": "Bearer %s" % token
        })
        if rep.status_code != 200:
            fail("HTTP request failed with status %d", rep.status_code)
        weather = rep.json()
        cache.set(cache_key, rep.body(), ttl_seconds = 240)
    return weather

def main(config):
    if config.get("homeassistant_server") == None:
        fail("Home Assistant server not configured")

    if config.get("entity_id") == None:
        fail("Entity ID not configured")

    if config.get("auth") == None:
        fail("Bearer token not configured")

    timezone = config.get("$tz") or "America/New_York"
    now = time.now().in_location(timezone)
    conditions = get_conditions(config)
    

    temp = int(conditions["attributes"]["temperature"])
    temp_unit = conditions["attributes"]["temperature_unit"]
    humidity_percent = int(conditions["attributes"]["humidity"])
    condition = conditions["state"]
    condition_img = CONDITIONS.get(condition, None)

    print("Temperature: %i%s" % (temp, temp_unit))
    print("Humidity: %i%%" % humidity_percent)
    print("Condition: %s" % condition)

    return render.Root(
        delay = 500,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "start",
            children = [
                render.Box(
                    height = 15,
                    child = render.Animation(
                        children = [
                            render.Text(
                                content = now.format("3:04 PM"),
                                font = "6x13",
                            ),
                            render.Text(
                                content = now.format("3 04 PM"),
                                font = "6x13",
                            ),
                        ],
                    ),
                ),
                render.Row(
                    expanded = True,
                    main_align = "center",
                    cross_align = "start",
                    children = [
                        render.Image(
                            src = condition_img,
                            width = 16,
                            height = 16,
                        ) if condition_img else None,
                        render.Column(
                            expanded = True,
                            main_align = "center",
                            cross_align = "start",
                            children = [
                                render.Box(
                                    height = 8,
                                    width = 20,
                                    child = render.Text(
                                        content = "%i%s" % (temp, temp_unit),
                                        font = "tb-8",
                                    ),
                                ),
                                render.Box(
                                    height = 6,
                                    width = 20,
                                    child = render.Text(
                                        content = "%i%% " % humidity_percent,
                                        font = "tb-8",
                                        color = "#0000FF",
                                    ),
                                ),
                            ]
                        )
                    ]
                )
            ]
        ),
    )