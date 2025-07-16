<h1 align="center">Linux CAC</h1>

<p align='center'>
  <a href="https://github.com/sponsors/jdjaxon"><img alt="Sponsor" src="https://img.shields.io/badge/sponsor-30363D?style=flat&logo=GitHub-Sponsors&logoColor=#white" /></a>
  &nbsp;
  <a href="#"><img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/jdjaxon/linux_cac?style=flat&labelColor=30363D&color=gray" /></a>
  &nbsp;
  <a href="https://github.com/jdjaxon/linux_cac/actions/workflows/CI.yml"><img alt="CI" src="https://github.com/jdjaxon/linux_cac/actions/workflows/CI.yml/badge.svg?" /></a>
</p>

A project for consistently configuring Debian-based Linux distributions to work with
Common Access Cards (CACs). Currently, this process will not work with Firefox if it
is installed via `snap`. Before using this project, please review the
[Known Issues](#known-issues) section.

> [!note]
> This project has moved from using Cackey to OpenSC, which seems to be
> more stable. If you don't use Cackey as a dependency of anything else,
> I recommend running the following:
> ```
> sudo apt purge cackey
> ```

## Table of Contents
<details>
<summary>
<b>Click to Toggle Expansion</b>
</summary>

1. [Supported Configurations](#supported-configurations)
1. [Installation](#installation)
   1. [Methods](#methods)
1. [Known Issues](#known-issues)
1. [Troubleshooting](#troubleshooting)
    1. [Microsoft Teams](#microsoft-teams)
1. [License](#license)
1. [References](#references)

</details>


## Supported Configurations

Regardless of how similar two distributions may be, I will only list
distributions and versions here that I know have been tested with this method.
Since Ubuntu 22.04, Firefox will only work if you allow the script to remove the
`snap` version and reinstall the browser with `apt`.

| Distribution | Versions  | Browsers                  |
|    :-:       |    :-:    |       :-:                 |
| Debian       | 12.5      | Firefox ESR, Chrome, Edge |
| Mint         | 21.2      | Firefox, Chrome           |
| Parrot OS    | 6.0.0-2   | Firefox, Brave            |
| PopOS!       | 20.04 LTS | Firefox, Chrome           |
|              | 22.04 LTS | Firefox, Chrome           |
| Ubuntu       | 20.04 LTS | Firefox, Chrome           |
|              | 22.04 LTS | Firefox, Chrome           |

> [!note]
> There are reports of this script working with other distributions and
> browsers. I have not personally tested these configurations.


## Installation
> [!warning]
>  Please make sure all browsers are closed before running the script.

This script requires root privileges since it installs `opensc` package and
its dependencies. Feel free to review the script
[here](https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh)
if this makes you uncomfortable. For transparency, the
the DoD certificates are downloaded from
[here](https://militarycac.com/maccerts/AllCerts.zip), which are
recommended by [militarycac](https://militarycac.com).

> [!note]
> - The automated installation requires `wget` and `unzip` to run and will
>  install both during the setup if they are not already installed. If you don't
>  want either tool, remove it after the setup is complete using `sudo apt remove <command>`.
> - The scripted installation has only been tested on the configurations listed in the
>  [Supported Configurations](#supported-configurations)


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
- The `pkcs11-register` command sometimes does not behave as expected when run
  in a script. Users may need to reboot or run `pkcs11-register` upon the
  completion of this setup script.

- Firefox and Chrome both need to be started at least once to initialize their
  respective certificate databases/profiles.

- Ubuntu 21.10 and greater (to include the latest LTS 22.04) have Firefox
  installed via snap by default. There is an outstanding bug
  (https://bugzilla.mozilla.org/show_bug.cgi?id=1734371) that prevents Firefox
  from being able to read the certificates. One solution could be to uninstall
  Firefox from snap and reinstall it via `apt`. This current version of the
  script will attempt to do the reinstallation for you.

- Recent DoD certificates do not work with Cackey and will cause errors like
  `ERR_SSL_CLIENT_AUTH_NO_COMMON_ALGORITHMS`. You can simply rerun the script
  to resolve this.

- If you run into any issues with Firefox after running the script, clear your
  data and history in `Privacy & Security` and then restart Firefox. If your
  troubles are with MS Teams, see the section for [troubleshooting
  teams](#microsoft-teams). Chrome is recommended for MS Teams since Firefox
  does not currently support Teams meetings. You can see more about this
  [here](https://support.microsoft.com/en-us/office/join-a-teams-meeting-on-an-unsupported-browser-daafdd3c-ac7a-4855-871b-9113bad15907).

- Firefox will likely start up a bit slower after running this installation.


## Troubleshooting
### Microsoft Teams
If you run into issues with MS Teams, try the following steps:
1. In the Firefox Settings window, select the `Privacy & Security` tab
2. Under `Cookies and Site Data`, select `Manage Exceptions`
3. In the `Address of website` text box, enter the following URLs, and then select `Allow`
    ```
    https://microsoft.com
    https://microsoftonline.com
    https://teams.skype.com
    https://teams.microsoft.com
    https://sfbassets.com
    https://skypeforbusiness.com
    ```
4. Select `Save Changes`

> [!note]
> `strict` security settings in Firefox may cause a loading loop

See the official documentation for this issue
[here](https://docs.microsoft.com/en-us/microsoftteams/troubleshoot/teams-sign-in/sign-in-loop#mozilla-firefox).


## Contributing
Thank you for your interest in contributing to **linux_cac**! Whether you're fixing a bug, improving documentation, or adding a new feature, your help is appreciated.

### How to Contribute
1. **Fork the repository**
   Create your own copy of the project by clicking the "Fork" button at the top right of this page.

2. **Clone your fork**
   ```
   git clone https://github.com/YOUR_USERNAME/linux_cac.git
   cd linux_cac
   ```

3. **Create a branch for your changes**
   ```
   git checkout -b <your-branch-name>
   ```
   OR
   ```
   git switch -c <your-branch-name>
   ```

5. **Make your changes**
   Keep commits focused and meaningful. Update or add documentation if needed.

6. **Test your changes**
   Ensure your changes don’t break existing functionality. If applicable, add tests.

7. **Push to your fork and open a Pull Request**
   ```
   git push origin <your-branch-name>
   ```
   Then, open a Pull Request on GitHub against the `main` branch of this repository.

### Guidelines
- Follow existing code style and conventions.
- Keep changes atomic and well-documented in commit messages.
- For larger changes or features, please open an issue first to discuss your proposal.

### Need Help?
If you run into any issues or have questions, feel free to open an issue or reach out.


## License
This project is licensed under the MIT License.
See the [LICENSE](./LICENSE) file for details.

> [!warning]
> This software is provided as-is without any warranty.
> Use it at your own risk, especially in sensitive or production environments.
> Always review scripts before running them.



## References
- https://militarycac.com/linux.htm (this was my starting point)
- https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/docs/linux/cert_management.md
- https://firefox-source-docs.mozilla.org/security/nss/legacy/tools/nss_tools_certutil/index.html
- https://firefox-source-docs.mozilla.org/security/nss/legacy/tools/certutil/index.html
- https://askubuntu.com/questions/244582/add-certificate-authorities-system-wide-on-firefox
- https://stackoverflow.com/questions/1435000/programmatically-install-certificate-into-mozilla
- https://docs.microsoft.com/en-us/microsoftteams/troubleshoot/teams-sign-in/sign-in-loop#mozilla-firefox
