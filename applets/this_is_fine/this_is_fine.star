load("render.star", r = "render")
load("http.star", "http")

def main(config):
    return r.Root(
        child = r.Box(
            child = r.Image(
                src = http.get('https://emojis.slackmojis.com/emojis/images/1561763719/5906/this-is-fine-fire.gif').body(),
                width = 28,
                height = 27,
            ),
        ),
    )