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
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAADFBMVEVHcEzf39/MzMz///80VOl5AAAA
A3RSTlMACAVCxbpZAAAAOElEQVQYlWNgIBIwAwE6H1mEmRlVhBkBcAgwoPMxDUUHjMxMKDQDMwMzCg1i
QWSRTWFmQDcTpx0AfOUA04XnNpoAAAAASUVORK5CYII=
"""

CLOUDY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABlBMVEVHcEz///+flKJDAAAAAXRSTlMA
QObYZgAAACJJREFUGJVjYKAdYAQCdD6yCCMjqggjAuAQYEDnYxpKIQAAG2YAOFPLZBUAAAAASUVORK5C
YII=
"""

PARTLY_CLOUDY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAS1BMVEVHcEz+4gH94QL/4gH/qgD+4gIA
AAD//wD//wD/gAD//wC/vwD/4gH//1X/4gH/4wH/4wH+4gL+4QL/vwD//wD94QL/4gL/////4gAU8L63
AAAAF3RSTlMA/PD6A/UBAQICAwT7A/z3+/v6BAX5/btt1mQAAABiSURBVBiVjY9ZDoAgDERHRQH3He5/
UktBlvjjS4DMTEtT4C8K0ElJYMzCuqeroSOukFdcA3kf/DqmdtujIAxhLc5ck7O6WYJaTcBiXlLO+M8L
A0UJ3kExVuj8GpqT4buf8x+2sgbC4kG09AAAAABJRU5ErkJggg==
"""

SUNNY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAkFBMVEVHcEz/2wD/4gD/AAD/vwD//wD/
4gH//wD//wD/gAD/4QD/4gH/4wD94QL/v0D/4gL94QL/zACAgAD+4wD//1X+4gL/4gD/4gH//wD/4wH+
4QL+4gH/zAD/4wL/4QHV1QD/4gH/1QD+4gL/4wH/qgD//wD94QH/4gK/vwD/4gH+4gL/4wH/4gH/4gH/
4gH/4gDiBOmRAAAAL3RSTlMAB/4BBAP7AQIC+u3n+QT88AUC8gP9/fwF/Pr8Cvz6BvkM9fsDBPT9BP37
9/r29N+ljWAAAACDSURBVBiVdY9HEsMwDAPXiWza6b333v3/34VW5ISXcEYHYEEOBH8mheynRF9iaCeG
4wN6NAOf+4y480JCZrDd3WZilrqVXGdSyoxnofM9EQddbdRJvLFhfFdeFaHmjemnQHE/9jci01NWo777
BlrL4F9Ze9x2SoZckJOp8pIUW43yt2+ItwkjrEjHzwAAAABJRU5ErkJggg==
"""

RAINY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAGFBMVEVHcEwAAP9Vqv8A//9Erftmmf//
//9DrfvPnazlAAAABnRSTlMAAQMB5gU4/0sdAAAANUlEQVQYlWNgIBewAQE6H1mEjQ1VhA0BcAgwoPMx
DcUE7MwM7AwgBAWMYJIJIc8KkmQh1lcA1sYBfc6MmF4AAAAASUVORK5CYII=
"""

SUNNY_NIGHT = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAABAlBMVEVHcEyAgID/gIDqdyjtcBz//wDo
eCn/AAD/gEDtjC/rdyfqdyfqdyjfgEDmgETodynrdyXreCjofTHrmj/pdijpdyfvgDDbkknMmTPpdyjq
eCnpjTXugifxlTLihz2qVVXrdyfvmjP////reizqhTTmdibxmznpdynwpDvwmS/rdyfwnzvwiz7nkDrx
jjH/gFXvgED/mTPmkz/vmTDvjTP/n2DXeTb/gADwgyrwjy7qikfwojTvkjH/ZjPpiETtmz3wjy/yojbt
jjHxgyvwlTLtljnwmDP/gCv4w0PzoDb0sT35xEX3v0L4vkX5wEX5wkX6xUT4wETvji/5wUX2uUH3vEGa
tk7xAAAASHRSTlMAAgLrZAHiAQT87uT0CB7t7/GD0PT5EAcF9Obto91xA/n+AeF7Xe3h7f3k+CG95wYQ
Bbr9pAgTAuf+SP7zBUfd/v7a6/zR/QwQBKOaAAAAlUlEQVQYlWNgwABMGCKi8qh8EQV1VjMWFlVxuIgW
g7m9p6e2igRMgJXBNSTYz1dDjgMm4hQaaONsoafGwMDLCOLbOXi7MbjbGigzMPCDFVkFebsAKUMGMUEe
NpCAvmWAIwODqY6MEAM3xAwjL39rY01FYT4GdqipJl4eHj6yMB6DlBKDLienNNxdzAKSaH7hwvQwMgAA
jwsPj2J6sT4AAAAASUVORK5CYII=
"""

PARTLY_CLOUDY_NIGHT = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAACVBMVEVHcEz/////4gA0HsahAAAAAXRS
TlMAQObYZgAAACpJREFUGJVjYKAEMAEBOh9ZBI3LCATofKAIGh8hwogATOgC6ErQDCHXRwAzdwBgMxvI
OgAAAABJRU5ErkJggg==
"""

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

    CONDITIONS = dict(
        snowy = base64.decode(SNOWY),
        cloudy = base64.decode(CLOUDY),
        partlycloudy = base64.decode(PARTLY_CLOUDY_NIGHT if now.hour >= 20 else PARTLY_CLOUDY),
        sunny = base64.decode(SUNNY_NIGHT if now.hour >= 20 else SUNNY),
        rainy = base64.decode(RAINY),
    )

    print(conditions)
    

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