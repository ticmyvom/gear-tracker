# Run it on your computer

Requires Ruby 3.4.2.

    bundle install
    bin/rails db:prepare
    bin/rails server

Then open http://localhost:3000 and sign up.

## Tests

    bin/rails test          # the test suite
    bin/rails test:system   # the few tests that need a browser; needs Firefox
    bin/ci                  # everything a pull request must pass: security scans, both kinds of tests and seeds

## Keeping your data

The database is one file, `storage/development.sqlite3`. It isn't stored in git.

`bin/rails db:migrate` and `db:rollback` save a copy to `storage/backups` before
changing anything. To make or restore a copy yourself:

    bin/rails db:backup
    bin/rails db:restore FILE=storage/backups/name.sqlite3

Stop the server before restoring. Restoring saves a copy of the current database
first. Backups live on the same disk, so copy them elsewhere too.
