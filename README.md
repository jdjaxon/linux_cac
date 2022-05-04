# Linux CAC Configuration

A project for consistently configuring DOD CACs on Linux. Currently, this
process will not work with Firefox if it is installed via `snap`. Before using
this project, please review the [Known Issues](#known-issues) section.


## Table of Contents

<details>
<summary>
<b>Click to Toggle Expansion</b>
</summary>

1. [Supported Configurations](#supported-configurations)
1. [Installation](#installation)
    1. [Automated Installation](#automated-installation)
        1. [Methods](#methods)
    1. [Manual Installation](#manual-installation)
        1. [Staging](#staging)
        1. [Browser Configuration](#browser-configuration)
            1. [Google Chrome](#google-chrome)
            1. [Firefox](#firefox)
1. [Known Issues](#known-issues)
1. [Troubleshooting](#troubleshooting)
    1. [Microsoft Teams](#microsoft-teams)
1. [Resources](#resources)

</details>


## Supported Configurations

Regardless of how similar two distributions may be, I will only list
distributions and versions here that I know have been tested with this method.

| Distribution | Versions  |    Browsers     |
|    :-:       |    :-:    |       :-:       |
| Ubuntu       | 20.04 LTS | Firefox, Chrome |
|              | 22.04 LTS | Chrome          |
| PopOS!       | 20.04 LTS | Firefox, Chrome |
|              | 22.04 LTS | Firefox, Chrome |


## Installation

Please run either the [Automated Installation](#automated-installation) or the
[Manual Installation](#manual-installation), but not both.


### Automated Installation

<details>
<summary>
<b>Click to Toggle Expansion</b>
</summary>

\
**WARNING:** Please make sure all browsers are closed before running the script.

If you choose this option, you do not need to do the
[manual installation](#manual-installation).

This script requires root privileges since it installs the `cackey` package and
its dependencies. Feel free to review the script
[here](https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh)
if this makes you uncomfortable. For transparency, the `cackey` package is
downloaded from
[here](https://cackey.rkeene.org/download/0.7.5/cackey_0.7.5-1_amd64.deb) and
the DoD certificates are downloaded from
[here](https://militarycac.com/maccerts/AllCerts.zip), both of which are
recommended by [militarycac](https://militarycac.com).

**Important Notes:**
- The automated installation requires `wget` and `unzip` to run and will
  install both during the setup, if they are not already installed. If you
  don't want either tool, remove it after the setup is complete using `sudo apt
  remove <command>`.
- The scripted installation has only been tested on the configurations listed in the
  [Supported Distributions](#supported-distributions)
- This script uses the 64-bit version of the cackey package.


#### Methods

- `wget`
```bash
sudo bash -c "$(wget https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh -O -)"
```

- `curl`
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh)"
```

- `fetch`
```bash
sudo bash -c "$(fetch -o https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh)"
```

</details>

---


### Manual Installation

<details>
<summary>
<b>Click to Toggle Expansion</b>
</summary>

\
**WARNING:** Only perform these steps if you have ***not*** done the [automated installation](#automated-installation).

#### Staging

1. Run the following command to install the CAC middleware:
```bash
sudo apt install libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools libnss3-tools
```

2. To verify that your CAC is detected, run (stop with ctrl+c):
```bash
pcsc_scan
```
3. Download and install cackey from [here](http://cackey.rkeene.org/fossil/wiki?name=Downloads).

4. Run the following command to verify the location of the cackey module and make note of the location:
```bash
find / -name libcackey.so 2>/dev/null
```
- **NOTE:** `libcackey.so` should be in one of the following locations:
```bash
/usr/lib/libcackey.so
        OR
/usr/lib64/libcackey.so
```

5. If `apt` updates cackey from 7.5 to 7.10, it will move `libcackey.so` to a
   different location.
To prevent cackey from updating, run the following:
```bash
sudo apt-mark hold cackey
```

- **NOTE**: The cackey package will still show as upgradeable.

6. Download DOD certs from DISA [here](https://militarycac.com/maccerts/AllCerts.zip).

7. Unzip the `AllCerts.zip` folder using the following command:
```bash
unzip AllCerts.zip -d AllCerts
```

#### Browser Configuration

---

##### Google Chrome

1. `cd` into the newly created `AllCerts` directory
2. Run the following command:
```bash
for cert in *.cer; do certutil -d sql:"$HOME/.pki/nssdb" -A -t TC -n "$cert" -i "$cert"; done
```
3. Run the following command:
```bash
printf "library=/usr/lib64/libcackey.so\nname=CAC Module" >> $HOME/.pki/nssdb/pkcs11.txt
```

##### Firefox

1. `cd` into the `AllCerts` directory
2. Run the following command:
```bash
for cert in *.cer; do certutil -d sql:"$(dirname "$(find "$HOME/.mozilla" -name "cert9.db")")" -A -t TC -n "$cert" -i "$cert"; done
```
3. Run the following command:
```bash
printf "library=/usr/lib64/libcackey.so\nname=CAC Module" >> "$(dirname "$(find "$HOME/.mozilla" -name "cert9.db")")/pkcs11.txt"
```

- **NOTE**: Since the firefox database directory starts with a random string of
  characters, it needs to be found dynamically. Its naming and location follows
  this convention: `$HOME/.mozilla/firefox/<alpahnumeric
  string>.default-release`.

</details>


## Known Issues

- Firefox and Chrome both need to be started at least once to initialize their
  respective certificate databases/profiles.

- CAC needs to be inserted before starting Firefox.

- Ubuntu 21.10 and greater (to include the latest LTS 22.04) have Firefox
  installed via snap by default. There is an outstanding bug
  (https://bugzilla.mozilla.org/show_bug.cgi?id=1734371) that prevents Firefox
  from being able to read the certificates. One solution could be to uninstall
  Firefox from snap and reinstall it via `apt`.

- If you run into any issues with firefox after running the script,
clear your data and history in `Privacy & Security` and then restart firefox.

- Firefox will likely start up a bit slower after running this installation.

- If you upgraded from 20.04 to 22.04 on either PopOS or Ubuntu, this likely
  also upgraded the cackey package from 7.5 to the latest version, which
  currently breaks this process. You can either rerun the script or run through
  step three through five of the [manual installation](#manual-installation).


## Troubleshooting

### Microsoft Teams

If you run into issues with MS Teams, try the following steps:
1. In the Firefox Settings window, select the `Privacy & Security` tab.
2. Under `Cookies and Site Data`, select `Manage Exceptions`.
3. In the `Address of website` text box, enter the following URLs, and then select `Allow`.
```
    https://microsoft.com
    https://microsoftonline.com
    https://teams.skype.com
    https://teams.microsoft.com
    https://sfbassets.com
    https://skypeforbusiness.com
```
4. Select `Save Changes`.

- **NOTE:** `strict` security settings in Firefox may cause a loading loop

See the official documentation for this issue
[here](https://docs.microsoft.com/en-us/microsoftteams/troubleshoot/teams-sign-in/sign-in-loop#mozilla-firefox).


## Resources

- https://militarycac.com/linux.htm (this was my starting point)
- https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/docs/linux/cert_management.md
- https://firefox-source-docs.mozilla.org/security/nss/legacy/tools/nss_tools_certutil/index.html
- https://firefox-source-docs.mozilla.org/security/nss/legacy/tools/certutil/index.html
- https://askubuntu.com/questions/244582/add-certificate-authorities-system-wide-on-firefox
- https://stackoverflow.com/questions/1435000/programmatically-install-certificate-into-mozilla
- https://docs.microsoft.com/en-us/microsoftteams/troubleshoot/teams-sign-in/sign-in-loop#mozilla-firefox
