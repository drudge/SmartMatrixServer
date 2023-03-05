load("cache.star", "cache")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

## Modified from https://github.com/savdagod/TidbytAssistant

ICON_OPEN = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAoRJREFUOE9lVEtW
G0EMLPWYba4SWJMF4BMEjpH483wQ7MHkGDgniCEPZ41zlWzxtPKqpBkH4sV4plutLpWqZDBzg0M/N8Ac
rk/jVu4YNxVi/NOnKZzB/OOim8MM5nrJhHxnpC6xPpHpYJzjTsQwuy7gaYbEdiR8GwBUJkg0ThRKHoiY
qyklto/1CQTj3IkowVTvshzH4v6nEKiCqI9HcPv1IikwlIbV5OEoaqgXXVe1ufv1jIeXA65PT/B9f8Dn
0xE2e36PsPl9wM3HER72B9xOLnShlShZqXt2vFal3+2eVWpQlKhU7bvGJG/nn86VqFjpqTRnNyvRlUY8
uK4RYVED1/iqTmanB1E4Oq9orAlqJBsHOu/QlGZoxKzdphwCLTeioxGymo4DNBy11jjbN4U7tXYoeQsz
zNc/sPxyGYiSg1ADsPj2hNVkHMiZprK6ktrNLnORHWNp8/VW/KmbKV7SYNKiYXH/pLqXmbRWR2lKiNzS
DpRLKQ3md9vgq6dR6N5pvBeKO9rpWHTx7P8JrWB2t0U7u4pS/gD2YZCcwNZc4/usfcRqeolAKAGmU0is
O0oxzNttMJ8tuT5rpEHecHN2gs3La/g2jd1OrtBVR0O6wnqgUVC74IHL6rBBwg656CGXEMVm/6r31fRK
cZRcYVPCI/FUU+hPd8zvHoVvOb3MeRDNSgyYraOKNvfpMJ7lmRwOgHd18OoguL74Xs1ZUwyeHGeaPkDR
MAjz5QAcLH6cWqmzMN3RelFXfqd5Q/xE2KtzmH3JVeLVbBzGYphcAs/RFRMomsi40OGwGAaNWfDPtA4C
s6Sj/yT2fpL09GgeZmjOzxRMDNIQtex0jOrHX7roeBnwFyJ6fy+gno16AAAAAElFTkSuQmCC
""") 

ICON_CLOSED = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAktJREFUOE9lVNF1
IjEMlHZJPSQVwJVwXBnAR6CObD5IyuBSAlwFIfWEte/NjOSFF+CZXVuWRiON3Myqu1u1/OST48g8Xqvf
vuMZp9W0rbNqjq9XXMKC17BkABrrZi7cxFVL23yCj7gDT/JeFQW/UsaIDB/V6l0Es57RhGzyDXz0xZWR
aykN1P793x2azGRYL5kNsuq6XrRoiX26cBsD1e79TLRMNECESWLiwbBdEkjXdXQoBoP2sRY+7d7OjCze
kD4Ko//K/0gUAd0MaPGBUxTX3cVcKdX2bydeWj3NkBBR4OzjciW3f55mrZYg9e/XSA5JQd+LThQNxuBu
B4eqUMKYUKqJGIg2scLwZb20vu/ESrYgED4fTqzP6vGhFQkGx89v7c8fgnwV9/h1ZcBhs7Dee/IdId1K
HW13OCdt0T6BJRDTmGlFW0fFXre/rCOyaBuogCkfTpCNreb91Lhu9nH55vvvx9nU5O7cR6xXcIj2QQHB
GDZLhcOz1JIVzY5E9cBdVJ6NHsnBZNjAYcciBoduZSz2jP4za0iYmZsdL+Cq2mo+mygBws8rgw8bpcwm
VNtIantwGKpNJWQ/EuGNuLM3WZT1gimH6NKh2ibrJH2iCFJMov0xk6rby3YhtbTb6OG4eDdZqFdkFfMl
CW8BNPZwjsZWnSGsJHkaitMUuRFza+wfqUdlNWecEk0doJTgqg2HzLeNr6CAyoyRp8ZQwaSUzEUjKQ8l
53BOjcbsS9ThKEcz6RHC2NI8oMMc7znq5IMDftK7pkEoWxPqP1goXzJ7NgxkAAAAAElFTkSuQmCC
""")  

