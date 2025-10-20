# Myrcli

Displays the 24-hour weather forecast for your location.

Make sure Wi-Fi is turned on.

## Usage

```sh
myrcli
myrcli --help
myrcli --version
```

## Output

```
Weather forecast (next 24 hours):
22:00    1°C  🌫️  Wind: 0.4 m/s
23:00    1°C  🌫️  Wind: 0.4 m/s
00:00    1°C  🌫️  Wind: 0.5 m/s
01:00    2°C  🌫️  Wind: 0.4 m/s
...
```

Weather data from [Met.no](https://api.met.no/)

## Build

Using make (recommended):

```sh
make build
make install  # requires sudo
```

Or manually:

```sh
swift build -c release
mkdir -p myrcli.app/Contents/MacOS/
cp ./.build/release/myrcli myrcli.app/Contents/MacOS/
cp Info.plist myrcli.app/Contents
codesign --force --deep --sign - myrcli.app
sudo cp ./myrcli.app/Contents/MacOS/myrcli /usr/local/bin/myrcli
```

Run `make help` to see all available targets.

## macOS Permissions

The first time you run myrcli, macOS will ask for location permission. You need to approve this for the app to work.

If Gatekeeper blocks the app, go to System Settings → Privacy & Security → General and approve it.
