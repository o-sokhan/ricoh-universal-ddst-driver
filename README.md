# Ricoh DDST printer driver for macOS

CUPS driver for Ricoh SP 100/111/150/200/210/230/310-series GDI printers on
macOS 12 and later (Apple Silicon and Intel). These printers support neither
AirPrint nor PCL/PostScript, and Ricoh no longer ships current macOS drivers.

This is a macOS-focused fork of
[ankitsingh99/ricoh-universal-ddst-driver](https://github.com/ankitsingh99/ricoh-universal-ddst-driver).
The print filters are upstream's; the differences are:

- **Files only.** Installing copies three filters to `/Library/Printers/Ricoh/Filter`
  and PPDs to `/Library/Printers/PPDs`. Nothing is shared on the network, no
  services are started, and no quarantine flags are removed.
- **No Homebrew.** JBIG compression (jbigkit 2.1) is compiled in, so the filters
  link only against the system CUPS libraries. They are universal binaries.
- **Signed package.** CI builds a `.pkg`, signed and notarized when signing
  secrets are configured.
- **Removed:** the web portal, the network/AirPrint sharing script, Docker and
  Linux/BSD packaging, and the multi-OS `setup.sh`.
- **Fixed:** the legacy SP 200 PPD no longer overwrites the SP 200 DDST PPD on
  install (both were named `ricoh-sp200.ppd`); it is now `ricoh-sp200-legacy.ppd`.

## Install

From a release (once one is published): open `ricoh-ddst-driver-<version>.pkg`.

From source (needs Xcode Command Line Tools):

```bash
make               # as your user, not with sudo
sudo make install
```

Then add the printer in **System Settings → Printers & Scanners → Add Printer**.
Under *Use*, choose **Select Software…** and pick the matching *Ricoh SP … DDST* entry.

Or from the command line (USB shown; for network use `socket://<printer-ip>:9100`):

```bash
lpinfo -v | grep -i ricoh
sudo lpadmin -p Ricoh_SP203 -E -v "<uri>" \
  -P /Library/Printers/PPDs/Contents/Resources/ricoh-sp200.ppd \
  -o printer-is-shared=false
```

`./detect_printer.sh` suggests the right PPD for a USB-connected printer.

## Models

| PPD | Models | Filter | Hardware-tested |
|---|---|---|---|
| `ricoh-sp200.ppd` | SP 200, 201, 202, 203, 204 | `rastertoricohddst` | SP 200 (upstream) |
| `ricoh-sp100.ppd` / `ricoh-sp111.ppd` | SP 100, 110–112 | `rastertoricohddst` | no |
| `ricoh-sp210.ppd` | SP 210–213, 220 | `rastertoricohddst` | no |
| `ricoh-sp230.ppd` | SP 230 | `rastertoricohddst` | no |
| `ricoh-sp310.ppd` | SP 310–330, 3710 | `rastertoricohddst` | no |
| `ricoh-sp150.ppd` | SP 150 | `rastertoricohlhpl` | no |
| `ricoh-sp200-legacy.ppd` | SP 200 (older JBIG stream) | `rastertoricohjbig` | SP 200 (upstream) |

Printing only; scanning on MFP models still needs Ricoh's ICA/TWAIN driver.
Paper sizes A5, A6, B5 (JIS) and Executive are new and not yet confirmed on hardware.

## Uninstall

```bash
sudo lpadmin -x Ricoh_SP203                          # remove the queue, if you added one
sudo make uninstall                                  # from a source checkout; or, after a .pkg install:
sudo rm -rf /Library/Printers/Ricoh/Filter           # not /Library/Printers/Ricoh: Ricoh's own drivers live there too
sudo rm /Library/Printers/PPDs/Contents/Resources/ricoh-sp*.ppd
sudo pkgutil --forget io.github.o-sokhan.ricoh-ddst-driver
```

## Troubleshooting

`tail -f /var/log/cups/error_log` while printing. A job that aborts with
`could not be encoded` ran out of memory; nothing partial is sent to the printer.

## Development

```bash
make test       # unit + integration tests, >= 95% line coverage (macOS or Linux)
make pkg        # dist/ricoh-ddst-driver-<version>.pkg (macOS)
```

Signing in CI uses these repository secrets: `APP_CERT_P12`, `INSTALLER_CERT_P12`
(base64 Developer ID Application / Installer certificates), `CERT_PASSWORD`,
`NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_PASSWORD` (app-specific password).
Without them CI produces an unsigned package.

## Licence

Driver code: MIT (see `LICENSE`). `jbig/` is jbigkit 2.1 by Markus Kuhn,
GPL-2.0-or-later (`jbig/jbig.c` includes Debian's CVE-2017-9937 patch;
`jbig/jbig85.c` carries upstream's LHPL protocol changes). Because the filters
are linked with jbigkit, distributed binaries are covered by the GPL.

Credits: reverse engineering by Aryan Kushwaha (funinkina) and Alexey (madlynx);
upstream driver by Ankit Kumar Singh (ankitsingh99). See `AUTHORS.md`.
