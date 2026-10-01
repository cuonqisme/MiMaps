# Band 8 full-screen navigation

## What version 17 proved

The paired standard Xiaomi Smart Band 8 successfully completed the complete
notification-icon handshake and accepted all pixel payloads requested by its
firmware:

| Requested size | ARGB8888 payload | Result |
| --- | ---: | --- |
| 28×28 | 3,136 bytes | uploaded |
| 44×44 | 7,744 bytes | uploaded |
| 80×80 | 25,600 bytes | uploaded |

The physical screen still showed the arrow in the small application-icon slot.
This is expected: Xiaomi data-upload type `50` supplies an application icon;
the Band firmware owns the surrounding notification layout. Increasing the
uploaded bitmap does not increase that slot.

Version 18 also treats the later 44/80-pixel requests as cache population. It
does not restart picture mode or send duplicate navigation notifications after
the first successful upload.

## Can MiMaps show the large arrow?

Yes, as an experimental temporary **watchface**, not as a notification icon and
not as an RPK. The target card already rendered by `MiBandNavigationCardRenderer`
matches the Band 8 screen resolution of 192×490.

The safe implementation sequence is:

1. Render maneuver, distance, road, remaining time and remaining distance into
   one 192×490 image on the iPhone.
2. Pack that image into a valid standard Band 8 watchface `.bin` whose header,
   product metadata, resource table and checksums are verified.
3. Ask the Band to install the face with command type `4`, subtype `4`.
4. Transfer the package with Xiaomi data-upload type `16`.
5. Activate the installed navigation face only after the Band confirms install.
6. Preserve the previously active face and restore it when navigation stops.

MiMaps must not send a PNG directly as type `16`, and it must not send an RPK or
firmware payload. Those are different container formats and an invalid install
can disrupt the wearable.

## Realtime limits

A type-`50` icon is only a few to tens of kilobytes and is appropriate for live
turn changes. A complete watchface package is hundreds of kilobytes in the
captured Mi Fitness data. Reinstalling it every GPS update would therefore be
slower and would increase battery use and flash writes.

The full-screen experiment should consequently coalesce updates and refresh
only when one of these materially changes:

- maneuver;
- rounded distance bucket;
- road name;
- remaining-time minute.

The normal notification path remains the realtime fallback until watchface
packing, install acknowledgement, activation and restoration have all passed
physical-device tests.

## Evidence and references

- Notify documents a Band 8 "picture mode" that displays the next direction
  icon and information, and separately documents phone-screen mirroring by
  repeatedly uploading a screen image.
- EasyFace documents standard Band 8 watchfaces at 192×490 and can compile the
  corresponding Xiaomi watchface format.
- Gadgetbridge identifies Xiaomi upload type `16` as watchface and type `50` as
  notification icon, and performs a separate install/activate command around a
  watchface upload.

References:

- <https://www.mibandnotify.com/tutorial/mi-band-8/notifications/google-maps--2015.html>
- <https://www.mibandnotify.com/tutorial/mi-band-8/tools/phone-screen-mirroring-notify--2033.html>
- <https://github.com/m0tral/EasyFace/wiki/ResolutionListIT>
- <https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/xiaomi/services/XiaomiWatchfaceService.java>
- <https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/xiaomi/services/XiaomiDataUploadService.java>
