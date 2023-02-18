load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")

IPIFY_JSON_URL = "https://api.ipify.org/?format=json"

def main(config):
	ip_cached = cache.get("ip")
	if ip_cached != None:
		ip = ip_cached
	else:
		rep = http.get(IPIFY_JSON_URL)
		if rep.status_code != 200:
			fail("HTTP request failed with status %d", rep.status_code)
		ip = rep.json()["ip"]
		cache.set("ip", ip, ttl_seconds=240)
	return render.Root(
		render.Box(
     		child = render.Column(
			expanded = True,
			main_align = "center",
			cross_align = "center",
			children = [
                render.Text(
                    color = config.get("color", "#72A5E8"),
                    content = config.get("label", "Public IP"),
                    font = "Dina_r400-6",
                ),
                render.Box(color = "#111", height = 1),
                render.Box(color = "#000", height = 1),
                render.Text(content = ip, font = "tom-thumb"),
                render.Box(color = "#111", height = 1),
			],
		)
	)
)
