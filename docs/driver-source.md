# Finding the matching driver

The P9X79 PRO product label is only part of the search. Its onboard Bluetooth radio identifies itself as `USB\VID_0B05&PID_179C`. That hardware ID also appears in the signed 64-bit INF of an ASUS-hosted Qualcomm Atheros package distributed under X542URV laptop support.

| Package detail | Value |
| --- | --- |
| Driver version | `10.0.3.22` |
| Driver INF date | `2019-09-03` |
| ASUS publication date | `2020-02-26` |
| Earlier driver used on the original system | `10.0.1.7`, dated `2016-05-18` |
| Hardware mapping | `USB\VID_0B05&PID_179C` → `QCABTUSB` |
| Architecture | `NTamd64` |
| Catalog | `btfilter.cat` |
| Catalog publisher | Microsoft Windows Hardware Compatibility Publisher |

Sources: [ASUS X542URV support](https://www.asus.com/supportonly/x542urv/helpdesk_download/), [ASUS driver archive](https://dlcdnets.asus.com/pub/ASUS/nb/DriversForWin10/Bluetooth/Bluetooth_QualcommAtheros_Win10_64_VER100322driver_only.zip.zip), [P9X79 PRO support](https://www.asus.com/supportonly/p9x79%20pro/helpdesk_download/).

The archive is identified by SHA-256:

```text
DE116BD82D2EB4D8FF2802FD4C0264EAF4E7EB61272FB054B4BFC81D05DCFDEA
```

The toolkit's [package manifest](../data/driver-package.json) records the required file hashes. Download reads the official ASUS archive; Review checks those files, the INF mapping, and its catalog signature before installation.

As of the November 7, 2026 source review, this is the newest matching ASUS-hosted package located. Other newer Qualcomm packages can target different hardware. The [Microsoft Catalog entry for this exact ASUS ID](https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=aa731da3-c759-4642-9432-4cde233876f8) is an older `10.0.3.12` package.

The ASUS files retain their original vendor licensing. This repository distributes scripts and metadata; it does not mirror the driver archive.