ICON_CLOSING_1 = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAhlJREFUOE9VVNtx
20AMBO6cflyCanAbSX6UPuwfuw23YKeD9OPhIbMPkGeNRiKPILCLXSAzsvCt4FX0dfiTURGVUXzIx1GZ
gePkQURVBY4Ql5lZCmVKP2QUo5EI57jXCd/UG6l73jne965IpEJxrHVWJTpWryj/Zw4hbpjNSKmuz1HL
SCP+vH00DEYBES5eft7Ol+YYpo2CKADEDq4FBBX3t7+mJaqkcTEV6Yx4/nUjkpGDycgOUoDSWtQm7q+f
TCY0/EHEKRHb2Qg6aVWMMRl9Jqyj4v76QWmeHh+cC0Uy3v99scDT4w+hQ4HUOZ4//74RJQ2DXzSbCJHe
ekt1WUR2spB9Luz8XeuIOSeRUzpQWvSSEyrubMp5I2BK2XaIVMIxth6SxooBhegt3PuC/TIaPXBWMUD0
qiNGzrYR8EndbwltYUoA71koW1IWZ/KI41gx5rgmBQhYZXQfGoimQCrbX+Ss9mhA1P85qbF8CPC1joD7
v41Wj4JF6RkgSrWfR5iqMUFZM82EaOwYMCgrkAqboamX0j2/XBatWsQ61qUylwMpr5imodBrdlXZlNtY
m2iyXPuwl8USfMVdS0IO6XW17yXPtoWZp8pE6BW1Wa/bRrN2z/YtwoV4rTktSCqASbFP289emF3msl6/
ZDa9DXcWao0Xaf/3WPU04NwLyxqpDVb5FNILWIJts3ltEy9Wz+G+wsxNM75tpP9XPWgyHdvS5AAAAABJ
RU5ErkJggg==
""")

ICON_CLOSING_2= base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAihJREFUOE9VVN1Z
5DAMlBL64ToASuAog9sXtg7gZSkDroTb6wDq2S8W3/woCXmIHceWZkZjZUZWZERVYIjCy08WvvniSkZF
YfRGfnHeZzMyM6p4oPSBcTuqWf9nVGTHuFvnEqE5BjaW83f2MXiukWmC7Ao258yRRxmsSEQIjRv/l9Ff
Ece3M+Az0Ma84uXxzpkc2GFBnFs7zxiaHU//TBzZjRPZCaE1rXg+3JLZNE0SUiS4w8gqnt7+GxXzaRtF
t7rQrilGxuvhln8oAQMmd8QYi4JFxcOvKwYpF+Dv14U1vr+Gbk6QGe+fF6J+OdzElEAJCLRNxVgqnk5n
WWIth4slEut2FtAFwerr403kNJOFapooxojj6cwsv4mQ5WTlPj6F8OH6ioF4qDI+vi6cP/+5i5mWc1GA
aamhRetuv4j65vXN/PYmrbSMmOaJIFaEoDxNDmgEEmTzmhxHsEQI+fGMMUx5rTIoL8wiuXqzKvDzpqwG
kQcqyY7W0U1JerfGwiyOKBgSa8++L/LOUkhohKC82QZZ7Lv1yqmaMrSCd/j2JdZBeaa5dVco71iQBbOf
7caO2XWVrYFIy4rCdZ3hwe42SD4A3eHk9faw/Cc1iVZ3RV3NfYoIdQYIWQiHoM9cDLckcbF/eHs2j6rQ
nULK2wsedpTdaHS3Ow1Rdddsg25ddEXIPPaVGkrj3LmalLtlm9WuxcOXu67fOglBC7jDJh3V/1cBu4St
7zd1ulwygKPQgAAAAABJRU5ErkJggg==
""")

