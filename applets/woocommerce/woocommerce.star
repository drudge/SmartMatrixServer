load("render.star", "render")
load("encoding/base64.star", "base64")
load("http.star", "http")
load("math.star", "math")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_REST_API_HOST = ""
DEFAULT_REST_API_CONSUMER_KEY = "ck_"
DEFAULT_REST_API_CONSUMER_SECRET = "cs_"
DEFAULT_SHOW_SITE_ICON = True
DEFAULT_TIMEZONE = "America/New_York"
DEFAULT_COMPARE_TO_DURATION = "8766h"

UP_ARROW = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAc0lEQVQY02NgQAJSZ3y5pO7Ev7I8FsrJ
gA0o3E/gkL4b/x2I/4No7auhbCgKVG57skvfifsJVQDBQD5Cxf8GJuk78ceB1pyVuht3E6Ig/haIL303
7gTDqlBmDGtBihj+MzAy4ANgRYQAVBERJu13YCHZOgDLJDrjAL8LyAAAAABJRU5ErkJggg==
""")

DOWN_ARROW = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAWklEQVQYGXXBywnCQABAwVlZDxER+2/G
PuKnlafeQiAztmJGMRyJSxRXR+IcxeJI3KNYbMWMESMuUdz8xBJTnGKNoiiKYo3pL0a8oiiKp70Y8Yni
HdOReNj5AhvkPSjlOa7aAAAAAElFTkSuQmCC
""")

def commaize(number):
    text = str(number)
    parts = text.split(".")
    ret = ""

    if len(parts) > 1:
        ret = "."
        ret += parts[1]
    
    for i in range(len(parts[0]) - 1,-1,-1):
        if (len(parts[0]) - i - 1) % 3 == 0 and i != len(parts[0]) - 1:
            ret = "," + ret
        ret = parts[0][i] + ret
    
    return ret

def SiteLogo(image_url = None):
    if image_url != None:
        res =  http.get(image_url)

        if res.status_code == 200:
            return render.Padding(
                pad = (1, 15, 0, 0),
                child = render.Image(
                    src = res.body(),
                    width = 16,
                    height = 16,
                )
            )
    
    return None

def Revenue(revenue, change = None, has_image = True, currency_symbol = "$"):    
    has_change = (change != None and change > 0)
    if has_change:
        change_color="#1bdd5f"
        change_image = UP_ARROW
        change_text = "Up"
    else:
        change_color="#ff0000"
        change_image = DOWN_ARROW
        change_text = "Down"

    change_text = "%s %s%%" % (change_text, change) if has_change else ""
    change_padding = 15 if has_image else 0
    revenue_padding = 0 if (has_image or has_change) else 5
    change_image = render.Padding(
        child = render.Image(src = UP_ARROW if change > 0 else DOWN_ARROW),
        pad = (0, 0, 1, 0)
    ) if has_change else None

    return render.Box(
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [
                  render.Padding(
                    pad = (0, revenue_padding, 0, 0),
                    child = render.Text(
                        content = "%s%s" % (currency_symbol, commaize(int(revenue))),
                        font="6x13",
                    ),
                ),
                render.Padding(
                    pad = (change_padding, 0, 0, 9),
                    child = render.Row(
                        main_align = "center",
                        cross_align = "center",
                        children = [
                            change_image,
                            render.Padding(
                                pad = (0, 1, 0, 0),
                                child = render.Text(
                                    content = change_text,
                                    font = "tom-thumb", 
                                    color = change_color,
                                )
                            ),
                        ]
                    )
                ),
            ],
        ),
    )

def get_revenue(host, consumer_key, consumer_secret, date_from = None, date_to = None):
    path = "/wp-json/wc/v3/reports/sales?total_sales"

    if date_from != None:
        path += "&date_min=%s" % date_from.format("2006-01-02")

    if date_to != None:
        path += "&date_max=%s" % date_to.format("2006-01-02")

    url = "%s%s" % (host, path)
    auth = base64.encode("%s:%s" % (consumer_key, consumer_secret))

    res = http.get(url, headers = {
        "Authorization": "Basic %s" % auth,
        "Content-Type": "application/json",
    })

    if res.status_code == 200:
        json = res.json()

        if len(json) > 0:
            return json[0]

    return None

