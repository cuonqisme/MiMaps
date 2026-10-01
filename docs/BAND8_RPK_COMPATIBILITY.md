# MiMaps and Xiaomi Smart Band on-device apps

## Verified boundary for Xiaomi Smart Band 8 standard

The device advertised as `Xiaomi Smart Band 8 3D99` is the standard Band 8,
not Band 8 Pro. Its authenticated FE95/FDAB protocol accepts notifications,
notification-icon uploads, and watchface data, but it does not expose a Xiaomi
Vela Quick App/RPK runtime or an RPK installer.

An ACK from FE95 only confirms receipt of the encrypted protocol frame. It does
not prove that the firmware rendered a notification. MiMaps therefore labels
this state as `Band đã ACK gói` and reports icon query/upload separately.

For the standard Band 8, MiMaps currently uses a normal Band notification plus
a dynamically uploaded notification icon. Physical testing on the paired Band
8 confirms that type-`50` uploads succeed at the firmware-requested 28, 44 and
80 pixel sizes. The firmware still renders those pixels only in the small app
icon slot of its fixed notification layout; an 80-pixel upload does not create
a full-screen navigation card. MiMaps uses short, revisioned keys under the
`com.mimaps` namespace so a stale or interrupted icon-cache entry cannot block
the firmware from requesting new pixels. The required order is notification,
Band package query, phone package reply, Band icon request, and type-`50`
pixel upload; an unsolicited upload request is not accepted by this firmware.

## Evidence from the paired device and Mi Fitness export

This conclusion is not based only on Notify's public feature list. The Mi
Fitness data exported from the test iPhone identifies this exact product as:

- product name: `Xiaomi Smart Band 8`
- model: `miwear.watch.m66gl`
- product id: `11817`
- screen: `192 x 490`

Its device capability list contains notification, notification action,
watchface, launcher, widget, media, health and other built-in features. It does
not contain `thirdparty_app`, `application`, Quick App, Vela or RPK support.
The words `application` and `third_app` elsewhere in the same archive belong to
the Mi Fitness/Zepp Life phone application descriptor, not to the Band 8 device
object.

The exported Mi Fitness directory contains zero `.rpk` packages and one Band 8
watchface `.bin`. That file begins with the Band watchface magic
`5A A5 34 12`; it is not an RPK archive. The reverse-engineered Xiaomi BLE
data-upload service likewise exposes only these payload classes for this
protocol:

- `16`: watchface
- `32`: firmware
- `50`: notification icon

There is no RPK/application upload type or install command in the Band 8 FE95
command schema. A watchface format may contain an object named `App` or an
interactive action, but that is still a `.bin` watchface object. It does not
provide the Xiaomi Vela JavaScript runtime or accept a `.rpk` package.

## Why MiMaps does not push an RPK to this device

- Notify's native **Notify Maps** RPK page lists Mi Band 9/10 and devices that
  support third-party RPK installation. Its separate Band 8 guide documents
  picture mode instead.
- Xiaomi's Vela device tables list Band 8 Pro and Band 9/10, but not the
  standard Band 8.
- Xiaomi's official real-device RPK procedure requires a development build of
  Mi Fitness and matching phone/RPK certificates. The public procedure is not
  a raw FE95 file upload.
- The public Xiaomi BLE command implementation used for cross-checking exposes
  watchface, firmware and notification-icon uploads, but no RPK installer.
- Community Vela tooling targets Band 8 **Pro** and newer Vela bands. Separate
  standard Band 8 firmware research reaches custom code only by replacing the
  firmware through physical SWD flashing.
- Sending an RPK through the watchface or firmware upload type would be an
  invalid package operation and can leave the device unusable. MiMaps refuses
  to do this.

References:

- <https://www.mibandnotify.com/tutorial/mi-band-8/notifications/google-maps--2015.html>
- <https://www.mibandnotify.com/xiaomi-mi-band/notify-maps.php>
- <https://iot.mi.com/vela/quickapp/en/guide/multi-screens/>
- <https://iot.mi.com/vela/quickapp/en/guide/other/faq.html>
- <https://iot.mi.com/vela/quickapp/en/features/network/interconnect.html>
- <https://github.com/oryonatan/xiaomi-band-development>
- <https://github.com/atc1441/ATCmiBand8fw>
- <https://gist.github.com/Doliman100/c4d22766c4288ad0e025fb3eba066289>

## Supported implementation tracks

1. **Band 8 standard:** authenticated FE95 notifications and
   notification-icon upload. MiMaps proactively refreshes the maneuver icon,
   uploads the pixels requested by the Band, then sends the live distance and
   street text. The optional realtime mode reuses one notification identifier
   and refreshes its distance at most every two seconds, avoiding a growing
   stack of navigation cards. The pixel channel uses 244-byte
   `writeWithoutResponse` frames with CoreBluetooth backpressure and selective
   retransmission when the Band reports missing frames. This path is realtime,
   but the firmware confines the pixels to the notification's app-icon slot.
   Notify's public Band 8 documentation also advertises picture mode and screen
   mirroring; reproducing its full-screen result requires a separate temporary
   watchface/image workflow, not a larger type-`50` notification icon.
2. **Band 8 Pro / Band 9 / Band 10:** a Vela RPK can be developed and tested in
   Xiaomi AIoT-IDE, but physical installation and phone interconnect require
   Xiaomi's supported signing and Mi Fitness development channel.
3. **iPhone-only operation:** MiMaps can keep using direct authenticated BLE for
   the standard Band 8. Xiaomi's documented RPK interconnect path targets the
   paired mobile application and matching certificates; it is not exposed as a
   general iOS CoreBluetooth channel.

## Why an interactive `.bin` watchface is not a realtime miniapp

Band 8 watchface containers can include bitmaps, image lists, widgets, action
buttons and an object named `App`. Those objects are interpreted by the fixed
watchface engine and can bind to built-in sources such as time, steps, heart
rate, weather and battery. The standard Band 8 format does not embed the Vela
JavaScript/Lua runtime used by newer models, and the authenticated BLE schema
does not expose a command for updating arbitrary watchface text or bitmaps on
every GPS tick.

A custom watchface can therefore imitate a navigation screen, but it cannot
safely receive arbitrary live street names, distance and maneuver images from
MiMaps through the notification command on stock firmware. A phone can instead
render a complete 192×490 card and repeatedly install it as a temporary
watchface (upload type `16`), which is the leading explanation for Notify's
Band 8 picture/screen-mirroring mode. This is technically different from a
miniapp and must be treated as experimental: a complete face is much larger
than an icon, refreshes are slower, and aggressive updates may cost battery and
flash lifetime. MiMaps will only enable that path after it can build a valid
Band 8 `.bin`, verify its product metadata, and preserve/restore the user's
active watchface. Replacing the firmware through SWD could add a runtime, but
requires opening the device; MiMaps deliberately does not attempt it.

This conclusion also matches Gadgetbridge's current standard Band 8 installer:
its Xiaomi firmware helper recognizes the `5A A5` watchface container and the
Xiaomi upload service identifies type `16` as a watchface. It does not parse an
RPK as an installable package for this model. Gadgetbridge's notification path
does, however, implement the same package-query, icon-request and type-`50`
pixel-upload handshake used by MiMaps picture mode.

References:

- [Gadgetbridge Xiaomi notification service](https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/xiaomi/services/XiaomiNotificationService.java)
- [Gadgetbridge Xiaomi firmware/watchface parser](https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/devices/xiaomi/XiaomiFWHelper.java)
- [Gadgetbridge Xiaomi data upload service](https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/xiaomi/services/XiaomiDataUploadService.java)
