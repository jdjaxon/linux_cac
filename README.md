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
Ubuntu 22.04, Firefox will only work if you allow the script to remove the `snap`
version and reinstall the browser with `apt`.

| Distribution | Versions  |    Browsers     |
|    :-:       |    :-:    |       :-:       |
| Ubuntu       | 20.04 LTS | Firefox, Chrome |
|              | 22.04 LTS | Firefox, Chrome |
| PopOS!       | 20.04 LTS | Firefox, Chrome |
|              | 22.04 LTS | Firefox, Chrome |
| Mint         | 21.2      | Firefox, Chrome |



There are reports of this script also working with both Linux Mint and the Brave
browser, but I have not tested these configurations.


## Installation
**WARNING:** Please make sure all browsers are closed before running the script.

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

## Known Issues
- Firefox and Chrome both need to be started at least once to initialize their
  respective certificate databases/profiles.

- CAC needs to be inserted before starting Firefox.

- Ubuntu 21.10 and greater (to include the latest LTS 22.04) have Firefox
  installed via snap by default. There is an outstanding bug
  (https://bugzilla.mozilla.org/show_bug.cgi?id=1734371) that prevents Firefox
  from being able to read the certificates. One solution could be to uninstall
  Firefox from snap and reinstall it via `apt`. This current version of the
  script will attempt to do this reinstallation for you.

- If you upgraded from 20.04 to 22.04 on either PopOS or Ubuntu, this likely
  also upgraded the cackey package from 7.5 to the latest version, which
  currently breaks this process. You can simply remove cackey and rerun the
  script to resolve this.

- If you run into any issues with firefox after running the script, clear your
  data and history in `Privacy & Security` and then restart firefox. If your
  troubles are with MS Teams, see the section for [troubleshooting
  teams](#microsoft-teams). Chrome is recommended for MS Teams since Firefox
  does not currently support Teams meetings. You can see more about this
  [here](https://support.microsoft.com/en-us/office/join-a-teams-meeting-on-an-unsupported-browser-daafdd3c-ac7a-4855-871b-9113bad15907).

- Firefox will likely start up a bit slower after running this installation.


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
