# Linux CAC Configuration
A simple walkthrough for how to consistently configure DOD CACs on Linux.

## Table of Contents
1. [Supported Distributions](#supported-distributions)
1. [Supported Browsers](#supported-browsers)
1. [Ubuntu and PopOS!](ubuntu-and-popos!)
    1. [Staging](#staging)
    1. [Browser Configuration](#browser-configuration)
        1. [Google Chrome](#google-chrome)
        1. [Firefox](#firefox)
1. [Known Issues](#known-issues)
1. [Additional Resources](#additional-resources)

## TODOs
- [ ] Find a way to automate the installation of DOD certificates in Firefox
- [ ] Script the entire setup process

## Supported Distributions
| OS | Versions |
|:-:|:-:|
| Ubuntu | 20.04 -> 21.04 |
| PopOS! | 21.04 |


## Supported Browsers
- Chrome
- Firefox

## Ubuntu and PopOS!
### Staging
1. Download DOD certs from DISA [here](https://militarycac.com/maccerts/AllCerts.zip).
2. Run the following command to install the CAC middleware:
```
sudo apt install libpcsclite1 pcscd libccid libpcsc-perl pcsc-tools
```
3. To verify that your CAC is detected, run (stop with ctrl+c):
```
pcsc_scan
```
4. Download and install cackey from [here](http://cackey.rkeene.org/fossil/wiki?name=Downloads).
5. Run the following command to verify the location of the cackey module and make note of the location:
```
find / -name libcackey.so 2>/dev/null
```
- **NOTE:** `libcackey.so` should be in one of the following locations:
```
/usr/lib/libcackey.so
        OR
/usr/lib64/libcackey.so
```
6. If `apt` updates cackey from 7.5 to 7.10, it will move `libcackey.so` to a different location.
To prevent cackey from updating, run the following:
```
sudo apt-mark hold cackey
```
- **NOTE**: The cackey package will still show as upgradeable.


### Browser-specific Configuration
---
#### Google Chrome
1. Run the following commands to configure the database:
```
modutil -dbdir sql:$HOME/.pki/nssdb/ -add "CAC Module" -libfile <libcackey.so's location>
modutil -dbdir sql:$HOME/.pki/nssdb/ -list
```
- **NOTE**: You should see output that resembles the following:

```
    1. NSS Internal PKCS #11 Module
         slots: 2 slots attached
         status:loaded

         slot: NSS Internal Cryptographic Services
         token: NSS Generic Crypto Services

         slot: NSS User Private Key and Certificate Services
         token: NSS Certificate DB

    2. CAC Module
         library name: /usr/lib/libcackey.so
         slots: 1 slot attached
         status: loaded

         slot: CACKey Slot
         token: LASTNAME.FIRSTNAME.NMN.123456789
```
2. `cd` inside the DISA `AllCerts` folder
3. Run the following command:
```
for n in *.cer; do certutil -d sql:$HOME/.pki/nssdb -A -t TC -n $n -i $n; done
```

#### Firefox
1. Open the Firefox browser.
2. Go to "Settings" -> "Privacy and Security"
3. Near the bottom, click "Security Devices...", then select "Load"
4. Make the "Module Name" CAC Module and then browse to the location of the `libcackey.so` module. Click "OK" when done.
3. Next, click "View Certificates..."
4. Select the "Authorities" tab.
5. Individually "Import" all the certs inside the DISA `AllCerts` folder (there are quite a few).

## Known Issues
- CAC needs to be inserted before starting Firefox

## Additional Resources
- https://militarycac.com/linux.htm (this was my starting point)