ICON_CLOSING_3 = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAkFJREFUOE9VVN15
IjEMlGxST44KQlogZRw8hNQB9xBSRmghXAWhn8PWfZqR7M2+rNer35mRVFXNxB8TNcVbNN7+Q0UM93zU
/+MQNnTNn6KwcAf4GOPxg8HSGvd5p6I0Dct5YkB6LlJ5VZ1BTcXcO5wtbGspP+7TW9EyumQt1vxt6Oj1
fEWYLJ7ti5z2T4RHTYpW2kdKVJgItc4+3s5XtoO+iBrPA0ocT/sN7kqpCO7BNNFo5qSIvH5coyJCO+CI
MklFQKQmf3bPqBoQIDF6NfGAb+cv/HxZPwSedLzc/ompyvZxRQ4DiM/bHdAcdxspBfXhGwl7Nzm8f4Uw
yBO4gDxSARHO+1ogd/r9JLVUikXDppsHdBJMtusVsAsNyeX7jqq2v1aDJK/zcmsIfNw9Sy1+AoFAU6w3
Obz/DSFnhaFPczwd7eAzyKK3yclbrjXQhcxUeu9y+HAMVbZr/+nG1ODluyHRy6Pfz2Yvtzu+j/sNKvSu
xqR061JKmfKHOJPlGMe4gnqiOj+4r4YvSPF2rHdRLWQix3XMzmKWKYpAiwbdmqi6FpMUEWmtBw7BLnvm
eC9GfQ5oTK37dpNaNRI5UuoBm9RKcQILlJ6K86ufkzJXiEFypXoXVCJi9N5GKWQzcQpBgqDEgLPOanlw
YQ9SRvLFimM8BuPyyOGJjeij6thHF1DfmIfEKNSfMuOuzQWxYMpT5T5EoqnTub4IXciGQcbQRfZcS9Tn
nMi54AEAcw1hjKBzVZFpVpWG7DSqBokOjcp/9wlXL048qUQAAAAASUVORK5CYII=
""")

ICON_CLOSING_4 = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAlJJREFUOE9VVdtB
IkEQ7J7FeA4jkAtBDEP8OIhD+QDDkAtBiACNR2fmrqq6B9wfdmf6WV3VuLl349MNb93cXAfWHV943Pq4
6da7m/NCrvimp8MSAXl+7cwYl8DX94qEKOGhoBGSbl35L4e0bzUqw8/l1lCNdys+qcLrxDB18y7zTtte
mwp2s/XuyDZg4HzR+cvjIspHmwrMuhGNZuHVeqMHAslioDH6B8KBgL2sFLh4CUyjQrTQqrBY799jJK7u
Bl4EnIPiBdt12z4umHaaJutdI+1AsfZmm92R2ZdztHGZ5OFc6bS8nQUTBMHh/GUdQVcLQYKWyQ43q7XZ
Zn8SPTzHpKryCX4RVGEmymyf7qyUEkU4MbfWum1278xyjwqjXziqErOHXzeccBLl8PHFIMBSOEbLOGy1
2fr1yJkzf1CFLWjMwbXUgSiMTM9PdzZh2ggYZLDauq33R4K9nN8M5iP43/M3q3q4nXEWSStUiDSo0Eth
DUyDl9ar/dmffqiDIkpv6TJ5MbDG4TNaRkBeB/61Ndu8noj//Xw2tI2cb5/fZB/PqWO1+vYJDM22q9/m
JVUfRGitWZkwqdR8UDi0K46lJlILwjV9Y4FEy62aT8JBvM3BBHUwrB/KZ/eEhMkwZbUsHgDDoS/CJeFS
aJEgBaKFcLUwzKwUiOFaTTkOjB77J9bk2JHBv7GmNC2tFXFL+1Bkj0qiXQRMKHMArDh34dBOSvrST/Dw
Ii82q80rQg+SC1chpKU37Ljtc6sPucfOQ8AoJh2p2fwzyN0VM9ddwPz/5R9sz1gzWfrEdgAAAABJRU5E
rkJggg==
""")

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
                desc = "Entity ID of the Garage Door in Home Assistant",
            ),
            schema.Text(
                id = "auth",
                name = "Bearer Token",
                icon = "key",
                desc = "Long-lived access token for Home Assistant",
            ),
        ],
    )

def get_entity_status(ha_server, entity_id, token):
    if ha_server == None:
        fail("Home Assistant server not configured")
    
    if entity_id == None:
        fail("Entity ID not configured")

    if token == None:
        fail("Bearer token not configured")
    
    state_res = None
    cache_key = "%s.%s" % (ha_server, entity_id)
    cached_res = cache.get(cache_key)
    if cached_res != None:
        state_res = json.decode(cached_res)
    else:
        rep = http.get("%s/api/states/%s" % (ha_server, entity_id), headers = {
            "Authorization": "Bearer %s" % token
        })
        if rep.status_code != 200:
            fail("HTTP request failed with status %d", rep.status_code)
        state_res = rep.json()
        cache.set(cache_key, rep.body(), ttl_seconds = 240)
    return state_res

def get_current_frame(image, status, friendly_name = None):
    return render.Box(
        render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [
                render.Row(
                    expanded = True,
                    main_align = "space_evenly",
                    cross_align = "center",
                    children = [
                        render.Image(src=image),
                        render.Text(status.capitalize()),
                    ],
                ),
                render.Text(
                    content = friendly_name,
                    font = 'tom-thumb',
                    color = '#cccccc'
                ) if friendly_name != None else None,
            ],
        ),
    )

def main(config):
    ha_server = config.get("homeassistant_server")
    entity_id = config.get("entity_id")
    token = config.get("auth")
    entity_status = get_entity_status(ha_server, entity_id, token)
    status = entity_status["state"]
    friendly_name = entity_status["attributes"]["friendly_name"] if "friendly_name" in entity_status["attributes"] else entity_id

    close_frames = [
        get_current_frame(ICON_CLOSING_1, status, friendly_name),
        get_current_frame(ICON_CLOSING_2, status, friendly_name),
        get_current_frame(ICON_CLOSING_3, status, friendly_name),
        get_current_frame(ICON_CLOSING_4, status, friendly_name),
        get_current_frame(ICON_CLOSED, status, friendly_name),
    ]
    
    # print(entity_status)
        
    if status == "open":         
        return render.Root(child = get_current_frame(ICON_OPEN, status, friendly_name))
    elif status == "closed":
        return render.Root(child = get_current_frame(ICON_CLOSED, status, friendly_name))
    elif status == "closing":
        return render.Root(          
            delay = 500,
            child = render.Box(render.Animation(close_frames)),
        )
    elif status == "opening":
        return render.Root(          
            delay = 500,
            child = render.Box(render.Animation(reversed(close_frames))),
        )