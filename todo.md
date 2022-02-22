# TODOs
I'm working on figuring out how to load certificates into firefox's db in an automated manner.

## Notes
- I can find the user's cert and key DBs within their profile programatically:
    ```
    find $HOME/.mozilla -name cert*.db

    AND

    find $HOME/.mozilla -name key*.db
    ```
