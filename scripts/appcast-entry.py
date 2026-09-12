#!/usr/bin/env python3
"""Insert a new <item> into appcast.xml, built from a CHANGELOG section.

Sparkle renders a <description> CDATA block as HTML, so the markdown from
CHANGELOG.md has to be converted first — raw "### Fixed" and "**bold**" would
otherwise show literally in the update dialog.

Everything is passed through the environment so release.sh does not have to
quote a multi-line changelog through an argument list:

    APPCAST  NOTES  VERSION  BUILD_NUMBER  PUB_DATE  REPO_SLUG  TAG
    ED_SIGNATURE  LENGTH  [PRINT_ENTRY]
"""

import html
import io
import os
import re
import sys
import xml.dom.minidom


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", text)
    return text


def to_html(markdown):
    out, in_list = [], False
    for raw in markdown.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("### "):
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append("<h3>%s</h3>" % inline(line[4:]))
        elif line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append("<li>%s</li>" % inline(line[2:]))
        else:
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append("<p>%s</p>" % inline(line))
    if in_list:
        out.append("</ul>")
    return out


def main():
    env = os.environ
    body = "\n".join("          " + line for line in to_html(env["NOTES"]))

    entry = """    <item>
      <title>Version {v}</title>
      <pubDate>{date}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{v}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
{body}
      ]]></description>
      <enclosure
        url="https://github.com/{repo}/releases/download/{tag}/Hum-{v}.dmg"
        sparkle:edSignature="{sig}"
        length="{length}"
        type="application/octet-stream"/>
    </item>
""".format(
        v=env["VERSION"],
        date=env["PUB_DATE"],
        build=env["BUILD_NUMBER"],
        body=body,
        repo=env["REPO_SLUG"],
        tag=env["TAG"],
        sig=env["ED_SIGNATURE"],
        length=env["LENGTH"],
    )

    target = env["APPCAST"]
    source = io.open(target, encoding="utf-8").read()

    if "<title>Version %s</title>" % env["VERSION"] in source:
        sys.exit("error: appcast.xml already has an entry for %s" % env["VERSION"])

    # Newest first: insert above whatever item currently leads the channel.
    anchor = re.search(r"[ \t]*<item>", source)
    if anchor is None:
        sys.exit("error: appcast.xml has no <item> to insert before")

    io.open(target, "w", encoding="utf-8").write(
        source[: anchor.start()] + entry + source[anchor.start():]
    )
    xml.dom.minidom.parse(target)  # refuse to hand back malformed XML

    print("   appcast entry inserted and well-formed")
    if env.get("PRINT_ENTRY"):
        print(entry.rstrip())


if __name__ == "__main__":
    main()
