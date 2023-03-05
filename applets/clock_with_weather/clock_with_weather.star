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
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAA81BMVEVHcEzd3d3X19fd3d3////b29vd
3d3e3t7d3d3e3t6qqqra2trZ2dnd3d3d3d0AAADT09Pa2trV1dXe3t6AgIDa2trT09Pc3Nzc3Nzf39/Y
2Njd3d3W1tbY2Njb29vb29vX19fc3Nzb29vZ2dnc3Nze3t7b29vd3d3e3t7b29vX19fd3d3e3t7////b
29ve3t7b29vV1dXc3Nzc3NzY2Nja2trb29vX19fe3t7V1dXb29vb29vY2Njb29ve3t7b29va2trb29ve
3t7a2trZ2dnb29va2trY2Njd3d3b29vZ2dna2trb29vc3Nzc3NzW1tbe3t4fRWcfAAAAUHRSTlMA+i3Z
Aqz7/kT9A25/980BHSIG6QKEQKDTCC5THzuVo0bW+Fe29yvg7Q4TD/oEMj05DOavDTA4UxdWqdZV40W4
KXEuaBsce3wmsVh2pSz7GW3/ickAAACdSURBVBiVbc/lCsMwFIbh+lkqc7fO3d3dNfd/NTsdpBS2F/Lj
eyCEcNzfgt5w3O/YsRBPIeqztycCFAsIDFI8/eZOZyScUtKkLEgg5ItgA80iiNRRDqHshAKC1gAWqZQQ
moLLaoWnXbMelUaz2/F51neHqdxREbpzYmiPlyLvDSJWEQZLUO5XQtZbBXp168pQXrwvJ30zGfdb6u/H
Py9iHk1Ruh+BAAAAAElFTkSuQmCC
"""

CLOUDY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAAe1BMVEVHcEzd3d3Z2dnZ2dn////V1dXV
1dXf39/e3t7e3t7a2trd3d3Y2NjX19fV1dXd3d2qqqrR0dHW1tbd3d3Z2dnd3d3c3Ny/v7/c3Nzb29vX
19fc3NzV1dXd3d3b29va2tre3t7a2trb29vd3d3c3Nzb29va2trb29ve3t4fjdNUAAAAKHRSTlMA8Upr
AQwGEO/+b8+PEzfTAwtqD1jYzgT30DrkEvuUdvKDB+eQ5ZmG4Wb7xQAAAFxJREFUGJWtz0cSgCAQRFFU
EDHnnOPc/4SORWGxdOHf9ds1IX9lm74VaDv0BIDhxmonETyJvKcSUpAN87niZFMBbwvCCFoHQq3DhtDo
cCG0paPqdo5AGVdl1ZcXN613DP6CGc3jAAAAAElFTkSuQmCC
"""

