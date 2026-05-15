import urllib.request, re

req = urllib.request.urlopen('https://www.haxball.com/play', timeout=10)
content = req.read().decode('utf-8', errors='ignore')
scripts = re.findall(r'src=["\']([^"\']+\.js[^"\']*)["\']', content)
print("JS files found:")
for s in scripts:
    print(s)
print("\nFull content snippet:")
print(content[:2000])
