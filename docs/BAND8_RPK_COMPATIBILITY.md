# MiMaps and Xiaomi Smart Band on-device apps

## Verified boundary for Xiaomi Smart Band 8 standard

The device advertised as `Xiaomi Smart Band 8 3D99` is the standard Band 8,
not Band 8 Pro. Its authenticated FE95/FDAB protocol accepts notifications,
notification-icon uploads, and watchface data, but it does not expose a Xiaomi
Vela Quick App/RPK runtime or an RPK installer.

An ACK from FE95 only confirms receipt of the encrypted protocol frame. It does
not prove that the firmware rendered a notification. MiMaps therefore labels
this state as `Band đã ACK gói` and reports icon query/upload separately.

For the standard Band 8, MiMaps uses the same class of mechanism documented by
Notify as **picture mode**: a normal Band notification plus a dynamically
uploaded notification icon. The package identifier must remain `com.mimaps`;
physical testing showed that direction-specific aliases were ACKed and then
silently ignored by the Band notification service.

## Why MiMaps does not push an RPK to this device

- Notify's native **Notify Maps** RPK page lists Mi Band 9/10 and devices that
  support third-party RPK installation. Its separate Band 8 guide documents
  picture mode instead.
- Xiaomi's Vela device tables list Band 8 Pro and Band 9/10, but not the
  standard Band 8.
- Xiaomi's official real-device RPK procedure requires a development build of
  Mi Fitness and matching phone/RPK certificates. The public procedure is not
  a raw FE95 file upload.
- Sending an RPK through the watchface or firmware upload type would be an
  invalid package operation and can leave the device unusable. MiMaps refuses
  to do this.

References:

- <https://www.mibandnotify.com/tutorial/mi-band-8/notifications/google-maps--2015.html>
- <https://www.mibandnotify.com/xiaomi-mi-band/notify-maps.php>
- <https://iot.mi.com/vela/quickapp/en/guide/multi-screens/>
- <https://iot.mi.com/vela/quickapp/en/guide/other/faq.html>

## Supported implementation tracks

1. **Band 8 standard:** authenticated FE95 picture-mode notifications and
   notification-icon upload; a validated `.bin` watchface may be added later.
2. **Band 8 Pro / Band 9 / Band 10:** a Vela RPK can be developed and tested in
   Xiaomi AIoT-IDE, but physical installation and phone interconnect require
   Xiaomi's supported signing and Mi Fitness development channel.
3. **iPhone-only operation:** MiMaps can keep using direct authenticated BLE for
   the standard Band 8. Xiaomi's documented RPK interconnect path targets the
   paired mobile application and matching certificates; it is not exposed as a
   general iOS CoreBluetooth channel.
