# Linux CAC Configuration
A simple walkthrough for how to consistently configure DOD CACs on Linux. The
guide currently only covers Ubuntu and PopOS. I created the guide using
https://militarycac.com/linux.htm and trial and error.

## Table of Contents
<details>
<summary>
<b>Click to Expand</b>
</summary>

1. [Supported Distributions](#supported-distributions)
1. [Supported Browsers](#supported-browsers)
1. [Ubuntu and PopOS](#ubuntu-and-popos)
    1. [Automated Installation](#automated-installation)
    1. [Manual Installation](#manual-installation)
        1. [Staging](#staging)
        1. [Browser Configuration](#browser-configuration)
            1. [Google Chrome](#google-chrome)
            1. [Firefox](#firefox)
                1. [Microsoft Teams Troubleshooting](#microsoft-teams-troubleshooting)
1. [Known Issues](#known-issues)
1. [Resources](#resources)
</details>

## TODOs
- [ ] Script as much of the setup process as possible
    - [x] Find a way to automate the installation of DOD certificates in Firefox
- [ ] Fix links in the `Automated Installation` section once script is complete

## Supported Distributions
Regardless of how similar two distributions may be, I will only list
distributions and versions here that I know have been tested with this method.

| Distribution | Versions |
|:-:|:-:|
| Ubuntu | 20.04 |
| PopOS! | 21.04 |

## Supported Browsers
- Chrome
- Firefox

## Ubuntu and PopOS

### Automated Installation
This installation is a scripted version of the [manual installation](#manual-installation) you will find below.
This script requires root privileges since it installs the `cackey` package and its dependencies.
Feel free to review the script [here](https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh) if this makes you uncomfortable.
For transparency, the `cackey` package is downloaded from [here](https://cackey.rkeene.org/download/0.7.5/cackey_0.7.5-1_amd64.deb) and the DoD certificates are downloaded from [here](https://militarycac.com/maccerts/AllCerts.zip), both of which are recommended by [militarycac](https://militarycac.com).

**Important Notes:**
- The automated installation requires `wget` and `unzip` to run and will install both during the setup. If you don't want either tool, remove it after the setup is complete using `sudo apt remove <command>`.
- The scripted installation has only been tested on Ubuntu 20.04
- This script uses the 64-bit version of the cackey package.

**WARNING:** Please make sure all browsers are closed before running the script.

To run the setup script, use the following command:
| Method | Command |
|:-:|:-:|
| `wget`  | `sudo sh -c "$(wget https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh -O -)"` |
| `curl`  | `sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh)"` |
| `fetch` | `sudo sh -c "$(fetch -o https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh)"` |

**NOTE:** If you run into any issues with firefox after running the script, restart firefox. Firefox will start up a bit slower.


### Manual Installation
#### Staging
1. Run the following command to install the CAC middleware:
```
sudo apt install libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools
```
2. To verify that your CAC is detected, run (stop with ctrl+c):
```
pcsc_scan
```
3. Download and install cackey from [here](http://cackey.rkeene.org/fossil/wiki?name=Downloads).
4. Run the following command to verify the location of the cackey module and make note of the location:
```
find / -name libcackey.so 2>/dev/null
```
- **NOTE:** `libcackey.so` should be in one of the following locations:
```
/usr/lib/libcackey.so
        OR
/usr/lib64/libcackey.so
```
5. If `apt` updates cackey from 7.5 to 7.10, it will move `libcackey.so` to a different location.
To prevent cackey from updating, run the following:
```
sudo apt-mark hold cackey
```
- **NOTE**: The cackey package will still show as upgradeable.

6. Download DOD certs from DISA [here](https://militarycac.com/maccerts/AllCerts.zip).
7. Unzip the `AllCerts.zip` folder using the following command:
```
unzip AllCerts.zip -d AllCerts
```

#### Browser Configuration
---
##### Google Chrome
1. `cd` into the newly created `AllCerts` directory
2. Run the following command:
```
for cert in *.cer; do certutil -d sql:"$HOME/.pki/nssdb" -A -t TC -n "$cert" -i "$cert"; done
```
3. Run the following command:
```
printf "library=/usr/lib64/libcackey.so\nname=CAC Module" >> $HOME/.pki/nssdb/pkcs11.txt
```

##### Firefox
1. `cd` into the `AllCerts` directory
2. Run the following command:
```
for cert in *.cer; do certutil -d sql:"$(dirname "$(find "$HOME/.mozilla" -name "cert9.db")")" -A -t TC -n "$cert" -i "$cert"; done
```
3. Run the following command:
```
printf "library=/usr/lib64/libcackey.so\nname=CAC Module" >> "$(dirname "$(find "$HOME/.mozilla" -name "cert9.db")")/pkcs11.txt"
```
- **NOTE**: Since the firefox database directory starts with a random string of characters, it needs to be found dynamically. Its naming and location follows this convention: `$HOME/.mozilla/firefox/<alpahnumeric string>.default-release`.

###### Microsoft Teams Troubleshooting
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


## Known Issues
- CAC needs to be inserted before starting Firefox

## Resources
- https://militarycac.com/linux.htm (this was my starting point)
- https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/docs/linux/cert_management.md
- https://firefox-source-docs.mozilla.org/security/nss/legacy/tools/nss_tools_certutil/index.html
- https://firefox-source-docs.mozilla.org/security/nss/legacy/tools/certutil/index.html
- https://askubuntu.com/questions/244582/add-certificate-authorities-system-wide-on-firefox
- https://stackoverflow.com/questions/1435000/programmatically-install-certificate-into-mozilla
- https://docs.microsoft.com/en-us/microsoftteams/troubleshoot/teams-sign-in/sign-in-loop#mozilla-firefox
