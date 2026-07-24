# Windows Logic Extraction

Inspected attachment:

- `Tivan-ONT-Bootstrapper-v1.0.5(3).exe`
- SHA-256: `c004decf5d28ca7bfd336848cd4ee8e58cd000585c3b5e7e986c110fe02ccc7e`
- Type: Windows PE x86-64, Go binary.

The EXE was not executed. The logic was inferred from embedded Go symbols and strings.

## Important Go symbols found

- `main.automateLogin`
- `main.configureWAN`
- `main.configureACS`
- `main.deleteExistingTargetWANs`
- `main.provisionONT`
- `main.telnetClient`
- `main.configureAdapterForONT`
- `main.restoreAdapter`

## Windows-only stage removed for iOS

The Windows app contains network-adapter handling:

- Detect physical Ethernet adapter.
- Save current IPv4 settings.
- Assign temporary ONT-side IPv4.
- Restore adapter settings.

The iOS app does not include this stage because the iPhone version assumes layer-3 communication to the ONT already works.

## Huawei paths found

- `/index.asp`
- `/html/bbsp/wan/wan.asp`
- `/html/bbsp/layer3/layer3.asp`
- `/html/ssmp/tr069/tr069.asp`
- `/html/ssmp/telnet/telnet.asp`
- `/html/ssmp/ssh/ssh.asp`
- `/html/ssmp/stelnet/stelnet.asp`
- `/html/ssmp/remote/remote.asp`
- `/html/ssmp/remoteaccess/remoteaccess.asp`
- `/html/ssmp/security/remoteaccess.asp`
- `/html/bbsp/security/remoteaccess.asp`
- `/html/ssmp/servicecontrol/servicecontrol.asp`
- `/html/ssmp/servicecontrol/service.asp`

## WAN logic preserved

- Select Route WAN when available.
- Select exact PPPoE control, avoiding IPoE.
- Select service type `TR069_VOIP_INTERNET`.
- Enable VLAN.
- Set VLAN ID `800`.
- Fill real PPPoE username/password fields.
- Avoid DHCP Client ID and ACS connection-request fields.
- Check exact Huawei binding controls:
  - `IPv4BindLanList1...8` => `LAN1...LAN8`
  - `IPv4BindLanList9...16` => `SSID1...SSID8`
- Preserve default MTU unless blank, then use `1492`.
- Apply with `ButtonApply`.

## ACS logic preserved

- Enable CWMP/TR-069 when available.
- Set ACS URL.
- Set ACS username/password.
- Set Connection Request username/password.
- Enable periodic inform.
- Set inform interval `30`.
- Bind/select the management WAN when selector exists.
- Apply with `ButtonApply`.

## Telnet/default-config logic preserved

Commands:

```sh
cd /mnt/jffs2
cp -f hw_ctree.xml hw_default_ctree.xml
chmod 644 hw_default_ctree.xml
sync
cmp hw_ctree.xml hw_default_ctree.xml && echo TIVAN_CMP_OK || echo TIVAN_CMP_FAIL
md5sum hw_ctree.xml hw_default_ctree.xml
```

Default login assumptions:

- Telnet host: `192.168.100.1`
- Telnet port: `23`
- Username: `root`
- Password fallback: `adminHW`, then `admin`

