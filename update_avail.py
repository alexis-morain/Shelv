import re

with open("ShelvCore/AppIntents/ShelvPlatformAppIntents.swift", "r") as f:
    content = f.read()

# Add @available(iOS, unavailable) to all struct ...: ShelvPlatform...Intent
content = re.sub(
    r'(struct ShelvPlatform[A-Za-z]+Intent: ShelvPlatform(?:Playback|Navigation)Intent \{)',
    r'@available(iOS, unavailable)\n\1',
    content
)

# And for ShelvPlatformPlayableEntity etc
content = re.sub(
    r'(struct ShelvPlatform[A-Za-z]+Entity: AppEntity)',
    r'@available(iOS, unavailable)\n\1',
    content
)

with open("ShelvCore/AppIntents/ShelvPlatformAppIntents.swift", "w") as f:
    f.write(content)