def main(config):
    host = config.get("host", DEFAULT_REST_API_HOST)
    consumer_key = config.get("consumer_key", DEFAULT_REST_API_CONSUMER_KEY)
    consumer_secret = config.get("consumer_secret", DEFAULT_REST_API_CONSUMER_SECRET)
    show_site_icon = config.get("show_site_icon", DEFAULT_SHOW_SITE_ICON)
    compare_to_period = config.get("compare_to", DEFAULT_COMPARE_TO_DURATION)
    time_zone = config.get("$tz", DEFAULT_TIMEZONE)

    print("host: %s" % host)
    
    status_message = None
    todays_sales = None
    last_year_sales = None
    total_orders = 0
    change = None

    today = time.now().in_location(time_zone)
    last_year = today - time.parse_duration(compare_to_period)

    ty_revenue = get_revenue(
        host,
        consumer_key,
        consumer_secret,
        date_from = today,
        date_to = today,
    )
    updated_at = today.format("3:04 PM")

    if ty_revenue == None:
        return []

    todays_sales = float(ty_revenue["total_sales"])
    total_orders = int(ty_revenue["total_orders"])
    orders_str = "order%s" % ("s" if total_orders != 1 else "")
    status_message = "%s %s as of %s" % (commaize(total_orders), orders_str, updated_at)

    ly_revenue = get_revenue(
        host,
        consumer_key,
        consumer_secret,
        date_from = last_year,
        date_to = last_year,
    )

    if ly_revenue != None:
        last_year_sales = float(ly_revenue["total_sales"])
        if last_year_sales > 0:
            change = math.ceil(todays_sales / last_year_sales * 100 - 100)
    
    logo = SiteLogo("%s/favicon.ico" % host) if show_site_icon else None

    status_bar = render.Padding(
        pad = (0, 24, 0, 0),
        child = render.Box(
            height = 8,
            color = "#3c3c3c",
            child = render.Padding(
                pad = (0, 0, 0, 0),
                child = render.Marquee(
                    width = 59,
                    child = render.Text(
                        content = status_message,
                        color = "#eee",
                        font = "tom-thumb",
                    ),
                ),
            )
        )
    ) if status_message else None

    return render.Root(
        child = render.Stack(
            children = [
               Revenue(
                   revenue = todays_sales,
                   change = change,
                   has_image = logo != None,
                ),
               status_bar,
               logo,
            ],
        )
    )

def get_schema():
    compare_to_options = [
        schema.Option(
            display = "Yesterday",
            value = "24h",
        ),
        schema.Option(
            display = "Last Year",
            value = "8766h",
        ),
    ]
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "host",
                name = "REST API Host",
                desc = "WooCommerce Base URL",
                icon = "link",
                default = DEFAULT_REST_API_HOST,
            ),
            schema.Text(
                id = "consumer_key",
                name = "Consumer key",
                desc = "REST API Consumer key",
                icon = "key",
                default = DEFAULT_REST_API_CONSUMER_KEY,
            ),
            schema.Text(
                id = "consumer_secret",
                name = "Consumer secret",
                desc = "REST API Consumer secret",
                icon = "password",
                default = DEFAULT_REST_API_CONSUMER_SECRET,
            ),
            schema.Toggle(
                id = "show_site_icon",
                name = "Show Site Icon",
                desc = "Show favicon of the site",
                icon = "image",
                default = DEFAULT_SHOW_SITE_ICON,
            ),
            schema.Dropdown(
                id = "compare_to",
                name = "Compare to",
                desc = "Period to use for comparison",
                icon = "chartLine",
                default = compare_to_options[1].value,
                options = compare_to_options,
            ),
        ],
    )