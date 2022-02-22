# TODOs
I'm working on figuring out how to load certificates into firefox's db in an automated manner.

## Notes
- I can find the user's cert and key DBs within their profile programatically:
    ```
    find $HOME/.mozilla -name cert*.db

    AND

    find $HOME/.mozilla -name key*.db
    ```

- I need to be able to consistently locate the user's local firefox profile
- I may be able to just load the certificates using the loop for chrome and
  then hard link the cert and key DBs from `~/.pki/nssdb/`.

## Current ideas
Locates cert DB and identifies the directory to which it belongs:
```
FirefoxCertDir=$(dirname $(find $HOME/.mozilla -name cert*.db))
```