PARTLY_CLOUD = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAA4VBMVEVHcEzExMTb29ve3t7b29vd3d3T
09Pe3t4AAADa2trV1dXc3Nzc3NzV1dXe3t7MzMzd3d3b29vW1tbe3t7U1NTz3Abc3Nze3t733ATv3wD1
3gXv1gjc3Nz74QL/2wD12wP//wD94ALc3Nzb29ve3t7d3d374QPx1QDz2gP23QXz3Azz2QP43gP43gPu
2iro3GX53wL53gPd2sTd3bv03gb84gP+4QH+4gH94gP23ATy2Q322wXy1wf94QH02wX44QT54gb94QH/
/wD+4gHV1QD44Qj43gf53wH84ALe3t7/4gBhF/pcAAAASXRSTlMADYbGI/wXlQFuDLy4EhcF24cf/TUs
v/5BEGsfQXgHTgThvpvs9MwSUnEWWKpOZ1iJXFIPLrjx/eE7FDgm1V1ELPEB+QYidbeSTpQLxAAAAHtJ
REFUGJVjYCAOqMuhCRhoIPM07Tk8DBlkJeAClhau1g4matIwPoeTi6mXuZ2xjAg/REDH3cbZy9ZIRVxY
gA8sIK9tZeaop+oJBMxMbCARBV03fWVPCOBhBApIKWopQfmerCxAAVFJBjGYADcXxGAhQXYw4OQl0mso
AABoSBK3y4zMPAAAAABJRU5ErkJggg==
"""

SUNNY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAABCFBMVEVHcEzV1QD+4QH74AH/gAC/vwD4
4Qj//wCqqgD//wD64QT84AP+4QDz2wD+4gH33wX43gP/4gDv3wDt2xL/qgD94QH/6wDbzgz44AT/7QDu
3QDo0QD94QL94QP13ATm2Q333wP43gL43QT74Qb54QT74QP/4gH54QT74Qb84gL63wL33gP84QLl0wn+
4QH+4QH+4AH74QTv1wj33gj43gL43gP74QH44AX94gLt2wn+4gD//wD84AL/4gD+4gLm1gj33QX94QL+
4gLr1gD94QLx3Af11gD54AT+4gP03wf+4QH53wT13gX/4gD43wT+4gH/4gHw0g/w4QD43gTs2Qn13wWA
gAD/4gACHDNlAAAAV3RSTlMABrLWAgQiAQMCj5W8FeFhmv4QDgPwDRWLDg8L8OWFFKXOkIGJq7iIiqiY
pOUd+bS3kCAfbJXJbKAc9QOVuPgfl/b1GaNIGbP3SPiJZfa19PYREY0bZgIT7yGmAAAApklEQVQYlWNg
wAGUtFkQHGkgm4mZlYFTmB3Ml9cJDmPQNLPmUJFhAwuwe3u5sodYsvPbKTNCtHD4BAo4OToYm7PDDOFw
FwwPD+eG8rhsLZwDgPxwPl59NW5JBgZDHhc3X4iAAY+WFFgRpx9Iiw3cHRyhQQL+VqZGJlBD2dU9PNl1
7dn59eQg1orLarAzqCqyckiIQhzGIMYJcbqIENwhQMsVkDyHAgA/+RRiWyY6igAAAABJRU5ErkJggg==
"""

RAINY = """
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAA5FBMVEVHcEzY2NiqqqrT09PY2NjR0dH/
///e3t7b29vMzMzc3Nzd3d3V1dXV1dXc3Nzc3Nzd3d3d3d3b29vW1tbW1tbb29v////e3t7c3Nzd3d3e
3t7c3Nzc3Nze3t7c3Nzb29vZ2dnc3Nzd3d3Jycnd3d3d3d3d3d3d3d2/v79Gr/bW1tZKre9HsP0zmf9V
qv9FrPVFr/lGr/lFsPpDrvZGsfxGouhGsPlGsf1Fsf05quNHr/pDrvJHrvdGsPpGsftHrvRGsP1GrfNH
rfpHr/pGrfdHretGsftGr/xGsf1Vqv9GrvPe3t7TWwYtAAAAS3RSTlMAIQMXJwsB/BwFp9oxGN2v2+kH
LB9qA/bH2O7Orv7CYj1n9xPc0vr7BJIZH/kFAzS1g5Q57hau2t0JjSZe17Ze81QyyoMZ2urdCUI1rG3Z
AAAAiUlEQVQYlWNgwA6EeJk5kfnC/HzcXCIIPo+gNxAIsMD4nJLeYCAhysIG4osxintDgawCkM8qp+QN
B9JMDAzy3khAipWBQRFZQAZoiLKqOjsUqKkwggzV0OKAAmYmqL2m5k42bp5mhjB36Nk5W7u7ODoYwwT0
dbysLCw9jOAu1zTQtbV3NdHG7m8AY1gam9DytZkAAAAASUVORK5CYII=
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
                                        content = "%i%%" % humidity_percent,
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